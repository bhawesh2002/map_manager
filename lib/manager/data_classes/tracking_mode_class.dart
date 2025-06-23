import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/manager/map_assets.dart';
import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:map_manager_mapbox/manager/map_utils.dart';
import 'package:map_manager_mapbox/utils/extensions.dart';
import 'package:map_manager_mapbox/utils/utils.dart';
import 'package:map_manager_mapbox/utils/route_utils.dart';
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
    await cls._addPlannedRoute(
        geojson: mode.geojson, waypoints: mode.waypoints);

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
        if (_isAnimating) return;
        _isAnimating = true;
        final current = _queue.removeAt(0);
        _logger.info("Processing queue item ${current.location.toJson()}");
        await _animatePersonMarker(current);
        lastKnownLoc = current;
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
  Future<void> _animatePersonMarker(LocationUpdate update) async {
    try {
      final tween = PointTween(
        begin: lastKnownLoc?.location ?? update.location,
        end: update.location,
      );

      final animation = tween.animate(
        CurvedAnimation(parent: _controller, curve: Curves.ease),
      );

      void listener() => _updatePersonAnno(animation.value);

      animation.addListener(listener);

      try {
        await _controller.forward(from: 0);
      } finally {
        animation.removeListener(listener);
      }

      _logger.info("Person marker animation completed");
    } catch (e) {
      _logger.warning("Error animating person marker: $e");
      // Still update the marker to the final position even if animation fails
      await _updatePersonAnno(update.location);
    }
  }

  /// Creates a route using LineLayer and GeoJsonSource for the planned route
  /// Either provide a LineString route OR a GeoJSON map, but not both
  Future<void> _addPlannedRoute(
      {required Map<String, dynamic> geojson, List<Point>? waypoints}) async {
    try {
      GeoJsonSource? geoJsonSource;
      if (geojson['type'] == 'Feature' &&
          geojson['geometry']?['type'] == 'LineString') {
        // Create GeoJSON source with line metrics enabled for gradient support
        geoJsonSource = GeoJsonSource(id: _routeSourceId, lineMetrics: true);
        await _map.style.addSource(geoJsonSource);
        await _map.style.setStyleSourceProperty(
          _routeSourceId,
          'data',
          geojson,
        );
        _plannedRoute = LineString.fromJson(geojson['geometry']);
      }

      // Create and add the line layer for planned route with blue styling
      final lineLayer = LineLayer(
          id: _routeLayerId,
          sourceId: _routeSourceId,
          lineWidth: 10.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.9,
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
        await moveMapCamTo(
            _map, Point(coordinates: _plannedRoute!.coordinates.first));
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
      } catch (e) {
        _logger.severe("Error updating person annotation: $e");
        rethrow;
      }
    });
  }

  /// Calculates an updated route based on the user's current location
  /// Returns a map with update information or null if no update is needed
  Map<String, dynamic>? _calculateUpdatedRoute(LocationUpdate update) {
    // Skip if no planned route exists
    if (_plannedRoute == null) return null;
    try {
      _logger.info(
          "Calculating updated route based on location: ${update.location}");
      final userLocation = update.location.toGeojsonPoint();
      // Convert Mapbox LineString coordinates to GeoJSON format
      List<List<double>> geoJsonCoords =
          _plannedRoute!.toGeojsonLineStr().coordinates;

      // Extra safeguard - ensure we have at least 2 coordinates for the LineString
      if (geoJsonCoords.length < 2) {
        _logger.warning(
            "Route has fewer than 2 points - adding duplicate end point");
        if (geoJsonCoords.isNotEmpty) {
          // Duplicate the last point to ensure we have at least 2 points
          geoJsonCoords.add(List<double>.from(geoJsonCoords.last));
        } else {
          // If somehow we have no points, we can't process
          _logger.severe("Route has no points - cannot process");
          return null;
        }
      }

      final geoRoute = _plannedRoute!.toGeojsonLineStr();
      final routePoints = lineStringToPoints(geoRoute);
      if (routePoints.length < 2) {
        _logger.info(
            "Route too short for processing (${routePoints.length} points)");
        return null;
      }
      final checkResult =
          isUserOnRoute(userLocation, routePoints, thresholdMeters: 50.0);

      RouteUpdateResult routeUpdateResult;
      bool isOnRoute = checkResult.isOnRoute;

      if (isOnRoute) {
        _logger.info(
            "User is on route - shrinking route at segment ${checkResult.segmentIndex}");
        // User is on route - shrink
        routeUpdateResult = shrinkRoute(checkResult.projectedPoint,
            checkResult.segmentIndex, checkResult.projectionRatio, routePoints);
        if (routeUpdateResult.isNearlyComplete) {
          _logger
              .info("Route nearly complete - maintaining minimal valid route");
        }
      } else {
        _logger.info(
            "User is off route (${checkResult.distance}m away) - growing route");
        // User is off route - grow
        routeUpdateResult = growRoute(userLocation, routePoints);
      }

      // Only return data if there's actually a change
      if (routeUpdateResult.hasChanged) {
        // Log segment change information
        if (routeUpdateResult.changedSegmentIndex >= 0) {
          _logger.info(
              '''Route segment changed at index: ${routeUpdateResult.changedSegmentIndex}, 
              isGrowing: ${routeUpdateResult.isGrowing}, 
              isNearlyComplete: ${routeUpdateResult.isNearlyComplete}''');
        }

        final updatedGeoJsonLineString =
            pointsToLineString(routeUpdateResult.updatedRoute);
        final data = {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": updatedGeoJsonLineString.coordinates
          },
          "properties": {}
        };
        return {
          "data": data,
          "isOnRoute": isOnRoute,
          "distanceFromRoute": checkResult.distance,
          "routeChanged": true,
          "changedSegmentIndex": routeUpdateResult.changedSegmentIndex,
          "originalSegment": routeUpdateResult.originalSegment,
          "newSegment": routeUpdateResult.newSegment,
          "isGrowing": routeUpdateResult.isGrowing,
          "isNearlyComplete": routeUpdateResult.isNearlyComplete,
          "updatedRoutePoints": routeUpdateResult.updatedRoute
        };
      } else {
        _logger.info("No significant route change needed");
        return {
          "routeChanged": false,
          "isOnRoute": isOnRoute,
          "distanceFromRoute": checkResult.distance
        };
      }
    } catch (e) {
      _logger.warning("Error calculating updated route: $e");
      if (e.toString().contains('coordinates.length >= 2')) {
        _logger.warning(
            "Route has fewer than 2 points - this typically happens at the end of a route");
      }
      return null;
    }
  }

  /// Updates the route visualization on the map based on the calculated route data
  ///  /// This method handles updating the GeoJSON source data and the planned route
  /// object based on the results from _calculateUpdatedRoute
  Future<void> _updateRouteVisualization(Map<String, dynamic> routeData) async {
    if (!(routeData['routeChanged'] as bool)) {
      return;
    }
    try {
      _logger.info("Updating route visualization");

      // Get the GeoJSON data
      final Map<String, dynamic> data =
          routeData['data'] as Map<String, dynamic>;

      // Update existing source data
      await _map.style.setStyleSourceProperty(
        _routeSourceId,
        'data',
        data,
      );
      _logger.info("Updated existing route source");
      _logger.info("Route visualization updated successfully");
    } catch (e) {
      _logger.severe("Error updating route visualization: $e");
    }
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
