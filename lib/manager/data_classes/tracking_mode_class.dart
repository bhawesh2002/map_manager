import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/manager/map_assets.dart';
import 'package:map_manager_mapbox/map_manager_mapbox.dart';
import 'package:map_manager_mapbox/utils/enums.dart';
import 'package:map_manager_mapbox/utils/extensions.dart';
import 'package:map_manager_mapbox/utils/geolocator_utils.dart';
import 'package:map_manager_mapbox/utils/predefined_layers_props.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../tweens/point_tween.dart';

class TrackingModeClass implements ModeHandler {
  TrackingMode mode;
  final MapboxMap _map;
  TrackingModeClass(this.mode, this._map);

  static late final AnimationController _controller;
  static bool _controllerSet = false;

  static const String _featureCollectionSourceId = 'tracking-features-source';
  static const String _userFeatureSourceId = 'user-feature-source';
  static const String _personFeatureSourceId = 'person-feature-source';
  static const String _routeLayerId = 'route-layer';
  static const String _personLayerId = 'person-layer';
  static const String _userLayerId = 'user-layer';

  final GeoJSONFeature userGeoFeature = GeoJSONFeature(null);
  final GeoJSONFeature personGeoFeature = GeoJSONFeature(null);
  final GeoJSONFeature routeGeoFeature = GeoJSONFeature(null);

  bool _userLayerExists = false;
  bool _personLayerExists = false;
  bool _routeLayerExists = false;

  GeoJSONLineString get plannedRoute =>
      GeoJSONLineString.fromMap(mode.geojson['geometry']);

  GeoJSONPoint? get userGeoPoint => userGeoFeature.geometry != null
      ? GeoJSONPoint.fromMap(userGeoFeature.geometry!.toMap())
      : null;
  GeoJSONPoint? get personGeoPoint => personGeoFeature.geometry != null
      ? GeoJSONPoint.fromMap(personGeoFeature.geometry!.toMap())
      : null;

  GeoJSONFeature get activeSourceFeature =>
      mode.source == RouteTraversalSource.person
          ? personGeoFeature
          : userGeoFeature;
  GeoJSONPoint? get activeSourceLoc => activeSourceFeature.geometry != null
      ? GeoJSONPoint.fromMap(activeSourceFeature.geometry!.toMap())
      : null;
  GeoJSONFeatureCollection get featureCollection =>
      GeoJSONFeatureCollection([activeSourceFeature, routeGeoFeature]);

  ValueNotifier<LocationUpdate?>? _personNotifier;
  ValueNotifier<LocationUpdate?> get activeNotifier =>
      mode.source == RouteTraversalSource.person
          ? _personNotifier!
          : GeolocatorUtils.positionValueNotifier;

  VoidCallback? _activeNotifierListener;
  VoidCallback? _userLocationListener;
  VoidCallback? _personLocationListener;

  final List<LocationUpdate> _locUpdateQueue = [];
  final List<LocationUpdate> _personLocUpdateQueue = [];
  bool updatingPersonLoc = false;
  final List<LocationUpdate> _userLocUpdateQueue = [];
  bool updatingUserLoc = false;

  bool _isAnimating = false;
  bool _isProcessing = false;
  LineString _routeTraversed = LineString(coordinates: []);
  LineString get routeTraversed => _routeTraversed;

  final Logger _logger = Logger('RideTrackingModeClass');

  void setAnimController(AnimationController animController) {
    if (!_controllerSet) {
      _controller = animController;
      _controllerSet = true;
    }
  }

  static Future<TrackingModeClass> initialize(TrackingMode mode, MapboxMap map,
      AnimationController animController) async {
    TrackingModeClass cls = TrackingModeClass(mode, map);
    cls.setAnimController(animController);

    await map.style.addSource(
        GeoJsonSource(id: _featureCollectionSourceId, lineMetrics: true));
    await map.style.addSource(GeoJsonSource(id: _userFeatureSourceId));
    await map.style.addSource(GeoJsonSource(id: _personFeatureSourceId));

    await cls._addRouteLayer();
    return cls;
  }

  Future<void> startTracking() async {
    assert(
        !(mode.source == RouteTraversalSource.person &&
            _personNotifier == null),
        'you must first add person to tracking mode');
    await setRouteTrackingMode(mode.source);
    _activeNotifierListener = _addToUpdateQueue;
    activeNotifier.addListener(_activeNotifierListener!);
    _logger.info("Now tracking ride route");
  }

  Future<void> setRouteTrackingMode(RouteTraversalSource source) async {
    _locUpdateQueue.clear();
    mode = mode.copyWith(source: source);
    switch (source) {
      case RouteTraversalSource.user:
        _locUpdateQueue.addAll(_userLocUpdateQueue);
        _stopUserTracking(force: true);
        if (!_userLayerExists) await _addUserLayer();
        await _map.style.setStyleLayerProperty(
            _userLayerId, 'source', _featureCollectionSourceId);
      case RouteTraversalSource.person:
        _locUpdateQueue.addAll(_personLocUpdateQueue);
        stopPersonTracking(force: true);
        if (!_personLayerExists) await _addPersonLayer();
        await _map.style.setStyleLayerProperty(
            _personLayerId, 'source', _featureCollectionSourceId);
    }
  }

  void _addToUpdateQueue() async {
    final update = activeNotifier.value;
    if (update == null) return;
    _locUpdateQueue.add(update);
    _routeTraversed = LineString(coordinates: [
      ...routeTraversed.coordinates,
      update.location.coordinates
    ]);
    if (!_isProcessing) {
      _processQueue();
    }
  }

  void _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      while (_locUpdateQueue.isNotEmpty) {
        final current = _locUpdateQueue.removeAt(0);
        _isAnimating = false;
        await _animateLocationUpdate(current);
      }
    } catch (e) {
      _logger.severe("Error processing location queue: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _animateLocationUpdate(LocationUpdate update) async {
    try {
      if (_isAnimating) return;

      _isAnimating = true;
      final tween = PointTween(
        begin: activeSourceLoc?.toMbPoint() ?? update.location,
        end: update.location,
      );

      final animation = tween.animate(
        CurvedAnimation(parent: _controller, curve: Curves.linear),
      );
      // int frameCount = 0;
      void listener() {
        // if (frameCount++ % 3 != 0) return;
        _updateGeojson(animation.value.toGeojsonPoint());
        Future.delayed(const Duration(milliseconds: 16), () async {
          await _map.style.setStyleSourceProperty(
            _featureCollectionSourceId,
            'data',
            featureCollection.toMap(),
          );
        });
      }

      animation.addListener(listener);

      try {
        await _controller.forward(from: 0);
        await moveMapCamTo(_map, update.location);
      } finally {
        animation.removeListener(listener);
      }
    } catch (e) {
      _updateGeojson(update.location.toGeojsonPoint());
      await _map.style.setStyleSourceProperty(
        _featureCollectionSourceId,
        'data',
        featureCollection.toMap(),
      );
    }
  }

  void _updateGeojson(GeoJSONPoint point) {
    final geom = routeGeoFeature.geometry as GeoJSONLineString;
    activeSourceFeature.geometry = point;
    final newCoordinates = updateRouteGeojson(point, geom.coordinates);
    if (newCoordinates != null) geom.coordinates = newCoordinates;
    routeGeoFeature.geometry = geom;
  }

  Future<void> _addRouteLayer() async {
    try {
      routeGeoFeature.geometry = plannedRoute;
      routeGeoFeature.properties != null
          ? routeGeoFeature.properties!['type'] = 'route'
          : routeGeoFeature.properties = {'type': 'route'};
      await _map.style.addLayer(LineLayer(
        id: _routeLayerId,
        sourceId: _featureCollectionSourceId,
        filter: [
          "==",
          ["get", "type"],
          "route"
        ],
      ));
      await _map.style
          .setStyleLayerProperties(_routeLayerId, json.encode(routeLayerProps));
      await _map.style.setStyleSourceProperty(
          _featureCollectionSourceId, 'data', featureCollection.toMap());
      _routeLayerExists = true;
      _logger.info("Route layer added successfully");
    } catch (e) {
      _logger.warning("Error adding planned route: $e");
      rethrow;
    }
  }

  Future<void> _addPersonLayer({GeoJSONPoint? point}) async {
    if (_personLayerExists) return;
    personGeoFeature.geometry = point;
    personGeoFeature.properties != null
        ? personGeoFeature.properties!['type'] = 'person'
        : personGeoFeature.properties = {'type': 'person'};
    await _map.style.addStyleImage(
        '${_personLayerId}_img',
        1.0,
        MbxImage(width: 100, height: 139, data: MapAssets.personLoc),
        false,
        [],
        [],
        null);
    await _map.style.addLayer(
      SymbolLayer(
          id: _personLayerId,
          sourceId: _personFeatureSourceId,
          filter: [
            "==",
            ["get", "type"],
            "person"
          ]),
    );
    await _map.style.setStyleLayerProperties(
        _personLayerId, jsonEncode(personLayerProps('${_personLayerId}_img')));
    _personLayerExists = true;
    _logger.info("Person layer added successfully");
  }

  Future<void> _addUserLayer() async {
    if (_userLayerExists) return;
    await _map.style.addLayer(CircleLayer(
      id: _userLayerId,
      sourceId: _userFeatureSourceId,
    ));
    await _map.style
        .setStyleLayerProperties(_userLayerId, jsonEncode(userLayerProps));
    _userLayerExists = true;
    _logger.info("User layer added successfully");
  }

  Future<void> _addUserToTracking() async {
    if (_userLocationListener != null) _stopUserTracking();
    await GeolocatorUtils.startLocationUpdates();
    _userLocationListener = _updateUserLocation;
    GeolocatorUtils.positionValueNotifier.addListener(_userLocationListener!);
    _logger.info("User location tracking started");
  }

  Future<void> addPersonToTracking(
      ValueNotifier<LocationUpdate?> personNotifier) async {
    if (_personLocationListener != null) await stopPersonTracking();
    if (!_personLayerExists) await _addPersonLayer();
    _personNotifier = personNotifier;
    _personLocationListener = _updatePersonLocation;
    _personNotifier!.addListener(_personLocationListener!);
    _logger.info("Person location tracking started");
  }

  void _stopUserTracking({bool force = false}) {
    if (_userLocationListener != null) {
      GeolocatorUtils.positionValueNotifier
          .removeListener(_userLocationListener!);
      _userLocationListener = null;
      if (force) _userLocUpdateQueue.clear();
    }
  }

  Future<void> stopPersonTracking(
      {bool removePersonLayer = false, bool force = false}) async {
    if (_personLocationListener != null) {
      _personNotifier?.removeListener(_personLocationListener!);
      _personLocationListener = null;
      if (force) _personLocUpdateQueue.clear();
      if (removePersonLayer) await _removePersonLayer();
    }
  }

  Future<void> _updateUserLocation() async {
    final update = GeolocatorUtils.update;
    if (update == null) return;
    _userLocUpdateQueue.add(update);
    !updatingUserLoc ? _updateUserVisualization() : null;
  }

  Future<void> _updatePersonLocation() async {
    final update = _personNotifier?.value;
    if (update == null) return;
    _personLocUpdateQueue.add(update);
    (!updatingPersonLoc) ? _updatePersonVisualization() : null;
  }

  Future<void> _updateUserVisualization() async {
    try {
      updatingUserLoc = true;
      while (_userLocUpdateQueue.isNotEmpty) {
        final update = _userLocUpdateQueue.removeAt(0);
        final tween = PointTween(
            begin: userGeoPoint?.toMbPoint() ?? update.location,
            end: update.location);
        for (var i = 0; i < 80; i++) {
          final lerp = tween.lerp(i / 80);
          userGeoFeature.geometry = lerp.toGeojsonPoint();
          await _map.style.setStyleSourceProperty(
              _userFeatureSourceId, 'data', userGeoFeature.toMap());
        }
        await _map.style.setStyleSourceProperty(
            _userFeatureSourceId, 'data', userGeoFeature.toMap());
      }
      updatingUserLoc = false;
    } catch (e) {
      _logger.warning("Error updating user visualization: $e");
    }
  }

  Future<void> _updatePersonVisualization() async {
    try {
      updatingPersonLoc = true;
      while (_personLocUpdateQueue.isNotEmpty) {
        final update = _personLocUpdateQueue.removeAt(0);
        final tween = PointTween(
            begin: personGeoPoint?.toMbPoint() ?? update.location,
            end: update.location);
        for (var i = 0; i < 80; i++) {
          final lerp = tween.lerp(i / 80);
          personGeoFeature.geometry = lerp.toGeojsonPoint();
          await _map.style.setStyleSourceProperty(
              _personFeatureSourceId, 'data', personGeoFeature.toMap());
        }
        await _map.style.setStyleSourceProperty(
            _personFeatureSourceId, 'data', personGeoFeature.toMap());
      }

      updatingPersonLoc = false;
    } catch (e) {
      _logger.warning("Error updating person visualization: $e");
    }
  }

  Future<void> _removePersonLayer() async {
    if (!_personLayerExists) return;
    try {
      await _map.style.removeStyleLayer(_personLayerId);
      await _map.style.removeStyleImage('${_personLayerId}_img');
      _personLayerExists = false;
    } catch (e) {
      _logger.warning("Error removing person layer: $e");
    }
  }

  Future<void> _removeSources(
      {bool featureSrc = false,
      bool userSrc = false,
      bool personSrc = false}) async {
    if (featureSrc) {
      if (await _map.style.styleSourceExists(_featureCollectionSourceId)) {
        await _map.style.removeStyleSource(_featureCollectionSourceId);
      }
    }
    if (personSrc) {
      if (await _map.style.styleSourceExists(_personFeatureSourceId)) {
        await _map.style.removeStyleSource(_personFeatureSourceId);
      }
    }
    if (userSrc) {
      if (await _map.style.styleSourceExists(_userFeatureSourceId)) {
        await _map.style.removeStyleSource(_userFeatureSourceId);
      }
    }
  }

  Future<void> _removeLayers(
      {bool routeLayer = false,
      bool userLayer = false,
      bool personLayer = false}) async {
    if (routeLayer && _routeLayerExists) {
      await _map.style.removeStyleLayer(_routeLayerId);
    }
    if (userLayer && _userLayerExists) {
      await _map.style.removeStyleLayer(_userLayerId);
    }
    if (personLayer && _personLayerExists) _removePersonLayer();
  }

  @override
  Future<void> dispose() async {
    _logger.info("Cleaning Tracking Mode Data");
    _map.setOnMapTapListener(null);
    try {
      _stopUserTracking();
      await stopPersonTracking();
      await _removeLayers(routeLayer: true, userLayer: true, personLayer: true);
      await _removeSources(featureSrc: true, userSrc: true, personSrc: true);
      if (_activeNotifierListener != null) {
        activeNotifier.removeListener(_activeNotifierListener!);
      }
      _activeNotifierListener = null;
    } catch (e) {
      _logger.warning("Error removing feature collection layers/source: $e");
    }
    _controller.reset();

    _locUpdateQueue.clear();
    _isAnimating = false;
    _userLayerExists = false;
    _personLayerExists = false;
    updatingPersonLoc = false;
    updatingUserLoc = false;
    _personNotifier = null;

    await _map.location.updateSettings(
      LocationComponentSettings(enabled: false),
    );
    _logger.info("Tracking Mode Data Cleared");
  }
}
