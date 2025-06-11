import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../map_mode.dart';
import '../map_utils.dart';
import '../mode_handler.dart';

class RouteModeClass implements ModeHandler {
  final RouteMode _routeMode;
  final MapboxMap _map;

  RouteModeClass._(this._routeMode, this._map);
  PolylineAnnotationManager? _polylineAnnotationManager;
  PointAnnotationManager? _pointAnnotationManager;

  PolylineAnnotation? _route;

  LineString? get route => _route?.geometry;

  final Logger _logger = Logger('RouteModeClass');

  static Future<RouteModeClass> initialize(
      RouteMode mode, MapboxMap map) async {
    final cls = RouteModeClass._(mode, map);
    await cls.createAnnotationManagers();
    if (cls._routeMode.route != null) {
      await cls.addLineString(cls._routeMode.route!);
    }
    return cls;
  }

  Future<void> createAnnotationManagers() async {
    _polylineAnnotationManager ??=
        await _map.annotations.createPolylineAnnotationManager(id: 'route');
    _pointAnnotationManager ??=
        await _map.annotations.createPointAnnotationManager(id: 'waypoint');
  }

  /// pass the geometry key of the geojson. For ex routeDat['geometry']
  Future<void> addLineString(LineString lineString) async {
    _logger.info(lineString.bbox);
    _route = await _polylineAnnotationManager!.create(PolylineAnnotationOptions(
      geometry: lineString,
      lineWidth: 8,
      lineColor: Colors.purple.toARGB32(),
    ));
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
      await _polylineAnnotationManager!.delete(_route!);
    }
  }

  Future<void> removeAllRoutes() async {
    //Causes runtime exception `Caused by: java.lang.Throwable: No manager found with id: route`
    // if (_polylineAnnotationManager != null) {
    //   await _polylineAnnotationManager?.deleteAll();
    // }
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
    await _map.annotations.removeAnnotationManagerById('route');
    await _map.annotations.removeAnnotationManagerById('waypoint');
    _polylineAnnotationManager = null;
    _pointAnnotationManager = null;
    _logger.info('Route Mode Data Cleared');
  }
}
