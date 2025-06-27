import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/manager/map_assets.dart';
import 'package:map_manager_mapbox/map_manager_mapbox.dart';
import 'package:map_manager_mapbox/utils/enums.dart';
import 'package:map_manager_mapbox/utils/extensions.dart';
import 'package:map_manager_mapbox/utils/geolocator_utils.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../tweens/point_tween.dart';

class TrackingModeClass implements ModeHandler {
  final TrackingMode mode;
  final MapboxMap _map;
  TrackingModeClass(this.mode, this._map);

  static late final AnimationController _controller;
  static bool _controllerSet = false;

  static const String _featureCollectionSourceId = 'tracking-features-source';
  static const String _routeLayerId = 'tracking-route-layer';
  static const String _personLayerId = 'tracking-person-layer';
  static const String _userFeatureSourceId = 'user-feature-source';
  static const String _userLayerId = 'user-layer';
  static const String _personLocImageId = 'person-loc-image';

  late final GeoJSONFeature userGeoFeature = GeoJSONFeature(null);
  GeoJSONFeature? personGeoFeature;
  late GeoJSONFeature routeGeoFeature;

  bool _userLayerExists = false;
  bool _personLayerExists = false;
  bool _routeLayerExists = false;

  GeoJSONPoint? get userGeoPoint => userGeoFeature.geometry != null
      ? GeoJSONPoint.fromMap(userGeoFeature.geometry!.toMap())
      : null;
  GeoJSONPoint? get personGeoPoint => personGeoFeature != null
      ? GeoJSONPoint.fromMap(personGeoFeature!.geometry!.toMap())
      : null;
  GeoJSONLineString? get routeGeoLineString => routeGeoFeature.geometry != null
      ? GeoJSONLineString.fromMap(routeGeoFeature.geometry!.toMap())
      : null;
  GeoJSONFeatureCollection get featureCollection => GeoJSONFeatureCollection(
      [if (personGeoFeature != null) personGeoFeature!, routeGeoFeature]);
  late GeoJSONLineString _plannedRoute;
  GeoJSONLineString get plannedRoute => _plannedRoute;

  VoidCallback? _userLocationListener;
  ValueNotifier<LocationUpdate?>? _personNotifier;
  LocationUpdate? personLastKnownLoc;
  VoidCallback? _personLocationListener;

  final List<LocationUpdate> _queue = [];
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
    await cls._addUserLayer();
    await cls._addRouteLayer(geojson: mode.geojson, waypoints: mode.waypoints);
    return cls;
  }

  Future<void> startTracking(
      {RouteTraversalSource source = RouteTraversalSource.user,
      ValueNotifier<LocationUpdate?>? personLoc}) async {
    assert(!(source == RouteTraversalSource.person && personLoc == null),
        'personLoc cannot be null if route traversal source is person');

    // Start user stream if not already started
    await _startUserStream();

    // Start person stream if provided
    if (personLoc != null) {
      await _startPersonStream(personLoc);
    }

    _logger.info("Now tracking ride route");
  }

  void _addToUpdateQueue(LocationUpdate update) async {
    if (!_personLayerExists && _personNotifier?.value != null) {
      await addPersonLayer(update.location.toGeojsonPoint().coordinates);
    }
    _queue.add(update);
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
      while (_queue.isNotEmpty) {
        final current = _queue.removeAt(0);
        _isAnimating = false;
        await _animateLocationUpdate(current);
        personLastKnownLoc = current;
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
        begin: personLastKnownLoc?.location ?? update.location,
        end: update.location,
      );

      final animation = tween.animate(
        CurvedAnimation(parent: _controller, curve: Curves.linear),
      );
      int frameCount = 0;
      void listener() {
        if (frameCount++ % 3 != 0) return;

        _updateGeojson(animation.value.toGeojsonPoint());

        _updateMapVisualization();
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
      await _updateMapVisualization();
    }
  }

  void _updateGeojson(GeoJSONPoint point) {
    final geom = routeGeoFeature.geometry as GeoJSONLineString;
    personGeoFeature?.geometry = point;
    final newCoordinates = updateRouteGeojson(point, geom.coordinates);
    if (newCoordinates != null) {
      geom.coordinates = newCoordinates;
    }
    routeGeoFeature.geometry = geom;
  }

  Future<void> _addRouteLayer(
      {required Map<String, dynamic> geojson, List<Point>? waypoints}) async {
    try {
      routeGeoFeature = GeoJSONFeature.fromMap(geojson);
      if (routeGeoFeature.properties != null) {
        routeGeoFeature.properties!['type'] = 'route';
      } else {
        routeGeoFeature.properties = {'type': 'route'};
      }
      _plannedRoute = GeoJSONLineString.fromMap(geojson['geometry']);
      final lineLayer = LineLayer(
          id: _routeLayerId,
          sourceId: _featureCollectionSourceId,
          lineWidth: 8.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.9,
          filter: [
            "==",
            ["get", "type"],
            "route"
          ],
          lineGradientExpression: [
            'interpolate',
            ['linear'],
            ['line-progress'],
            0.0,
            "#0BE3E3",
            0.4,
            "#0B69E3",
            0.6,
            "#0B4CE3",
            1.0,
            "#890BE3",
          ],
          lineBlur: 0.0,
          lineZOffset: -1.0);

      await _map.style.addLayer(lineLayer);
      _routeLayerExists = true;
      await _updateMapVisualization();
    } catch (e) {
      _logger.warning("Error adding planned route: $e");
      rethrow;
    }
  }

  Future<void> _addPersonLayer(List<double> point) async {
    personGeoFeature = GeoJSONFeature(GeoJSONPoint(point));
    if (personGeoFeature!.properties != null) {
      personGeoFeature!.properties!['type'] = 'person';
    } else {
      personGeoFeature!.properties = {'type': 'person'};
    }
    await _map.style.addStyleImage(
        _personLocImageId,
        1.0,
        MbxImage(width: 100, height: 139, data: MapAssets.personLoc),
        false,
        [],
        [],
        null);
    await _map.style.addLayer(
      SymbolLayer(
          id: _personLayerId,
          sourceId: _featureCollectionSourceId,
          iconImage: _personLocImageId,
          iconSize: 0.45,
          iconOffset: [
            0,
            -64
          ],
          filter: [
            "==",
            ["get", "type"],
            "person"
          ]),
    );

    await _updateMapVisualization();
  }

  Future<void> _addUserLayer() async {
    if (_userLayerExists) return; // Already exists

    await GeolocatorUtils.startLocationUpdates();
    final circleLayer = CircleLayer(
      id: _userLayerId,
      sourceId: _userFeatureSourceId,
      circleRadius: 8,
      circleColor: 0xFF0078D4,
      circleStrokeWidth: 4.0,
      circleStrokeColor: 0xFFFFFFFF,
      circlePitchAlignment: CirclePitchAlignment.MAP,
    );

    await _map.style.addLayer(circleLayer);
    _userLayerExists = true;
    _logger.info("User layer added successfully");
  }

  Future<void> _updateMapVisualization() async {
    try {
      await _map.style.setStyleSourceProperty(
        _featureCollectionSourceId,
        'data',
        featureCollection.toMap(),
      );
    } catch (e) {
      _logger.severe(
          "_updateMapVisualization: Error updating map visualization: $e");
    }
  }

  // Stream management methods
  Future<void> _startUserStream() async {
    if (_userLocationListener != null) return; // Already started

    await GeolocatorUtils.startLocationUpdates();
    _userLocationListener = () {
      _updateUserLocation(GeolocatorUtils.update);
    };
    GeolocatorUtils.positionValueNotifier.addListener(_userLocationListener!);

    _logger.info("User location stream started");
  }

  Future<void> _startPersonStream(
      ValueNotifier<LocationUpdate?> personNotifier) async {
    if (_personLocationListener != null) {
      await _stopPersonStream(); // Clean up existing subscription
    }

    _personNotifier = personNotifier;
    _personLocationListener = () {
      _updatePersonLocation();
    };
    _personNotifier!.addListener(_personLocationListener!);

    // Add person layer if it doesn't exist
    if (!_personLayerExists) {
      final initialLocation = personNotifier.value;
      if (initialLocation != null) {
        await addPersonLayer(
            initialLocation.location.toGeojsonPoint().coordinates);
      }
    }

    _logger.info("Person location stream started");
  }

  Future<void> _stopUserStream() async {
    if (_userLocationListener != null) {
      GeolocatorUtils.positionValueNotifier
          .removeListener(_userLocationListener!);
      _userLocationListener = null;
    }
  }

  Future<void> _stopPersonStream() async {
    if (_personLocationListener != null) {
      _personNotifier?.removeListener(_personLocationListener!);
      _personLocationListener = null;
    }
    _personNotifier = null;
    _logger.info("Person location stream stopped");
  }

  void _updateUserLocation(LocationUpdate? update) {
    if (update == null) return;

    // Update user layer visualization
    _updateUserVisualization(update);

    // Add to processing queue (this will handle route traversal logic later)
    _addToUpdateQueue(update);
  }

  void _updatePersonLocation() {
    final update = _personNotifier?.value;
    if (update == null) return;

    // Update person layer visualization
    _updatePersonVisualization(update);

    // Add to processing queue (this will handle route traversal logic later)
    _addToUpdateQueue(update);
  }

  Future<void> _updateUserVisualization(LocationUpdate update) async {
    try {
      final tween = PointTween(
          begin: userGeoPoint?.toMbPoint() ?? update.location,
          end: update.location);

      // Smooth animation for user marker
      for (var i = 0; i < 80; i++) {
        final lerp = tween.lerp(i / 80);
        userGeoFeature.geometry = lerp.toGeojsonPoint();
        await _map.style.setStyleSourceProperty(
            _userFeatureSourceId, 'data', userGeoFeature.toMap());
      }

      await moveMapCamTo(_map, update.location);
    } catch (e) {
      _logger.warning("Error updating user visualization: $e");
    }
  }

  Future<void> _updatePersonVisualization(LocationUpdate update) async {
    try {
      if (personGeoFeature != null) {
        personGeoFeature!.geometry = update.location.toGeojsonPoint();
        await _updateMapVisualization();
      }
    } catch (e) {
      _logger.warning("Error updating person visualization: $e");
    }
  }

  // Person layer management methods
  Future<void> addPersonLayer(List<double>? point) async {
    if (_personLayerExists) return; // Already exists

    if (point == null) {
      _logger.warning("Cannot add person layer without initial position");
      return;
    }

    await _addPersonLayer(point);
    _personLayerExists = true;
    _logger.info("Person layer added successfully");
  }

  Future<void> removePersonLayer() async {
    if (!_personLayerExists) return;
    try {
      await _map.style.removeStyleLayer(_personLayerId);
      await _map.style.removeStyleImage(_personLocImageId);
      personGeoFeature = null;
      _personLayerExists = false;
      _logger.info("Person layer removed successfully");
    } catch (e) {
      _logger.warning("Error removing person layer: $e");
    }
  }

  @override
  Future<void> dispose() async {
    _logger.info("Cleaning Tracking Mode Data");
    _map.setOnMapTapListener(null);
    try {
      if (_routeLayerExists) await _map.style.removeStyleLayer(_routeLayerId);
      if (_personLayerExists) await removePersonLayer();
      if (_userLayerExists) await _map.style.removeStyleLayer(_userLayerId);

      if (await _map.style.styleSourceExists(_featureCollectionSourceId)) {
        await _map.style.removeStyleSource(_featureCollectionSourceId);
      }

      if (await _map.style.styleSourceExists(_userFeatureSourceId)) {
        await _map.style.removeStyleSource(_userFeatureSourceId);
      }
    } catch (e) {
      _logger.warning("Error removing feature collection layers/source: $e");
    }
    _controller.reset();

    // Clean up stream subscriptions
    await _stopUserStream();
    await _stopPersonStream();

    personLastKnownLoc = null;
    _queue.clear();
    _isAnimating = false;
    personGeoFeature = null;
    _userLayerExists = false;
    _personLayerExists = false;

    await _map.location.updateSettings(
      LocationComponentSettings(enabled: false),
    );
    _logger.info("Tracking Mode Data Cleared");
  }
}
