import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/map_manager_mapbox.dart';
import 'package:map_manager_mapbox/utils/extensions.dart';
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
  GeoJSONFeature? personGeoFeature;
  late GeoJSONFeature routeGeoFeature;

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
  ValueNotifier<LocationUpdate?>? _locNotifier;
  LocationUpdate? lastKnownLoc;
  final List<LocationUpdate> _queue = [];
  bool _isAnimating = false;
  bool _isProcessing = false;
  LineString _routeTraversed = LineString(coordinates: []);
  LineString get routeTraversed => _routeTraversed;

  final Logger _logger = Logger('RideTrackingModeClass');

  bool _layersAdded = false;

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
    await map.location.updateSettings(LocationComponentSettings(enabled: true));
    await map.style.addSource(
        GeoJsonSource(id: _featureCollectionSourceId, lineMetrics: true));
    await cls._addRouteLayer(geojson: mode.geojson, waypoints: mode.waypoints);
    return cls;
  }

  Future<void> startTracking(ValueNotifier<LocationUpdate?> personLoc) async {
    _logger.info("Starting tracking");
    _locNotifier = personLoc;
    _locNotifier!.addListener(_addToUpdateQueue);
    _logger.info("Tracking Ride Route");
  }

  void _addToUpdateQueue() async {
    final update = _locNotifier?.value;
    if (update == null) return;
    if (!_layersAdded) {
      await _addPersonLayer(update.location.toGeojsonPoint().coordinates);
      _layersAdded = true;
    }
    _queue.add(update);
    _logger.info("Adding location update to queue at ${_queue.length}");
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
    _logger.info("_processQueue: Entered, queue length: ${_queue.length}");

    try {
      while (_queue.isNotEmpty) {
        final current = _queue.removeAt(0);
        _logger.info("Processing queue item ${current.location.toJson()}");
        final startTime = DateTime.now();
        _isAnimating = false;
        await _animateLocationUpdate(current);
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime).inMilliseconds;
        _logger.info("_processQueue: Animation took ${duration}ms");
        lastKnownLoc = current;
        _logger.info(
            "_processQueue: About to process next item, queue length: ${_queue.length}");
      }
      _logger.info("_processQueue: All items processed");
    } catch (e) {
      _logger.severe("Error processing location queue: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _animateLocationUpdate(LocationUpdate update) async {
    try {
      _logger.info(
          "_animateLocationUpdate: Starting animation for ${update.location.toJson()}");
      if (_isAnimating) {
        _logger.warning("_animateLocationUpdate: Already animating, skipping");
        return;
      }
      _isAnimating = true;
      final setupStartTime = DateTime.now();

      final tween = PointTween(
        begin: lastKnownLoc?.location ?? update.location,
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
      final setupEndTime = DateTime.now();
      final setupDuration =
          setupEndTime.difference(setupStartTime).inMilliseconds;
      _logger.info("_animateLocationUpdate: Setup took ${setupDuration}ms");

      try {
        final animationStartTime = DateTime.now();
        await _controller.forward(from: 0);
        final animationEndTime = DateTime.now();
        final animationDuration =
            animationEndTime.difference(animationStartTime).inMilliseconds;
        _logger.info(
            "_animateLocationUpdate: Controller animation took ${animationDuration}ms");

        final cameraStartTime = DateTime.now();
        await moveMapCamTo(_map, update.location);
        final cameraEndTime = DateTime.now();
        final cameraDuration =
            cameraEndTime.difference(cameraStartTime).inMilliseconds;
        _logger.info(
            "_animateLocationUpdate: Camera movement took ${cameraDuration}ms");
      } finally {
        animation.removeListener(listener);
        _logger.info(
            "_animateLocationUpdate: Animation completed for: ${update.location.toJson()}");
      }
    } catch (e) {
      _logger
          .warning("_animateLocationUpdate: Error animating person marker: $e");
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
    final circleLayer = CircleLayer(
        id: _personLayerId,
        sourceId: _featureCollectionSourceId,
        circleRadius: 12.5,
        circleColor: 0xFF0078D4, // Blue color
        circleStrokeWidth: 3.0,
        circleStrokeColor: 0xFFFFFFFF, // White border
        circlePitchAlignment: CirclePitchAlignment.MAP,
        filter: [
          "==",
          ["get", "type"],
          "person"
        ]);

    await _map.style.addLayer(circleLayer);
    await _updateMapVisualization();
  }

  Future<void> _updateMapVisualization() async {
    final startTime = DateTime.now();
    try {
      await _map.style.setStyleSourceProperty(
        _featureCollectionSourceId,
        'data',
        featureCollection.toMap(),
      );
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;
      _logger.info("_updateMapVisualization: Map update took ${duration}ms");
    } catch (e) {
      _logger.severe(
          "_updateMapVisualization: Error updating map visualization: $e");
    }
  }

  @override
  Future<void> dispose() async {
    _logger.info("Cleaning Tracking Mode Data");
    _map.setOnMapTapListener(null);

    try {
      // Clean up the feature collection source and layers
      if (await _map.style.styleLayerExists(_routeLayerId)) {
        await _map.style.removeStyleLayer(_routeLayerId);
      }
      if (await _map.style.styleLayerExists(_personLayerId)) {
        await _map.style.removeStyleLayer(_personLayerId);
      }
      if (await _map.style.styleSourceExists(_featureCollectionSourceId)) {
        await _map.style.removeStyleSource(_featureCollectionSourceId);
      }
      _logger.info("Removed feature collection source and layers");
    } catch (e) {
      _logger.warning("Error removing feature collection layers/source: $e");
    }

    _controller.reset();
    _locNotifier?.removeListener(_addToUpdateQueue);
    _locNotifier = null;
    lastKnownLoc = null;
    _queue.clear();
    _isAnimating = false;
    personGeoFeature = null;

    await _map.location.updateSettings(
      LocationComponentSettings(enabled: false),
    );
    _logger.info("Tracking Mode Data Cleared");
  }
}
