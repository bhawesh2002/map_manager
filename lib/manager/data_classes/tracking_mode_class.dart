import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:map_manager/manager/map_assets.dart';
import 'package:map_manager/map_manager.dart';
import 'package:map_manager/models/traversal_pair.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class TrackingModeClass extends ModeHandler {
  TrackingMode mode;
  final MapboxMap _map;
  TrackingModeClass(this.mode, this._map);

  static String get _routesSourceId => 'routes-source';
  static String get _waypointsSourceId => 'waypoints-source';

  static String get _routeLayerId => 'route-layer';
  static String get _waypointLayerId => 'waypoint-layer';

  final Map<String, GeoJSONFeature> _routesMap = {};
  List<String> get routeIds => _routesMap.keys.toList();
  final Map<String, GeoJSONFeature> _waypointsMap = {};
  List<String> get waypointIds => _waypointsMap.keys.toList();
  final Map<String, TraversalPair> _traversalPairMap = {};
  final Map<String, VoidCallback> _traversalListeners =
      {}; // Track listeners for cleanup

  GeoJSONFeatureCollection get _routesFeatureCollection =>
      GeoJSONFeatureCollection([..._routesMap.values]);
  GeoJSONFeatureCollection get _waypointsFeatureCollection =>
      GeoJSONFeatureCollection([..._waypointsMap.values]);

  final ManagerLogger _logger = ManagerLogger('RideTrackingModeClass');

  static Future<TrackingModeClass> initialize(
    TrackingMode mode,
    MapboxMap map,
    AnimationController animController,
  ) async {
    TrackingModeClass cls = TrackingModeClass(mode, map);
    await cls._setupSource();
    if (mode.initialRoutes != null) {
      for (var rt in mode.initialRoutes!.entries) {
        await cls.addRoute(rt.value, identifier: rt.key);
      }
    }
    return cls;
  }

  String get defWaypointImg => 'def-waypoint-image';
  Future<void> _setupSource() async {
    await safeExecute(() async {
      await _map.style.addStyleImage(
        defWaypointImg,
        0.5,
        MbxImage(
          width: MapAssets.personLoc.width,
          height: MapAssets.personLoc.height,
          data: MapAssets.personLoc.asset,
        ),
        false,
        [],
        [],
        null,
      );
    }, operationName: 'addTrackingImage');

    await safeExecute(() async {
      await _map.style.addSource(
        GeoJsonSource(id: _routesSourceId, lineMetrics: true),
      );
    }, operationName: 'addRoutesSource');

    await safeExecute(() async {
      await _map.style.addSource(GeoJsonSource(id: _waypointsSourceId));
    }, operationName: 'addWaypointsSource');
  }

  static int _routesAddCount = 0;
  Future<void> addRoute(
    GeoJSONFeature route, {
    String? identifier,
    bool setActive = false,
  }) async {
    try {
      final routeId = identifier ?? "route-$_routesAddCount";
      route.properties ??= {};
      route.properties!['active'] = setActive;
      route.properties!['route-id'] = routeId;
      _routesMap.putIfAbsent(routeId, () {
        _routesAddCount++;
        return route;
      });

      await _updateRoute();

      await safeExecute(() async {
        await _map.style.addLayer(
          LineLayer(
            id: _routeLayerId + routeId,
            sourceId: _routesSourceId,
            filter: [
              "==",
              ["get", "route-id"],
              routeId,
            ],
          ),
        );
      }, operationName: 'addRouteLayer');

      final styling =
          route.properties?['styling'] as Map<String, dynamic>? ??
          routeLayerProps;
      await applyLayerStyling(
        styling: styling,
        layerId: _routeLayerId + routeId,
      );
      final lineString = route.geometry as GeoJSONLineString;
      await zoomToFitPoints(_map, lineString.points, logger: _logger);
    } catch (e) {
      _logger.warning("Error adding route: $e");
      rethrow;
    }
  }

  static int _waypointsAddCount = 0;
  Future<void> addWaypoint(GeoJSONFeature point, {String? identifier}) async {
    try {
      final waypointId = identifier ?? 'waypoint-$_waypointsAddCount';
      if (identifier == null) {
        _waypointsAddCount++;
      }
      point.properties ??= {};
      point.properties!['waypoint-id'] = waypointId;
      _waypointsMap[waypointId] = point;

      await _updateWaypoints();

      await safeExecute(() async {
        await _map.style.addLayer(
          SymbolLayer(
            id: _waypointLayerId + waypointId,
            sourceId: _waypointsSourceId,
            filter: [
              "==",
              ["get", "waypoint-id"],
              waypointId,
            ],
          ),
        );
      }, operationName: 'addWaypointLayer');

      final styling =
          point.properties?['styling'] as Map<String, dynamic>? ??
          symbolLayerProps(defWaypointImg);
      await applyLayerStyling(
        styling: styling,
        layerId: _waypointLayerId + waypointId,
      );
    } catch (e) {
      _logger.severe("Error adding waypoint: $e");
      rethrow;
    }
  }

  static int _traversalSourceAddCount = 0;
  Future<void> addTraversalSource(
    ValueNotifier<LocationUpdate> traversalSource,
    String routeId, {
    String? identifier,
    Map<String, dynamic>? sourceStyling,
    Map<String, dynamic>? traversedRouteStyling,
    Map<String, dynamic>? remainingRouteStyling,
  }) async {
    if (!_routesMap.containsKey(routeId)) {
      throw ArgumentError('Route with ID "$routeId" not found');
    }

    identifier ??= 'traversal-$_traversalSourceAddCount';

    final traversalPair = TraversalPair(
      pairId: identifier,
      traversalSource: traversalSource,
      originalRoute: _routesMap[routeId]!,
    );

    _traversalPairMap.putIfAbsent(identifier, () {
      _traversalSourceAddCount++;
      return traversalPair;
    });

    void listener() {
      try {
        updateTraversalPair(identifier!);
      } catch (e) {
        _logger.severe("Error updating traversal pair $identifier: $e");
      }
    }

    traversalSource.addListener(listener);
    _traversalListeners[identifier] = listener;

    await safeExecute(() async {
      await _map.style.addSource(
        GeoJsonSource(
          id: traversalPair.pairId,
          data: traversalPair.traversalFeatureCollection.toJSON(),
          lineMetrics: true,
        ),
      );
    }, operationName: 'addTraversalSource');

    await _addTraversalFeatureLayer(
      identifier,
      sourceStyling: sourceStyling,
      traversedRouteStyling: traversedRouteStyling,
      remainingRouteStyling: remainingRouteStyling,
    );
  }

  Future<void> _addTraversalFeatureLayer(
    String pairId, {
    Map<String, dynamic>? sourceStyling,
    Map<String, dynamic>? traversedRouteStyling,
    Map<String, dynamic>? remainingRouteStyling,
  }) async {
    // Traversed route (completed path)
    await safeExecute(() async {
      await _map.style.addLayer(
        LineLayer(
          id: '$pairId-traversed',
          sourceId: pairId,
          filter: [
            "==",
            ["get", "traversed-route-id"],
            '$pairId-traversed',
          ],
        ),
      );
    }, operationName: 'addTraversedRouteLayer');

    await applyLayerStyling(
      styling: traversedRouteStyling ?? traversedRouteLayerProps,
      layerId: "$pairId-traversed",
    );

    // Remaining route (path ahead)
    await safeExecute(() async {
      await _map.style.addLayer(
        LineLayer(
          id: '$pairId-remaining',
          sourceId: pairId,
          filter: [
            "==",
            ["get", "remaining-route-id"],
            '$pairId-remaining',
          ],
        ),
      );
    }, operationName: 'addRemainingRouteLayer');

    await applyLayerStyling(
      styling: remainingRouteStyling ?? routeLayerProps,
      layerId: "$pairId-remaining",
    );

    // Current position marker
    await safeExecute(() async {
      await _map.style.addLayer(
        CircleLayer(
          id: '$pairId-point',
          sourceId: pairId,
          filter: [
            "==",
            ["get", "traversal-source-id"],
            '$pairId-source',
          ],
        ),
      );
    }, operationName: 'addTraversalPointLayer');

    await applyLayerStyling(
      styling: sourceStyling ?? userLayerProps,
      layerId: "$pairId-point",
    );
  }

  Future<void> applyLayerStyling({
    required Map<String, dynamic> styling,
    required String layerId,
  }) async {
    await safeExecute(() async {
      await _map.style.setStyleLayerProperties(layerId, jsonEncode(styling));
    }, operationName: 'applyLayerStyling_$layerId');
  }

  /// Updates the route in real-time with new coordinates
  Future<void> _updateRoute() async {
    await safeExecute(() async {
      await _map.style.setStyleSourceProperty(
        _routesSourceId,
        'data',
        _routesFeatureCollection.toJSON(),
      );
    }, operationName: 'updateRoute');
    _logger.info("Route updated successfully.");
  }

  Future<void> _updateWaypoints() async {
    await safeExecute(() async {
      await _map.style.setStyleSourceProperty(
        _waypointsSourceId,
        'data',
        _waypointsFeatureCollection.toJSON(),
      );
    }, operationName: 'updateWaypoints');
    _logger.info("Waypoints updated successfully.");
  }

  Future<void> updateTraversalPair(String pairId) async {
    final pair = _traversalPairMap[pairId];
    if (pair == null) return;

    await safeExecute(() async {
      await _map.style.setStyleSourceProperty(
        pairId,
        'data',
        pair.traversalFeatureCollection.toJSON(),
      );
    }, operationName: 'updateTraversalPair_$pairId');
  }

  Future<void> removeTraversalSource(String pairId) async {
    final pair = _traversalPairMap[pairId];
    final listener = _traversalListeners[pairId];

    if (pair != null && listener != null) {
      pair.traversalSource.removeListener(listener);
      _traversalListeners.remove(pairId);
    }

    // Remove map layers
    try {
      await removeLayer('$pairId-point');
      await removeLayer('$pairId-traversed');
      await removeLayer('$pairId-remaining');
      await _removeSource(pairId);

      _traversalPairMap.remove(pairId);
      _logger.info("Traversal source $pairId removed successfully.");
    } catch (e) {
      _logger.severe("Error removing traversal source $pairId: $e");
      rethrow;
    }
  }

  Future<void> _removeSource(String sourceId) async {
    await safeExecute(
      () async {
        await _map.style.removeStyleSource(sourceId);
      },
      operationName: 'removeTrackingSource_$sourceId',
      shouldDispose: false,
    );
  }

  Future<void> removeLayer(String layerId) async {
    await safeExecute(
      () async {
        await _map.style.removeStyleLayer(layerId);
      },
      operationName: 'removeTrackingLayer_$layerId',
      shouldDispose: false,
    );
  }

  Future<void> removeAllRoutes() async {
    for (var id in routeIds) {
      await removeLayer(_routeLayerId + id);
    }
  }

  Future<void> removeAllWaypoints() async {
    for (var id in waypointIds) {
      await removeLayer(_waypointLayerId + id);
    }
  }

  Future<void> removeAllTraversalSources() async {
    final pairIds = _traversalPairMap.keys.toList();
    for (var pairId in pairIds) {
      await removeTraversalSource(pairId);
    }
  }

  Future<void> removeAllLayers() async {
    try {
      await removeAllRoutes();
      await removeAllWaypoints();
      await removeAllTraversalSources();
    } catch (e) {
      _logger.severe("removeAllLayers(): $e");
    }
  }

  @override
  Future<void> dispose() async {
    if (isDisposed) return;

    _logger.info("Cleaning Tracking Mode Data");

    safeExecuteSync(() {
      _map.setOnMapTapListener((gesture) {});
    }, operationName: 'clearMapTapListener');

    await removeAllLayers();
    await _removeSource(_routesSourceId);
    await _removeSource(_waypointsSourceId);

    await safeExecute(
      () async {
        await _map.style.removeStyleImage(defWaypointImg);
      },
      operationName: "removeStyleImage_$defWaypointImg",
      shouldDispose: false,
    );

    _logger.info("Tracking Mode Data Cleared");
    isDisposed = true;
  }
}
