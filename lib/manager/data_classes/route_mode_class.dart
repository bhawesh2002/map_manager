import 'package:logging/logging.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../map_mode.dart';
import '../map_utils.dart';
import '../mode_handler.dart';

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
    await cls._createPointAnnotationManager();
    if (cls._routeMode.route != null) {
      await cls.addLineString(cls._routeMode.route!);
    }
    return cls;
  }

  Future<void> _createPointAnnotationManager() async {
    _pointAnnotationManager ??=
        await _map.annotations.createPointAnnotationManager(id: 'waypoint');
  }

  /// Creates a route using LineLayer and GeoJsonSource
  /// pass the geometry key of the geojson. For ex routeDat['geometry']
  Future<void> addLineString(LineString lineString) async {
    _logger.info(lineString.bbox);
    _route = lineString;

    // Create GeoJSON source for the route
    final geoJsonSource = GeoJsonSource(
      id: _routeSourceId,
    );

    // Set the data for the source
    await _map.style.addSource(geoJsonSource);
    await _map.style.setStyleSourceProperty(
      _routeSourceId,
      'data',
      {"type": "Feature", "geometry": lineString.toJson(), "properties": {}},
    );

    // Create and add the line layer
    final lineLayer = LineLayer(
      id: _routeLayerId,
      sourceId: _routeSourceId,
    );

    // Set line layer properties
    await _map.style.addLayer(lineLayer);
    await _map.style.setStyleLayerProperty(
      _routeLayerId,
      'line-color',
      '#9C27B0', // Purple color in hex
    );
    await _map.style.setStyleLayerProperty(
      _routeLayerId,
      'line-width',
      8.0,
    );

    // Add waypoint markers at start and end
    await _pointAnnotationManager!.createMulti(
      [
        PointAnnotationOptions(
            iconOffset: [0, -28],
            geometry: Point(coordinates: lineString.coordinates.first)),
        PointAnnotationOptions(
            iconOffset: [0, -28],
            geometry: Point(coordinates: lineString.coordinates.last)),
      ],
    );

    moveMapCamTo(_map, Point(coordinates: route!.coordinates.first));
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
