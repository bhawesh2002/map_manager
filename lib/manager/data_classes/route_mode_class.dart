import 'package:logging/logging.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../map_mode.dart';
import '../map_utils.dart';
import '../mode_handler.dart';

/// Different styling profiles for route lines
enum RouteStyle {
  /// Uber + Lyft hybrid: Uber geometry with Lyft gradient
  uberLyftHybrid,

  /// Classic Uber style: Clean black line
  uber,

  /// Classic Lyft style: Pink to purple gradient
  lyft,

  /// Navigation apps style: Blue gradient
  navigation,

  /// Custom style: Customizable colors
  custom,
}

class RouteModeClass implements ModeHandler {
  final RouteMode _routeMode;
  final MapboxMap _map;

  RouteModeClass._(this._routeMode, this._map);
  PointAnnotationManager? _pointAnnotationManager;

  LineString? _route;
  static const String _routeSourceId = 'route-source';
  static const String _routeLayerId = 'route-layer';

  LineString? get route => _route;

  final Logger _logger = Logger('RouteModeClass');
  static Future<RouteModeClass> initialize(
      RouteMode mode, MapboxMap map) async {
    final cls = RouteModeClass._(mode, map);

    // Create point annotation manager with error handling
    try {
      await cls._createPointAnnotationManager();
    } catch (e) {
      cls._logger.warning("Error creating point annotation manager: $e");
    }

    // Set up tap listener to prevent issues with residual handlers
    cls._map.setOnMapTapListener((context) {});
    if (cls._routeMode.route != null || cls._routeMode.geojson != null) {
      try {
        if (cls._routeMode.route != null) {
          cls._logger.info(
              "Adding route from LineString with ${cls._routeMode.route!.coordinates.length} coordinates");
        } else {
          cls._logger.info("Adding route from GeoJSON data");
        }
        await cls.addLineString(
            route: cls._routeMode.route, geojson: cls._routeMode.geojson);
      } catch (e) {
        cls._logger.warning("Error adding route: $e");
      }
    } else {
      cls._logger.info(
          "No route or geojson data provided - route mode initialized without route");
    }

    return cls;
  }

  Future<void> _createPointAnnotationManager() async {
    try {
      _pointAnnotationManager ??=
          await _map.annotations.createPointAnnotationManager(id: 'waypoint');
    } catch (e) {
      _logger.warning("Failed to create point annotation manager: $e");
      _pointAnnotationManager = null;
    }
  }

  /// Creates a route using LineLayer and GeoJsonSource
  /// Either provide a LineString route OR a GeoJSON map, but not both
  Future<void> addLineString(
      {LineString? route, Map<String, dynamic>? geojson}) async {
    assert(!(route == null && geojson == null),
        "Either route or geojson must be provided");
    assert(!(route != null && geojson != null),
        "Both route and geojson cannot be provided");
    try {
      GeoJsonSource? geoJsonSource;
      if (route != null) {
        _route = route; // Store the route
        final data = {
          "type": "Feature",
          "geometry": route.toJson(),
          "properties": {}
        };
        geoJsonSource = GeoJsonSource(id: _routeSourceId, lineMetrics: true);
        await _map.style.addSource(geoJsonSource);
        await _map.style.setStyleSourceProperty(
          _routeSourceId,
          'data',
          data,
        );
      } else {
        // For geojson input, try to extract LineString if possible
        if (geojson!['type'] == 'Feature' &&
            geojson['geometry']?['type'] == 'LineString') {
          _route = LineString.fromJson(geojson['geometry']);
        }
        geoJsonSource = GeoJsonSource(id: _routeSourceId, lineMetrics: true);
        await _map.style.addSource(geoJsonSource);
        await _map.style.setStyleSourceProperty(
          _routeSourceId,
          'data',
          geojson,
        );
      } // Create and add the line layer with Uber + Lyft styling
      // This combines Uber's clean geometry with Lyft's vibrant gradient colors
      final lineLayer = LineLayer(
        id: _routeLayerId,
        sourceId: _routeSourceId,
        // Geometry Styling (Uber's characteristics)
        lineWidth: 14.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        lineOpacity: 0.95,
        // Lyft-style vibrant gradient (using lineGradientExpression)
        lineGradientExpression: [
          'interpolate',
          ['linear'],
          ['line-progress'],
          0.0, "#FF1493", // Deep pink at start
          0.2, "#FF69B4", // Hot pink
          0.4, "#DA70D6", // Orchid
          0.6, "#BA55D3", // Medium orchid
          0.8, "#9932CC", // Dark orchid
          1.0, "#6A5ACD", // Slate blue at end
        ],

        // Subtle Glow (simulated using blur or a second layer behind)
        lineBlur: 0.0, // set >0 for softening; needs testing
        lineBorderColor: 0xFFFFFFFF, // white glow
        lineBorderWidth: 2.0, // adjust as needed

        // Translation / Z offset if needed to lift it above other elements
        lineZOffset: 0.0,
      );

      // Set line layer properties
      await _map.style.addLayer(
          lineLayer); // Add waypoint markers at start and end (only if annotation manager exists and route is available)
      if (_pointAnnotationManager != null && _route != null) {
        await _pointAnnotationManager!.createMulti(
          [
            PointAnnotationOptions(
                iconOffset: [0, -28],
                geometry: Point(coordinates: _route!.coordinates.first)),
            PointAnnotationOptions(
                iconOffset: [0, -28],
                geometry: Point(coordinates: _route!.coordinates.last)),
          ],
        );

        moveMapCamTo(_map, Point(coordinates: _route!.coordinates.first));
      } else {
        if (_pointAnnotationManager == null) {
          _logger
              .warning("Point annotation manager not available for waypoints");
        }
        if (_route == null) {
          _logger
              .warning("No route coordinates available for camera positioning");
        }
      }
    } catch (e) {
      _logger.warning("Error adding line string: $e");
      rethrow;
    }
  }

  Future<void> removeRoute() async {
    if (_route != null) {
      // Remove the line layer and source
      try {
        await _map.style.removeStyleLayer(_routeLayerId);
        await _map.style.removeStyleSource(_routeSourceId);
      } catch (e) {
        _logger.warning("Error removing route layer/source: $e");
      }
    }
  }

  Future<void> removeAllRoutes() async {
    await removeRoute();
  }

  /// Zooms the map camera to fit the entire route within the viewport.
  ///
  /// This method uses the shared utility function to create a bounding box
  /// that encompasses all route coordinates and adjusts the camera to show
  /// the entire route. If no route is set, this method does nothing.
  ///
  /// Parameters:
  /// - [paddingPixels]: Padding around the bounds in screen pixels
  /// - [animationDuration]: Duration for the camera animation in milliseconds
  ///
  /// Example usage:
  /// ```dart
  /// mapManager.whenRouteMode((routeMode) {
  ///   routeMode.zoomToRoute();
  /// });
  /// ```
  Future<void> zoomToRoute({
    double paddingPixels = 50.0,
    int animationDuration = 1000,
  }) async {
    if (route == null || route!.coordinates.isEmpty) return;

    // Convert route coordinates to Points
    final List<Point> routePoints = route!.coordinates
        .map((coordinate) => Point(coordinates: coordinate))
        .toList();

    await zoomToFitPoints(
      _map,
      routePoints,
      paddingPixels: paddingPixels,
      animationDuration: animationDuration,
      logger: _logger,
    );
  }

  @override
  Future<void> dispose() async {
    _logger.info("Cleaning Route Mode Data");

    // Clear tap listener
    _map.setOnMapTapListener(null);

    await removeAllRoutes();
    _route = null;

    // Remove annotation manager for waypoints
    try {
      await _map.annotations.removeAnnotationManagerById('waypoint');
    } catch (e) {
      _logger.warning("Error removing waypoint annotation manager: $e");
    }

    _pointAnnotationManager = null;
    _logger.info('Route Mode Data Cleared');
  }
}
