import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:map_manager/manager/map_assets.dart';
import 'package:map_manager/map_manager.dart';
import 'package:map_manager/models/traversal_pair.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class TrackingModeClass implements ModeHandler {
  TrackingMode mode;
  final MapboxMap _map;
  TrackingModeClass(this.mode, this._map);

  static late final AnimationController _controller;
  static bool _controllerSet = false;

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

  void _setAnimController(AnimationController animController) {
    if (!_controllerSet) {
      _controller = animController;
      _controllerSet = true;
    }
  }

  static Future<TrackingModeClass> initialize(
    TrackingMode mode,
    MapboxMap map,
    AnimationController animController,
  ) async {
    TrackingModeClass cls = TrackingModeClass(mode, map);
    cls._setAnimController(animController);
    await cls._setupSource();
    if (mode.initialRoutes != null) {
      for (var rt in mode.initialRoutes!.entries) {
        await cls.addRoute(rt.value, identifier: rt.key);
      }
    }
    await GeolocatorUtils.startLocationUpdates();
    return cls;
  }

  Future<void> _setupSource() async {
    try {
      await _map.style.addStyleImage(
        'def-image',
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
      await _map.style.addSource(
        GeoJsonSource(id: _routesSourceId, lineMetrics: true),
      );
      await _map.style.addSource(GeoJsonSource(id: _waypointsSourceId));
    } catch (e) {
      _logger.severe("Error while setting up sources: $e");
    }
  }

  static int _routesAddCount = 0;
  Future<void> addRoute(
    GeoJSONFeature route, {
    String? identifier,
    bool setActive = false,
  }) async {
    try {
      identifier ??= "route-$_routesAddCount";
      route.properties ??= {};
      route.properties!['active'] = setActive;
      route.properties!['route-id'] = identifier;
      _routesMap.putIfAbsent(identifier, () {
        _routesAddCount++;
        return route;
      });

      await _updateRoute();

      await _map.style.addLayer(
        LineLayer(
          id: _routeLayerId + identifier,
          sourceId: _routesSourceId,
          filter: [
            "==",
            ["get", "route-id"],
            identifier,
          ],
        ),
      );

      final styling =
          route.properties?['styling'] as Map<String, dynamic>? ??
          routeLayerProps;
      await applyLayerStyling(
        styling: styling,
        layerId: _routeLayerId + identifier,
      );
    } catch (e) {
      _logger.warning("Error adding route: $e");
      rethrow;
    }
  }

  static int _waypointsAddCount = 0;
  Future<void> addWaypoint(GeoJSONFeature point, {String? identifier}) async {
    try {
      if (identifier == null) {
        identifier = 'waypoint-$_waypointsAddCount';
        _waypointsAddCount++;
      }
      point.properties ??= {};
      point.properties!['waypoint-id'] = identifier;
      _waypointsMap[identifier] = point;

      await _updateWaypoints();

      await _map.style.addLayer(
        SymbolLayer(
          id: _waypointLayerId + identifier,
          sourceId: _waypointsSourceId,
          filter: [
            "==",
            ["get", "waypoint-id"],
            identifier,
          ],
        ),
      );

      final styling =
          point.properties?['styling'] as Map<String, dynamic>? ??
          symbolLayerProps('def-image');
      await applyLayerStyling(
        styling: styling,
        layerId: _waypointLayerId + identifier,
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

    await _map.style.addSource(
      GeoJsonSource(
        id: identifier,
        data: traversalPair.traversalFeatureCollection.toJSON(),
      ),
    );
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
    // Current position marker
    await _map.style.addLayer(
      SymbolLayer(
        id: '$pairId-point',
        sourceId: pairId,
        filter: [
          "==",
          ["get", "traversal-source-id"],
          '$pairId-source',
        ],
      ),
    );
    await applyLayerStyling(
      styling: sourceStyling ?? symbolLayerProps('def-image'),
      layerId: "$pairId-point",
    );

    // Traversed route (completed path)
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
    await applyLayerStyling(
      styling: traversedRouteStyling ?? traversedRouteLayerProps,
      layerId: "$pairId-traversed",
    );

    // Remaining route (path ahead)
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
    await applyLayerStyling(
      styling: remainingRouteStyling ?? routeLayerProps,
      layerId: "$pairId-remaining",
    );
  }

  Future<void> applyLayerStyling({
    required Map<String, dynamic> styling,
    required String layerId,
  }) async {
    try {
      await _map.style.setStyleLayerProperties(layerId, jsonEncode(styling));
    } catch (e) {
      _logger.severe("applyRouteStyle(): $e");
    }
  }

  /// Updates the route in real-time with new coordinates
  Future<void> _updateRoute() async {
    try {
      await _map.style.setStyleSourceProperty(
        _routesSourceId,
        'data',
        _routesFeatureCollection.toJSON(),
      );
      _logger.info("Route updated successfully.");
    } catch (e) {
      _logger.severe("Error updating route: $e");
      rethrow;
    }
  }

  Future<void> _updateWaypoints() async {
    try {
      await _map.style.setStyleSourceProperty(
        _waypointsSourceId,
        'data',
        _waypointsFeatureCollection.toJSON(),
      );
      _logger.info("Waypoints updated successfully.");
    } catch (e) {
      _logger.severe("Error updating waypoints: $e");
      rethrow;
    }
  }

  Future<void> updateTraversalPair(String pairId) async {
    final pair = _traversalPairMap[pairId];
    if (pair == null) return;

    try {
      await _map.style.setStyleSourceProperty(
        pairId,
        'data',
        pair.traversalFeatureCollection.toJSON(),
      );
      _logger.info("Traversal pair $pairId updated successfully.");
    } catch (e) {
      _logger.severe("Error updating traversal pair $pairId: $e");
      rethrow;
    }
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
    try {
      await _map.style.removeStyleSource(sourceId);
    } catch (e) {
      _logger.severe("Error removing source: $e");
    }
  }

  Future<void> removeLayer(String layerId) async {
    try {
      await _map.style.removeStyleLayer(layerId);
    } catch (e) {
      _logger.severe("Error removing source: $e");
    }
  }

  Future<void> removeAllRoutes() async {
    for (var id in routeIds) {
      await removeLayer(id);
    }
  }

  Future<void> removeAllWaypoints() async {
    for (var id in waypointIds) {
      await removeLayer(id);
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
    _logger.info("Cleaning Tracking Mode Data");
    _map.setOnMapTapListener(null);

    _controller.reset();

    await removeAllTraversalSources();
    await removeAllLayers();
    await _removeSource(_routesSourceId);
    await _removeSource(_waypointsSourceId);

    await _map.location.updateSettings(
      LocationComponentSettings(enabled: false),
    );
    _logger.info("Tracking Mode Data Cleared");
  }
}
