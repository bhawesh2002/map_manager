import 'package:geojson_vi/geojson_vi.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_manager/map_manager.dart';

/// Different styling profiles for route lines.
///
/// Each style represents a different visual approach inspired by popular
/// navigation and ride-sharing applications.
enum RouteStyle {
  /// Navigation apps style: Blue gradient similar to Google Maps/Apple Maps.
  ///
  /// Features:
  /// - Blue color scheme
  /// - Professional navigation appearance
  /// - Standard line width
  navigation,

  /// Custom style: Allows for fully customizable colors and properties.
  ///
  /// Features:
  /// - User-defined colors
  /// - Configurable line properties
  /// - Maximum flexibility
  custom,
}

/// Handles route visualization on the Mapbox map using LineLayer and GeoJsonSource.
///
/// This class manages the display of routes on a Mapbox map by implementing a modern
/// LineLayer approach instead of the deprecated polyline annotation system. It provides
/// support for both LineString routes and raw GeoJSON data input, with beautiful
/// gradient styling inspired by popular navigation apps.
///
/// ## Key Features:
///
/// ### Dual Input Support
/// - **LineString Routes**: Standard coordinate-based routes
/// - **GeoJSON Data**: Full GeoJSON feature objects with properties
///
/// ### Modern Styling
/// - Gradient line coloring using `lineGradientExpression`
/// - Rounded geometry for smooth appearance
/// - White border glow for enhanced visibility
/// - Multiple styling profiles (Uber, Lyft, Navigation, etc.)
///
/// ### Performance Optimized
/// - Uses Mapbox's native LineLayer for better performance
/// - Efficient GeoJsonSource with line metrics enabled
/// - Proper cleanup to prevent memory leaks
///
/// ### Crash Prevention
/// - Comprehensive error handling throughout
/// - Graceful degradation when features fail
/// - Proper disposal of map resources
///
/// ## Usage Example:
///
/// ```dart
/// // Create a route from LineString coordinates
/// final route = LineString(coordinates: [
// Position(-122.4194, 37.7749),
// Position(-122.4094, 37.7849),
/// ]);
///
/// // Initialize route mode
/// final routeMode = MapMode.route(route: route);
/// await mapManager.setMode(routeMode);
///
/// // Access route functionality
/// mapManager.whenRouteMode((routeClass) {
///   routeClass.zoomToRoute();
///   print('Route has ${routeClass.route?.coordinates.length} coordinates');
/// });
/// ```
///
/// ## Implementation Notes:
///
/// ### LineLayer vs Polyline Annotations
/// This implementation uses Mapbox's LineLayer instead of polyline annotations
/// for several advantages:
/// - Better performance with large routes
/// - Native gradient support
/// - More styling options
/// - Better integration with map style
///
/// ### GeoJSON Source Configuration
/// The GeoJsonSource is configured with `lineMetrics: true` to enable
/// gradient expressions. This is required for the `lineGradientExpression`
/// to work properly.
///
/// ### Error Handling Strategy
/// All map operations are wrapped in try-catch blocks with specific error
/// logging. This prevents crashes while providing debugging information.
class RouteModeClass implements ModeHandler {
  /// The route mode configuration containing the route data and options.
  final RouteMode _routeMode;

  /// The Mapbox map instance for rendering operations.
  final MapboxMap _map;

  /// Private constructor to enforce factory initialization pattern.
  RouteModeClass._(this._routeMode, this._map);

  final Map<String, GeoJSONFeature> _addedRoutesMap = {};

  List<String> get addedRoutesId => _addedRoutesMap.keys.toList();

  /// The currently active route stored as a GeoJSONLineString.
  ///
  /// This is populated when a route is successfully added, either from
  /// a LineString input or extracted from GeoJSON data. It's used for
  /// camera operations and waypoint placement.
  GeoJSONFeatureCollection get _routeFeatureCollection =>
      GeoJSONFeatureCollection([..._addedRoutesMap.values]);

  /// Unique identifier for the GeoJSON source containing route data.
  ///
  /// This source is configured with `lineMetrics: true` to enable
  /// gradient expressions along the route line.
  static const String _routeSourceId = 'route-source';

  /// Unique identifier for the LineLayer that renders the route.
  ///
  /// The layer references the GeoJSON source and applies styling
  /// including gradients, line width, and border effects.
  static String get _routeLayerId => 'route-layer';

  /// Gets the currently active route as a LineString.
  ///
  /// Returns `null` if no route is currently set. This getter provides
  /// access to route coordinates for camera operations and analysis.
  GeoJSONLineString? get activeRoute {
    try {
      return _routeFeatureCollection.features
              .where((f) => f?.properties?['active'] == true)
              .firstOrNull
              ?.geometry
          as GeoJSONLineString?;
    } catch (e) {
      return null;
    }
  }

  List<GeoJSONLineString> get allRoutes => _routeFeatureCollection.features
      .map((e) => e?.geometry as GeoJSONLineString)
      .toList();

  /// Logger instance for debugging and error reporting.
  final ManagerLogger _logger = ManagerLogger('RouteModeClass');

  /// Factory method to initialize a new RouteModeClass instance.
  ///
  /// This method handles the complete setup process including:
  /// - Point annotation manager creation
  /// - Tap listener configuration
  /// - Route data processing and display
  /// - Error handling and logging
  ///
  /// Parameters:
  /// - [mode]: The RouteMode configuration containing route data
  /// - [map]: The MapboxMap instance for rendering
  ///
  /// Returns a fully initialized RouteModeClass instance.
  ///
  /// Throws: Rethrows any critical errors that prevent initialization.
  static Future<RouteModeClass> initialize(
    RouteMode mode,
    MapboxMap map,
  ) async {
    final cls = RouteModeClass._(mode, map);

    // Set up tap listener to prevent issues with residual handlers
    // This prevents crashes from stale tap listeners when switching modes
    cls._map.setOnMapTapListener((context) {});
    try {
      await cls._setupSource();
      if (cls._routeMode.predefinedRoutes != null) {
        for (var rt in mode.predefinedRoutes!.entries) {
          await cls.addLineString(rt.value, identifier: rt.key);
        }
      }
    } catch (e) {
      cls._logger.warning("Error adding route: $e");
    }

    return cls;
  }

  Future<void> _setupSource() async {
    try {
      await _map.style.addSource(
        GeoJsonSource(
          id: _routeSourceId,
          data: _routeFeatureCollection.toJSON(),
          lineMetrics: true,
        ),
      );
    } catch (e) {
      _logger.severe("_setupSource(): $e");
    }
  }

  static int addCount = 0;

  /// Creates and displays a route using LineLayer and GeoJsonSource.
  ///
  /// This method implements the modern Mapbox approach for route visualization
  /// using native LineLayer instead of polyline annotations. It supports both
  /// LineString coordinates and raw GeoJSON data input.
  ///
  /// ## Features:
  ///
  /// ### Dual Input Support
  /// - **LineString**: Direct coordinate array input
  /// - **GeoJSON**: Full GeoJSON feature with properties
  ///
  /// ### Styling Implementation
  /// - Uber + Lyft hybrid styling by default
  /// - Pink to purple gradient using `lineGradientExpression`
  /// - Rounded line caps and joins for smooth appearance
  /// - White border glow for enhanced visibility
  /// - Configurable line width and opacity
  ///
  /// ### Waypoint Markers
  /// - Automatic start and end point markers
  /// - Proper icon positioning with offset
  /// - Camera movement to route start point
  ///
  /// ## Parameters:
  /// - [route]: Optional LineString containing route coordinates
  ///
  /// ## Requirements:
  /// - Exactly one of [route] must be provided
  /// - GeoJSON data should contain LineString geometry for full functionality
  ///
  /// ## Technical Implementation:
  ///
  /// ### GeoJSON Source Setup
  /// The source is configured with `lineMetrics: true` to enable gradient
  /// expressions. This is required for the `lineGradientExpression` to work.
  ///
  /// ### LineLayer Configuration
  /// ```dart
  /// LineLayer(
  ///   id: _routeLayerId,
  ///   sourceId: _routeSourceId,
  ///   lineWidth: 14.0,
  ///   lineCap: LineCap.ROUND,
  ///   lineJoin: LineJoin.ROUND,
  ///   lineGradientExpression: [...], // Pink to purple gradient
  /// )
  /// ```
  ///
  /// Throws: Rethrows any critical errors that prevent route creation.
  Future<void> addLineString(
    GeoJSONFeature route, {
    String? identifier,
    bool setActive = false,
  }) async {
    try {
      identifier ??= 'route-$addCount';
      route.properties ??= {};
      route.properties!['active'] = setActive;
      route.properties!['route_id'] = identifier;
      _addedRoutesMap.putIfAbsent(identifier, () {
        addCount++;
        return route;
      });
      await _updateRouteSource();
      await _map.style.addLayer(
        LineLayer(
          id: _routeLayerId + identifier,
          sourceId: _routeSourceId,
          filter: [
            "==",
            ["get", "route_id"],
            identifier,
          ],
        ),
      );
      await zoomToRoute();
    } catch (e) {
      _logger.warning("addLineString(): $e");
      rethrow;
    }
  }

  Future<void> setActiveRoute(String identifier) async {
    if (addedRoutesId.contains(identifier)) {
      for (var route in _addedRoutesMap.values) {
        route.properties?['active'] = false;
      }
      _addedRoutesMap[identifier]?.properties?['active'] = true;
      await _updateRouteSource();
    } else {
      throw Exception("Specified identifier was not found");
    }
  }

  Future<void> _updateRouteSource() async {
    try {
      await _map.style.setStyleSourceProperty(
        _routeSourceId,
        'data',
        _routeFeatureCollection.toJSON(),
      );
    } catch (e) {
      _logger.severe("_updateRouteSource(): $e");
    }
  }

  /// Removes the currently displayed route from the map.
  ///
  /// This method cleanly removes both the LineLayer and its associated
  /// GeoJsonSource from the map style. It includes error handling to
  /// prevent crashes if the removal fails.
  ///
  /// The method only attempts removal if a route is currently active
  /// (indicated by `_route` being non-null).
  ///
  /// ## Cleanup Process:
  /// 1. Remove the LineLayer from map style
  /// 2. Remove the GeoJsonSource from map style
  /// 3. Log any errors that occur during removal
  ///
  /// Note: This method does not remove waypoint markers. Use [dispose]
  /// for complete cleanup including waypoints.
  Future<void> removeRoute(String identifier) async {
    if (addedRoutesId.contains(identifier)) {
      try {
        _addedRoutesMap.remove(identifier);
        await _map.style.removeStyleLayer(_routeLayerId + identifier);
        await _updateRouteSource();
      } catch (e) {
        _logger.warning("Error removing route layer/source: $e");
      }
    } else {
      throw Exception("Specified identifier was not found");
    }
  }

  /// Removes all routes from the map.
  ///
  /// Currently equivalent to [removeRoute] since this implementation
  /// supports a single route at a time. This method exists for future
  /// compatibility when multi-route support is added.
  ///
  /// Future implementations may extend this to handle multiple
  /// concurrent routes with different styling or purposes.
  Future<void> removeAllRoutes() async {
    for (var id in addedRoutesId) {
      await removeRoute(id);
    }
  }

  Future<void> _removeSource() async {
    await _map.style.removeStyleSource(_routeSourceId);
  }

  /// Zooms the map camera to fit the entire route within the viewport.
  ///
  /// This method uses the shared utility function to create a bounding box
  /// that encompasses all route coordinates and adjusts the camera to show
  /// the entire route. If no route is set, this method does nothing.
  ///
  /// ## Camera Behavior:
  /// - Calculates bounding box from all route coordinates
  /// - Applies padding to ensure route isn't touching viewport edges
  /// - Uses smooth animation for camera transition
  /// - Maintains appropriate zoom level for route visibility
  ///
  /// ## Parameters:
  /// - [paddingPixels]: Padding around the bounds in screen pixels (default: 50.0)
  /// - [animationDuration]: Duration for the camera animation in milliseconds (default: 1000)
  ///
  /// ## Usage Example:
  /// ```dart
  /// // Zoom to show entire route with default padding
  /// await routeMode.zoomToRoute();
  ///
  /// // Zoom with custom padding and faster animation
  /// await routeMode.zoomToRoute(
  ///   paddingPixels: 100.0,
  ///   animationDuration: 500,
  /// );
  /// ```
  ///
  /// Note: This method does nothing if no route is currently set.
  Future<void> zoomToRoute({
    double paddingPixels = 50.0,
    int animationDuration = 1000,
  }) async {
    if (activeRoute == null || activeRoute!.coordinates.isEmpty) return;

    // Convert route coordinates to Points for utility function
    // final List<Point> routePoints = route!.coordinates
    //     .map((coordinate) => Point(coordinates: coordinate))
    //     .toList();

    // Use shared utility for consistent camera behavior across modes
    await zoomToFitPoints(
      _map,
      activeRoute!.points,
      paddingPixels: paddingPixels,
      animationDuration: animationDuration,
      logger: _logger,
    );
  }

  /// Disposes of all route-related resources and cleans up the map state.
  ///
  /// This method performs complete cleanup of the route mode including:
  /// - Clearing tap listeners to prevent stale handlers
  /// - Removing all route visualizations
  /// - Cleaning up waypoint annotations
  /// - Resetting internal state
  ///
  /// ## Cleanup Process:
  /// 1. **Tap Listener Cleanup**: Removes any active tap listeners to prevent
  ///    crashes from stale handlers when switching modes
  /// 2. **Route Removal**: Removes LineLayer and GeoJsonSource from map
  /// 3. **State Reset**: Clears internal route reference
  /// 4. **Annotation Cleanup**: Removes waypoint annotation manager
  /// 5. **Manager Reset**: Nullifies manager references
  ///
  /// ## Error Handling:
  /// All cleanup operations are wrapped in try-catch blocks to ensure
  /// disposal continues even if individual operations fail. Errors are
  /// logged for debugging but don't prevent other cleanup steps.
  ///
  /// This method should always be called when switching away from route
  /// mode to prevent memory leaks and map state conflicts.
  @override
  Future<void> dispose() async {
    _logger.info("Cleaning Route Mode Data");

    // Clear tap listener to prevent crashes from stale handlers
    // This is critical for preventing "No manager found" errors
    _map.setOnMapTapListener(null);

    // Remove all route visualizations
    await removeAllRoutes();
    await _removeSource();

    _logger.info('Route Mode Data Cleared');
  }
}
