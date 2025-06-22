import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/manager/map_assets.dart';
import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:map_manager_mapbox/manager/map_utils.dart';
import 'package:map_manager_mapbox/utils/utils.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:synchronized/synchronized.dart';

import '../location_update.dart';
import '../mode_handler.dart';
import '../tweens/point_tween.dart';

class TrackingModeClass implements ModeHandler {
  final TrackingMode mode;
  final MapboxMap _map;
  TrackingModeClass(this.mode, this._map);

  static late final AnimationController _controller;
  static bool _controllerSet = false;
  //Variables for adding route and waypoints - modernized LineLayer approach
  static const String _routeSourceId = 'tracking-route-source';
  static const String _routeLayerId = 'tracking-route-layer';
  static const String _traversedRouteSourceId = 'tracking-traversed-source';
  static const String _traversedRouteLayerId = 'tracking-traversed-layer';
  LineString? _plannedRoute;
  PointAnnotationManager? _waypointManager;
  List<PointAnnotation?> _waypoints = [];

  //Variables for live location tracking
  PointAnnotationManager? _personAnnoManager;
  PointAnnotation? _personAnno;
  ValueNotifier<LocationUpdate?>? _locNotifier;
  LocationUpdate? lastKnownLoc;
  final List<LocationUpdate> _queue = [];
  bool _isAnimating = false;
  bool _isUpdatingPersonAnno = false;
  final _personAnnoLock = Lock();
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
    await cls._createAnnotationManagers();

    // Add planned route from either LineString or GeoJSON
    if (mode.route != null || mode.geojson != null) {
      await cls._addPlannedRoute(
          route: mode.route, geojson: mode.geojson, waypoints: mode.waypoints);
    }

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

  /// Updates the traversed route visualization using LineLayer
  /// This shows the actual path taken by the user in real-time
  // ignore: unused_element
  Future<void> _updateTraversedRoute() async {
    if (_routeTraversed.coordinates.length < 2) return;

    try {
      // Check if traversed route layer already exists
      bool layerExists = false;
      try {
        await _map.style.getStyleLayerProperty(_traversedRouteLayerId, 'id');
        layerExists = true;
      } catch (e) {
        // Layer doesn't exist yet
      }

      if (!layerExists) {
        // Create the source and layer for traversed route
        final traversedData = {
          "type": "Feature",
          "geometry": _routeTraversed.toJson(),
          "properties": {}
        };

        final geoJsonSource =
            GeoJsonSource(id: _traversedRouteSourceId, lineMetrics: true);
        await _map.style.addSource(geoJsonSource);
        await _map.style.setStyleSourceProperty(
          _traversedRouteSourceId,
          'data',
          traversedData,
        );

        // Create traversed route layer with green styling
        final traversedLineLayer = LineLayer(
          id: _traversedRouteLayerId,
          sourceId: _traversedRouteSourceId,
          lineWidth: 7.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.9,
          lineGradientExpression: [
            'interpolate',
            ['linear'],
            ['line-progress'],
            0.0,
            "#0BE3E3",
            0.3,
            "#0BE389",
            0.7,
            "#0BE328",
            1.0,
            "#0BE3CA",
          ],
          lineBlur: 0.0,
          lineBorderColor: 0xFFFFFFFF,
          lineBorderWidth: 1.5,
          lineZOffset: 1.0,
        );

        await _map.style.addLayer(traversedLineLayer);
      } else {
        // Update existing source data
        final traversedData = {
          "type": "Feature",
          "geometry": _routeTraversed.toJson(),
          "properties": {}
        };

        await _map.style.setStyleSourceProperty(
          _traversedRouteSourceId,
          'data',
          traversedData,
        );
      }
    } catch (e) {
      _logger.warning("Error updating traversed route: $e");
    }
  }

  void _processQueue() async {
    // Quick check without acquiring the lock
    if (_isAnimating) return;

    // Check if there are items to process with lock
    bool noItems = true;
    while (noItems) {
      noItems = _queue.isEmpty;
      if (!noItems) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    await _queueLock.synchronized(() async {
      _isAnimating = true;
      try {
        // Get the next item from the queue with lock
        final current = _queue.removeAt(0);
        _logger.info("Processing queue item ${current.location.toJson()}");

        final tween = PointTween(
          begin: lastKnownLoc?.location ?? current.location,
          end: current.location,
        );

        final animation = tween.animate(
          CurvedAnimation(parent: _controller, curve: Curves.ease),
        );

        void listener() => _updatePersonAnno(animation.value);

        animation.addListener(listener);

        try {
          await _controller.forward(from: 0);
          lastKnownLoc = current;
        } finally {
          animation.removeListener(listener);
          _isAnimating = false;
        }
      } catch (e) {
        _logger.severe("Error processing location queue: $e");
      }
    }).then((val) {
      _processQueue();
    });
  }

  /// Creates a route using LineLayer and GeoJsonSource for the planned route
  /// Either provide a LineString route OR a GeoJSON map, but not both
  Future<void> _addPlannedRoute(
      {LineString? route,
      Map<String, dynamic>? geojson,
      List<Point>? waypoints}) async {
    assert(!(route == null && geojson == null),
        "Either route or geojson must be provided");
    assert(!(route != null && geojson != null),
        "Both route and geojson cannot be provided");

    try {
      GeoJsonSource? geoJsonSource;
      if (route != null) {
        _plannedRoute = route; // Store the planned route
        final data = {
          "type": "Feature",
          "geometry": route.toJson(),
          "properties": {}
        };
        // Create GeoJSON source with line metrics enabled for gradient support
        geoJsonSource = GeoJsonSource(id: _routeSourceId, lineMetrics: true);
        await _map.style.addSource(geoJsonSource);
        await _map.style.setStyleSourceProperty(
          _routeSourceId,
          'data',
          data,
        );
      } else {
        // For geojson input, try to extract LineString if possible
        if (geojson!['type'] == 'Feature' &&
            geojson['geometry']?['type'] == 'LineString') {
          _plannedRoute = LineString.fromJson(geojson['geometry']);
        }
        // Create GeoJSON source with line metrics enabled for gradient support
        geoJsonSource = GeoJsonSource(id: _routeSourceId, lineMetrics: true);
        await _map.style.addSource(geoJsonSource);
        await _map.style.setStyleSourceProperty(
          _routeSourceId,
          'data',
          geojson,
        );
      }

      // Create and add the line layer for planned route with blue styling
      final lineLayer = LineLayer(
        id: _routeLayerId,
        sourceId: _routeSourceId,

        // Planned route styling - Blue/gray for intended path
        lineWidth: 10.0, // Slightly thinner than traversed route
        lineCap: LineCap.ROUND, // Smooth rounded ends
        lineJoin: LineJoin.ROUND, // Smooth rounded corners
        lineOpacity: 0.9, // More transparent to show it's planned

        // Blue gradient for planned route
        lineGradientExpression: [
          'interpolate', // Smooth color interpolation
          ['linear'], // Linear interpolation method
          ['line-progress'], // Use line progress (0.0 to 1.0)
          0.0,
          "#0BE3E3",
          0.4,
          "#0B69E3",
          0.6,
          "#0B4CE3",
          1.0,
          "#890BE3",
        ],

        // Border effects
        lineBlur: 0.0, // Sharp edges
        lineBorderColor: 0xFFFFFFFF, // White border for contrast
        lineBorderWidth: 1.0, // Thin border

        // Z-positioning (below traversed route)
        lineZOffset: -1.0, // Place below traversed route
      );

      // Add the planned route layer to the map style
      await _map.style.addLayer(lineLayer);

      // Add waypoint markers
      await _addWaypoints(waypoints: [
        if (_plannedRoute != null)
          Point(coordinates: _plannedRoute!.coordinates.first),
        ...(waypoints ?? []),
        if (_plannedRoute != null)
          Point(coordinates: _plannedRoute!.coordinates.last)
      ]);

      // Move camera to show the start of the route
      if (_plannedRoute != null) {
        await _map.flyTo(
            CameraOptions(
                center: Point(coordinates: _plannedRoute!.coordinates.first)),
            MapAnimationOptions());
      }
    } catch (e) {
      _logger.warning("Error adding planned route: $e");
      rethrow;
    }
  }

  Future<void> _addWaypoints(
      {required List<Point?> waypoints, List<ByteData>? asset}) async {
    final waypts1 = await _waypointManager!.createMulti([
      PointAnnotationOptions(
          image: asset != null
              ? addImageFromAsset(asset.first)
              : MapAssets.selectedLoc,
          iconOffset: [0, -28],
          geometry: waypoints.removeAt(0)!),
      PointAnnotationOptions(
        image: asset != null
            ? addImageFromAsset(asset.last)
            : MapAssets.selectedLoc,
        iconOffset: [0, -28],
        geometry: waypoints.removeAt(waypoints.length - 1)!,
      ),
    ]);

    final wayPts2 = await _waypointManager!
        .createMulti(List.generate(waypoints.length, (index) {
      return PointAnnotationOptions(
          iconOffset: [0, -12], iconSize: 1.45, geometry: waypoints[index]!);
    }));
    _waypoints = [...waypts1, ...wayPts2];
  }

  Future<void> _updatePersonAnno(Point point) async {
    await _personAnnoLock.synchronized(() async {
      try {
        _isUpdatingPersonAnno = true;
        if (_personAnno == null) {
          _logger.info("Person anno is null, creating new annotation");
          _personAnno = await _personAnnoManager!.create(
            PointAnnotationOptions(
                image: MapAssets.personLoc,
                geometry: point,
                iconOffset: [0, -28]),
          );
        } else {
          await _personAnnoManager!.update(
            PointAnnotation(id: _personAnno!.id, geometry: point),
          );
        }
        await moveMapCamTo(_map, point, duration: 200);
      } catch (e) {
        _logger.severe("Error updating person annotation: $e");
        rethrow;
      } finally {
        _isUpdatingPersonAnno = false;
      }
    });
  }

  Future<void> _createAnnotationManagers() async {
    _waypointManager = await _map.annotations
        .createPointAnnotationManager(id: 'waypointManager');
    _personAnnoManager = await _map.annotations
        .createPointAnnotationManager(id: 'personManager');
  }

  @override
  Future<void> dispose() async {
    _logger.info("Cleaning Tracking Mode Data");

    // Clear tap listener to prevent crashes from stale handlers
    _map.setOnMapTapListener(null);

    // Remove planned route layer and source
    try {
      await _map.style.removeStyleLayer(_routeLayerId);
      await _map.style.removeStyleSource(_routeSourceId);
    } catch (e) {
      _logger.warning("Error removing planned route layer/source: $e");
    }

    // Remove traversed route layer and source
    // try {
    //   await _map.style.removeStyleLayer(_traversedRouteLayerId);
    //   await _map.style.removeStyleSource(_traversedRouteSourceId);
    // } catch (e) {
    //   _logger.warning("Error removing traversed route layer/source: $e");
    // }

    // Remove waypoint annotations
    if (_waypoints.isNotEmpty) {
      try {
        await _waypointManager?.deleteAll();
        _waypoints.clear();
      } catch (e) {
        _logger.warning("Error removing waypoint annotations: $e");
      }
    }

    // Remove waypoint annotation manager
    try {
      await _map.annotations.removeAnnotationManagerById('waypointManager');
    } catch (e) {
      _logger.warning("Error removing waypoint annotation manager: $e");
    }
    _waypointManager = null;

    // Clear tracking data and person annotation
    if (_personAnno != null) {
      try {
        await _personAnnoManager?.delete(_personAnno!);
      } catch (e) {
        _logger.warning("Error removing person annotation: $e");
      }
    }
    _personAnno = null;

    // Remove person annotation manager
    try {
      await _map.annotations.removeAnnotationManagerById('personManager');
    } catch (e) {
      _logger.warning("Error removing person annotation manager: $e");
    }
    _personAnnoManager = null;

    // Reset animation controller and tracking state
    _controller.reset();
    _locNotifier?.removeListener(_addToUpdateQueue);
    _locNotifier = null;
    lastKnownLoc = null;
    _queue.clear();
    _isAnimating = false;
    _plannedRoute = null;
    _routeTraversed = LineString(coordinates: []);

    // Disable location component
    try {
      await _map.location.updateSettings(
        LocationComponentSettings(enabled: false),
      );
    } catch (e) {
      _logger.warning("Error disabling location component: $e");
    }

    _logger.info("Tracking Mode Data Cleared");
  }
}
