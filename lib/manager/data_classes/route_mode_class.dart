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
