import 'dart:convert';

import 'package:geojson_vi/geojson_vi.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_manager/map_manager.dart';

/// Handles route visualization on the Mapbox map using LineLayer and GeoJsonSource.
class RouteModeClass extends ModeHandler {
  final RouteMode _routeMode;

  final MapboxMap _map;

  RouteModeClass._(this._routeMode, this._map);

  final Map<String, GeoJSONFeature> _addedRoutesMap = {};

  List<String> get addedRoutesId => _addedRoutesMap.keys.toList();

  GeoJSONFeatureCollection get _routeFeatureCollection =>
      GeoJSONFeatureCollection([..._addedRoutesMap.values]);

  static const String _routeSourceId = 'route-source';

  static String get _routeLayerId => 'route-layer';

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

  List<GeoJSONLineString> get allActiveRoutes => _routeFeatureCollection
      .features
      .where((e) => e?.properties?['active'] == true)
      .map((e) => e?.geometry)
      .toList()
      .cast<GeoJSONLineString>();

  final ManagerLogger _logger = ManagerLogger('RouteModeClass');

  static Future<RouteModeClass> initialize(
    RouteMode mode,
    MapboxMap map,
  ) async {
    final cls = RouteModeClass._(mode, map);

    cls.safeExecuteSync(() {
      cls._map.setOnMapTapListener((context) {});
    }, operationName: 'setMapTapListener');

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
    await safeExecute(() async {
      await _map.style.addSource(
        GeoJsonSource(
          id: _routeSourceId,
          data: _routeFeatureCollection.toJSON(),
          lineMetrics: true,
        ),
      );
    }, operationName: 'addRouteSource');
  }

  static int addCount = 0;

  Future<void> addLineString(
    GeoJSONFeature route, {
    String? identifier,
    bool setActive = false,
  }) async {
    try {
      setActive = _addedRoutesMap.isEmpty ? true : setActive;
      final routeId = identifier ?? 'route-$addCount';
      identifier = routeId;
      route.properties ??= {};
      route.properties!['route_id'] = routeId;
      _addedRoutesMap.putIfAbsent(routeId, () {
        addCount++;
        return route;
      });
      setActiveRoute(identifier);

      await _updateRouteSource();

      await safeExecute(() async {
        await _map.style.addLayer(
          LineLayer(
            id: _routeLayerId + routeId,
            sourceId: _routeSourceId,
            filter: [
              "==",
              ["get", "route_id"],
              routeId,
            ],
          ),
        );
      }, operationName: 'addRouteLayer');

      final styling = route.properties?['styling'] as Map<String, dynamic>?;
      await applyRouteStyle(routeId, styling);
      await zoomToRoute();
    } catch (e) {
      _logger.warning("addLineString(): $e");
      rethrow;
    }
  }

  Future<void> applyRouteStyle(
    String identifier,
    Map<String, dynamic>? styling,
  ) async {
    await safeExecute(() async {
      await _map.style.setStyleLayerProperties(
        _routeLayerId + identifier,
        jsonEncode(styling ?? routeLayerProps),
      );
    }, operationName: 'applyRouteStyle');
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
    await safeExecute(() async {
      await _map.style.setStyleSourceProperty(
        _routeSourceId,
        'data',
        _routeFeatureCollection.toJSON(),
      );
    }, operationName: 'updateRouteSource');
  }

  Future<void> removeRoute(String identifier) async {
    if (addedRoutesId.contains(identifier)) {
      _addedRoutesMap.remove(identifier);

      await safeExecute(
        () async {
          await _map.style.removeStyleLayer(_routeLayerId + identifier);
        },
        operationName: 'removeRouteLayer',
        shouldDispose: false,
      );

      await _updateRouteSource();
    } else {
      throw Exception("Specified identifier was not found");
    }
  }

  Future<void> removeAllRoutes() async {
    for (var id in addedRoutesId) {
      await removeRoute(id);
    }
  }

  Future<void> _removeSource() async {
    await safeExecute(
      () async {
        await _map.style.removeStyleSource(_routeSourceId);
      },
      operationName: 'removeRouteSource',
      shouldDispose: false,
    );
  }

  Future<void> zoomToRoute({
    GeoJSONLineString? route,
    double paddingPixels = 50.0,
    int animationDuration = 1000,
  }) async {
    _logger.info("Is route null : ${route == null}");
    _logger.info(
      "Is active route null : ${activeRoute == null || activeRoute!.coordinates.isEmpty}",
    );
    _logger.info("Active route: ${activeRoute?.coordinates.length}");
    if (route == null &&
        (activeRoute == null || activeRoute!.coordinates.isEmpty)) {
      return;
    }
    await zoomToFitPoints(
      _map,
      route?.points ?? activeRoute!.points,
      paddingPixels: paddingPixels,
      animationDuration: animationDuration,
      logger: _logger,
    );
  }

  @override
  Future<void> dispose() async {
    if (isDisposed) return;

    _logger.info("Cleaning Route Mode Data");

    safeExecuteSync(() {
      _map.setOnMapTapListener(null);
    }, operationName: 'clearMapTapListener');

    await removeAllRoutes();
    await _removeSource();

    _logger.info('Route Mode Data Cleared');
    isDisposed = true;
  }
}
