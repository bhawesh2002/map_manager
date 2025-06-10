import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../map_mode.dart';
import '../map_utils.dart';

class RouteModeClass {
  final RouteMode _routeMode;

  RouteModeClass._(this._routeMode);
  PolylineAnnotationManager? _polylineAnnotationManager;
  PointAnnotationManager? _pointAnnotationManager;

  PolylineAnnotation? _route;

  LineString? get route => _route?.geometry;

  final Logger _logger = Logger('RouteModeClass');

  static Future<RouteModeClass> initialize(
      RouteMode mode, MapboxMap map) async {
    final cls = RouteModeClass._(mode);
    await cls.createAnnotationManagers(map);
    if (cls._routeMode.route != null) {
      await cls.addLineString(cls._routeMode.route!, map);
    }
    return cls;
  }

  Future<void> createAnnotationManagers(MapboxMap map) async {
    _polylineAnnotationManager ??=
        await map.annotations.createPolylineAnnotationManager(id: 'route');
    _pointAnnotationManager ??=
        await map.annotations.createPointAnnotationManager(id: 'waypoint');
  }

  /// pass the geometry key of the geojson. For ex routeDat['geometry']
  Future<void> addLineString(LineString lineString, MapboxMap map) async {
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
    moveMapCamTo(map, Point(coordinates: route!.coordinates.first));
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

  Future<void> dispose(MapboxMap map) async {
    _logger.info("Cleaning Route Mode Data");
    await removeAllRoutes();
    _route = null;
    await map.annotations.removeAnnotationManagerById('route');
    await map.annotations.removeAnnotationManagerById('waypoint');
    _polylineAnnotationManager = null;
    _pointAnnotationManager = null;
    _logger.info('Route Mode Data Cleared');
  }
}
