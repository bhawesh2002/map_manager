import 'dart:isolate';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/map_manager_mapbox.dart';
import 'package:map_manager_mapbox/utils/extensions.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:synchronized/synchronized.dart';

import '../tweens/point_tween.dart';
import 'route_calculation_isolate.dart';

class TrackingModeClass implements ModeHandler {
  final TrackingMode mode;
  final MapboxMap _map;
  TrackingModeClass(this.mode, this._map);

  static late final AnimationController _controller;
  static bool _controllerSet = false;

  // Feature collection source and layer IDs
  static const String _featureCollectionSourceId = 'tracking-features-source';
  static const String _routeLayerId = 'tracking-route-layer';
  static const String _personLayerId = 'tracking-person-layer';

  // Cached features
  GeoJSONFeature? personGeoFeature;
  late GeoJSONFeature routeGeoFeature;

  GeoJSONPoint? get personGeoPoint => personGeoFeature != null
      ? GeoJSONPoint.fromMap(personGeoFeature!.geometry!.toMap())
      : null;
  GeoJSONLineString? get routeGeoLineString =>
      GeoJSONLineString.fromMap(routeGeoFeature.geometry!.toMap());

  // Combined feature collection
  Map<String, dynamic> get featureCollection => {
        "type": "FeatureCollection",
        "features": [
          if (personGeoFeature != null) personGeoFeature!,
          routeGeoFeature
        ]
      };

  //Variables for live location tracking
  late GeoJSONLineString _plannedRoute;
  GeoJSONLineString get plannedRoute => _plannedRoute;
  ValueNotifier<LocationUpdate?>? _locNotifier;
  LocationUpdate? lastKnownLoc;
  final List<LocationUpdate> _queue = [];
  bool _isAnimating = false;

  final _mapUpdateLock = Lock();
  final _queueLock = Lock(reentrant: true);

  //Variable holding the route traversed
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

    // Start the queue processing loop - this will self-perpetuate as long as items are in the queue
    _processQueue();
  }

  // This method handles the location updates from the ValueNotifier
  void _addToUpdateQueue() {
    final update = _locNotifier?.value;
    if (update == null) return;
    _queue.add(update);
    _logger.info("Adding location update to queue at ${_queue.length}");
    _routeTraversed = LineString(coordinates: [
      ...routeTraversed.coordinates,
      update.location.coordinates
    ]);
    // No longer calling _processQueue here as it's started once in startTracking
  }

  void _processQueue() async {
    bool noItems = true;
    while (noItems) {
      noItems = _queue.isEmpty;
      if (!noItems) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    await _queueLock.synchronized(() async {
      try {
        final current = _queue.removeAt(0);
        lastKnownLoc = current;
        _logger.info("Processing queue item ${current.location.toJson()}");
        await _animateLocationUpdate(current);
      } catch (e) {
        _logger.severe("Error processing location queue: $e");
      } finally {
        _isAnimating = false;
      }
    }).then((val) {
      _processQueue();
    });
  }

  /// Animates the person marker from its current position to the new location
  ///
  /// Creates a smooth animation using a tween and the animation controller
  Future<void> _animateLocationUpdate(LocationUpdate update) async {
    try {
      if (_isAnimating) return;
      _isAnimating = true;
      final tween = PointTween(
        begin: lastKnownLoc?.location ?? update.location,
        end: update.location,
      );

      final animation = tween.animate(
        CurvedAnimation(parent: _controller, curve: Curves.ease),
      );
      void listener() async {
        personGeoFeature!.geometry = update.location.toGeojsonPoint();
        final routeData = await _calculateRouteInIsolate(update);
        if (routeData != null) {
          routeGeoFeature.geometry = routeData.updatedRoute;
        }
        await _updateMapVisualization(addMissingLayers: true);
      }

      animation.addListener(listener);

      try {
        await _controller.forward(from: 0);
      } finally {
        animation.removeListener(listener);
      }

      _logger.info("Person marker animation completed");
    } catch (e) {
      _logger.warning("Error animating person marker: $e");
      personGeoFeature!.geometry = update.location.toGeojsonPoint();
      final routeData = calculateUpdatedRoute(update.location.toGeojsonPoint(),
          routeGeoFeature.geometry as GeoJSONLineString);
      if (routeData != null) {
        routeGeoFeature.geometry = routeData.updatedRoute;
      }
      await _updateMapVisualization(addMissingLayers: true);
    }
  }

  /// Calculates route updates in a separate isolate to avoid blocking the main thread
  ///
  /// Returns a map with route update information or null if no update is needed
  Future<RouteCalculationData?> _calculateRouteInIsolate(
      LocationUpdate update) async {
    try {
      _logger.info("Starting route calculation in isolate");

      // Create a ReceivePort for receiving the result
      final receivePort = ReceivePort();

      // Convert the planned route to GeoJSON coordinates
      final routeCoordinates = routeGeoLineString!.coordinates;

      // Create the message to send to the isolate
      final message = RouteCalculationMessage(
        update: update,
        routeCoordinates: routeCoordinates,
        sendPort: receivePort.sendPort,
      );

      // Start the isolate
      final isolate = await Isolate.spawn(routeCalculationIsolate, message);

      // Wait for the result from the isolate
      final result = await receivePort.first as RouteCalculationResult;

      // Clean up the isolate
      isolate.kill(priority: Isolate.immediate);
      receivePort.close();

      // Handle the result
      if (result.success) {
        if (result.success) {
          _logger.info("Route calculation completed successfully in isolate");
          return result.routeData;
        } else {
          _logger.info("No route changes needed");
          return null;
        }
      } else {
        _logger.warning(
            "Error in route calculation isolate: ${result.errorMessage}");
        return null;
      }
    } catch (e) {
      _logger.severe("Error running route calculation isolate: $e");

      // Fallback to the original implementation if isolate fails
      _logger.info("Falling back to main thread calculation");
      return calculateUpdatedRoute(update.location.toGeojsonPoint(),
          routeGeoFeature.geometry as GeoJSONLineString);
    }
  }

  /// Creates a route using LineLayer and GeoJsonSource for the planned route
  /// Either provide a LineString route OR a GeoJSON map, but not both
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
    final circleLayer = CircleLayer(
        id: _personLayerId,
        sourceId: _featureCollectionSourceId,
        circleRadius: 10.0,
        circleColor: 0xFF0078D4, // Blue color
        circleStrokeWidth: 2.0,
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

  /// Updates the map visualization with the combined feature collection
  /// This updates both the person marker and route in a single operation
  Future<void> _updateMapVisualization({bool addMissingLayers = false}) async {
    try {
      await _mapUpdateLock.synchronized(() async {
        if (addMissingLayers) {
          final personLayerExists =
              await _map.style.getLayer(_personLayerId) != null;
          final routeLayerExists =
              await _map.style.getLayer(_routeLayerId) != null;

          if (!routeLayerExists) {
            await _addRouteLayer(
                geojson:
                    GeoJSONFeature(routeTraversed.toGeojsonLineStr()).toMap());
          }
          if (personGeoFeature == null || !personLayerExists) {
            await _addPersonLayer(
                lastKnownLoc!.location.toGeojsonPoint().coordinates);
          }
        }
        await _map.style.setStyleSourceProperty(
          _featureCollectionSourceId,
          'data',
          featureCollection,
        );
      });
    } catch (e) {
      _logger.severe("Error updating map visualization: $e");
    }
  }

  @override
  Future<void> dispose() async {
    _logger.info("Cleaning Tracking Mode Data");
    _map.setOnMapTapListener(null);

    try {
      // Clean up the feature collection source and layers
      await _map.style.removeStyleLayer(_routeLayerId);
      await _map.style.removeStyleLayer(_personLayerId);
      await _map.style.removeStyleSource(_featureCollectionSourceId);
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
