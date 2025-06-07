import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../location_update.dart';
import '../tweens/point_tween.dart';

class RideTrackingModeClass {
  static late final AnimationController _controller;
  static bool _controllerSet = false;

  //Variables for adding route and waypoints
  PolylineAnnotationManager? _routeManager;
  PolylineAnnotation? _route;
  PointAnnotationManager? _waypointManager;
  List<PointAnnotation?> _waypoints = [];

  //Variables for live location tracking
  PointAnnotationManager? _personAnnoManager;
  PointAnnotation? _personAnno;
  ValueNotifier<LocationUpdate?>? _locNotifier;
  LocationUpdate? lastKnownLoc;
  final List<LocationUpdate> _queue = [];
  bool _isAnimating = false;

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

  static Future<RideTrackingModeClass> initialize(
      MapboxMap map, LineString route, AnimationController animController,
      {List<Point>? waypoints}) async {
    RideTrackingModeClass cls = RideTrackingModeClass();
    cls.setAnimController(animController);
    await map.location.updateSettings(LocationComponentSettings(enabled: true));
    await cls._createAnnotationManagers(map);
    await cls._addRideRoute(map, route);
    return cls;
  }

  Future<void> startTracking(ValueNotifier<LocationUpdate?> personLoc) async {
    _locNotifier = personLoc;
    _locNotifier!.addListener(_addToUpdateQueue);
    _logger.info("Tracking Ride Route");
  }

  void _addToUpdateQueue() {
    final update = _locNotifier!.value;
    if (update != null) {
      _queue.add(update);
      _routeTraversed = LineString(coordinates: [
        ...routeTraversed.coordinates,
        update.location.coordinates
      ]);
      _logger.info(_routeTraversed.coordinates.length);
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isAnimating || _queue.isEmpty) return;

    _isAnimating = true;

    final current = _queue.removeAt(0);

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
      _processQueue();
    }
  }

  Future<void> _addRideRoute(MapboxMap map, LineString route,
      {List<Point>? waypoints}) async {
    await _addLineString(route);
    await _addWaypoints(waypoints: [
      Point(coordinates: route.coordinates.first),
      ...(waypoints ?? []),
      Point(coordinates: route.coordinates.last)
    ]);
    await map.flyTo(
        CameraOptions(center: Point(coordinates: route.coordinates.first)),
        MapAnimationOptions());
  }

  Future<void> _addLineString(LineString route) async {
    _route = await _routeManager!.create(PolylineAnnotationOptions(
      geometry: route,
      lineWidth: 8,
      lineColor: AppColors.routeColor.value,
    ));
  }

  Future<void> _addWaypoints({required List<Point?> waypoints}) async {
    final waypts1 = await _waypointManager!.createMulti([
      PointAnnotationOptions(
          image: MapAssets.navArrow, geometry: waypoints.removeAt(0)!),
      PointAnnotationOptions(
        image: MapAssets.selectedLoc,
        iconOffset: [0, -28],
        geometry: waypoints.removeAt(waypoints.length - 1)!,
      ),
    ]);

    final wayPts2 = await _waypointManager!
        .createMulti(List.generate(waypoints.length, (index) {
      return PointAnnotationOptions(
          image: MapAssets.selectedLoc,
          iconOffset: [0, -12],
          iconSize: 1.45,
          geometry: waypoints[index]!);
    }));
    _waypoints = [...waypts1, ...wayPts2];
  }

  Future<void> _updatePersonAnno(Point point) async {
    if (_personAnno == null) {
      _personAnno = await _personAnnoManager!.create(
        PointAnnotationOptions(
            geometry: point, iconOffset: [0, -28], image: MapAssets.pickup),
      );
    } else {
      await _personAnnoManager!.update(
        PointAnnotation(id: _personAnno!.id, geometry: point),
      );
    }
  }

  Future<void> _createAnnotationManagers(MapboxMap map) async {
    _routeManager = await map.annotations
        .createPolylineAnnotationManager(id: 'routeManager');
    _waypointManager = await map.annotations
        .createPointAnnotationManager(id: 'waypointManager');
    _personAnnoManager =
        await map.annotations.createPointAnnotationManager(id: 'personManager');
  }

  Future<void> cleanRideTrackingData(MapboxMap map) async {
    //remove route
    await _routeManager?.delete(_route!);
    _route = null;
    _routeManager = null;
    //remove waypoint(if any)
    if (_waypoints.isNotEmpty) {
      await _waypointManager!.deleteAll();
      _waypoints.clear();
    }
    _waypointManager = null;

    //clear tracking data
    if (_personAnno != null) await _personAnnoManager!.delete(_personAnno!);
    _personAnno = null;
    _personAnnoManager = null;
    _controller.reset();
    _locNotifier = null;
    lastKnownLoc = null;
    _queue.clear();
    _isAnimating = false;
    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: false,
      ),
    );

    _logger.info("Ride Tracking Mode Data Cleared");
  }
}
