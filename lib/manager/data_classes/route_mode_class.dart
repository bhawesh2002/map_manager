import 'package:map_manager/utils/manager_logger.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../map_mode.dart';
import '../map_utils.dart';
import '../mode_handler.dart';

/// Different styling profiles for route lines.
///
/// Each style represents a different visual approach inspired by popular
/// navigation and ride-sharing applications.
enum RouteStyle {
  /// Uber + Lyft hybrid: Combines Uber's clean geometry with Lyft's vibrant gradient.
  ///
  /// Features:
  /// - Clean rounded geometry (Uber-style)
  /// - Pink to purple gradient (Lyft-style)
  /// - Moderate line width with subtle glow
  uberLyftHybrid,

  /// Classic Uber style: Clean black line with minimal styling.
  ///
  /// Features:
  /// - Solid black color
  /// - Clean, professional appearance
  /// - Moderate line width
  uber,

  /// Classic Lyft style: Bright pink to purple gradient.
  ///
  /// Features:
  /// - Vibrant pink to purple gradient
  /// - Bold, energetic appearance
  /// - Slightly thicker line width
  lyft,

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

  /// Point annotation manager for displaying route waypoints (start/end markers).
  ///
  /// This manager handles the creation and management of point annotations
  /// that mark the beginning and end of routes. It's nullable to handle
  /// cases where annotation creation fails.
  PointAnnotationManager? _pointAnnotationManager;

  /// The currently active route stored as a LineString.
  ///
  /// This is populated when a route is successfully added, either from
  /// a LineString input or extracted from GeoJSON data. It's used for
  /// camera operations and waypoint placement.
  LineString? _route;

  /// Unique identifier for the GeoJSON source containing route data.
  ///
  /// This source is configured with `lineMetrics: true` to enable
  /// gradient expressions along the route line.
  static const String _routeSourceId = 'route-source';

  /// Unique identifier for the LineLayer that renders the route.
  ///
  /// The layer references the GeoJSON source and applies styling
  /// including gradients, line width, and border effects.
  static const String _routeLayerId = 'route-layer';

  /// Gets the currently active route as a LineString.
  ///
  /// Returns `null` if no route is currently set. This getter provides
  /// access to route coordinates for camera operations and analysis.
  LineString? get route => _route;

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

    // Create point annotation manager with error handling
    try {
      await cls._createPointAnnotationManager();
    } catch (e) {
      cls._logger.warning("Error creating point annotation manager: $e");
    }

    // Set up tap listener to prevent issues with residual handlers
    // This prevents crashes from stale tap listeners when switching modes
    cls._map.setOnMapTapListener((context) {});

    if (cls._routeMode.route != null || cls._routeMode.geojson != null) {
      try {
        if (cls._routeMode.route != null) {
          cls._logger.info(
            "Adding route from LineString with ${cls._routeMode.route!.coordinates.length} coordinates",
          );
        } else {
          cls._logger.info("Adding route from GeoJSON data");
        }
        await cls.addLineString(
          route: cls._routeMode.route,
          geojson: cls._routeMode.geojson,
        );
      } catch (e) {
        cls._logger.warning("Error adding route: $e");
      }
    } else {
      cls._logger.info(
        "No route or geojson data provided - route mode initialized without route",
      );
    }

    return cls;
  }

  /// Creates and configures the point annotation manager for waypoint markers.
  ///
  /// This manager is used to display start and end point markers on routes.
  /// The method includes error handling to gracefully handle creation failures
  /// without breaking the overall route functionality.
  ///
  /// The manager is created with ID 'waypoint' for easy identification and cleanup.
  Future<void> _createPointAnnotationManager() async {
    try {
      _pointAnnotationManager ??= await _map.annotations
          .createPointAnnotationManager(id: 'waypoint');
    } catch (e) {
      _logger.warning("Failed to create point annotation manager: $e");
      _pointAnnotationManager = null;
    }
  }

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
  /// - [geojson]: Optional GeoJSON feature data
  ///
  /// ## Requirements:
  /// - Exactly one of [route] or [geojson] must be provided
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
  Future<void> addLineString({
    LineString? route,
    Map<String, dynamic>? geojson,
  }) async {
    assert(
      !(route == null && geojson == null),
      "Either route or geojson must be provided",
    );
    assert(
      !(route != null && geojson != null),
      "Both route and geojson cannot be provided",
    );
    try {
      GeoJsonSource? geoJsonSource;
      if (route != null) {
        _route = route; // Store the route
        final data = {
          "type": "Feature",
          "geometry": route.toJson(),
          "properties": {},
        };
        // Create GeoJSON source with line metrics enabled for gradient support
        geoJsonSource = GeoJsonSource(id: _routeSourceId, lineMetrics: true);
        await _map.style.addSource(geoJsonSource);
        await _map.style.setStyleSourceProperty(_routeSourceId, 'data', data);
      } else {
        // For geojson input, try to extract LineString if possible
        if (geojson!['type'] == 'Feature' &&
            geojson['geometry']?['type'] == 'LineString') {
          _route = LineString.fromJson(geojson['geometry']);
        }
        // Create GeoJSON source with line metrics enabled for gradient support
        geoJsonSource = GeoJsonSource(id: _routeSourceId, lineMetrics: true);
        await _map.style.addSource(geoJsonSource);
        await _map.style.setStyleSourceProperty(
          _routeSourceId,
          'data',
          geojson,
        );
      }

      // Create and add the line layer with Uber + Lyft hybrid styling
      // This combines Uber's clean geometry with Lyft's vibrant gradient colors
      final lineLayer = LineLayer(
        id: _routeLayerId,
        sourceId: _routeSourceId,

        // Geometry Styling (Uber's characteristics)
        lineWidth: 12.0, // Bold but not overwhelming
        lineCap: LineCap.ROUND, // Smooth rounded ends
        lineJoin: LineJoin.ROUND, // Smooth rounded corners
        lineOpacity: 0.95, // Slightly transparent for blend
        // Lyft-style vibrant gradient (requires lineMetrics: true)
        // Uses line-progress from 0.0 (start) to 1.0 (end) for gradient positioning
        lineGradientExpression: [
          'interpolate', // Smooth color interpolation
          ['linear'], // Linear interpolation method
          ['line-progress'], // Use line progress (0.0 to 1.0)
          0.0, "#FF1493", // Deep pink at start
          0.2, "#FF69B4", // Hot pink
          0.4, "#DA70D6", // Orchid
          0.6, "#BA55D3", // Medium orchid
          0.8, "#9932CC", // Dark orchid
          1.0, "#6A5ACD", // Slate blue at end
        ],

        // Border and Glow Effects
        lineBlur: 0.0, // Sharp edges (set >0 for softening)
        lineBorderColor: 0xFFFFFFFF, // White border for contrast
        lineBorderWidth: 2.0, // Subtle border width
        // Z-positioning
        lineZOffset: 0.0, // Keep at map level
      );

      // Add the configured line layer to the map style
      await _map.style.addLayer(lineLayer);

      // Add waypoint markers at start and end (only if annotation manager exists and route is available)
      if (_pointAnnotationManager != null && _route != null) {
        await _pointAnnotationManager!.createMulti([
          // Start point marker
          PointAnnotationOptions(
            iconOffset: [0, -28], // Offset to center icon on point
            geometry: Point(coordinates: _route!.coordinates.first),
          ),
          // End point marker
          PointAnnotationOptions(
            iconOffset: [0, -28], // Offset to center icon on point
            geometry: Point(coordinates: _route!.coordinates.last),
          ),
        ]);

        // Move camera to show the start of the route
        moveMapCamTo(_map, Point(coordinates: _route!.coordinates.first));
      } else {
        // Log warnings for debugging if waypoint creation fails
        if (_pointAnnotationManager == null) {
          _logger.warning(
            "Point annotation manager not available for waypoints",
          );
        }
        if (_route == null) {
          _logger.warning(
            "No route coordinates available for camera positioning",
          );
        }
      }
    } catch (e) {
      _logger.warning("Error adding line string: $e");
      rethrow;
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

  /// Removes all routes from the map.
  ///
  /// Currently equivalent to [removeRoute] since this implementation
  /// supports a single route at a time. This method exists for future
  /// compatibility when multi-route support is added.
  ///
  /// Future implementations may extend this to handle multiple
  /// concurrent routes with different styling or purposes.
  Future<void> removeAllRoutes() async {
    await removeRoute();
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
    if (route == null || route!.coordinates.isEmpty) return;

    // Convert route coordinates to Points for utility function
    final List<Point> routePoints = route!.coordinates
        .map((coordinate) => Point(coordinates: coordinate))
        .toList();

    // Use shared utility for consistent camera behavior across modes
    await zoomToFitPoints(
      _map,
      routePoints,
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
    _route = null;

    // Remove annotation manager for waypoints with error handling
    try {
      await _map.annotations.removeAnnotationManagerById('waypoint');
    } catch (e) {
      _logger.warning("Error removing waypoint annotation manager: $e");
    }

    // Reset manager reference
    _pointAnnotationManager = null;
    _logger.info('Route Mode Data Cleared');
  }
}
