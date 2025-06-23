import 'dart:isolate';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:map_manager_mapbox/manager/map_utils.dart';
import 'package:map_manager_mapbox/utils/extensions.dart';
import 'package:map_manager_mapbox/utils/route_utils.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:synchronized/synchronized.dart';

import '../location_update.dart';
import '../mode_handler.dart';
import '../tweens/point_tween.dart';
import 'route_calculation_isolate.dart';

class TrackingModeClass implements ModeHandler {
  final TrackingMode mode;
  final MapboxMap _map;
  TrackingModeClass(this.mode, this._map);

  static late final AnimationController _controller;
  static bool _controllerSet = false;

  //Variables for adding route and waypoints - modernized LineLayer approach
  static const String _routeSourceId = 'tracking-route-source';
  static const String _routeLayerId = 'tracking-route-layer';

  // Person location source and layer IDs
  static const String _personSourceId = 'tracking-person-source';
  static const String _personLayerId = 'tracking-person-layer';
  Map<String, dynamic>? personGeoFeature;
  LineString? _plannedRoute;

  //Variables for live location tracking
  ValueNotifier<LocationUpdate?>? _locNotifier;
  LocationUpdate? lastKnownLoc;
  final List<LocationUpdate> _queue = [];
  bool _isAnimating = false;
  final _personUpdateLock = Lock();
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

        // Start person marker animation
        await _animatePersonMarker(current);

        // Calculate route updates in isolate if we have a planned route
        if (_plannedRoute != null) {
          final routeData = await _calculateRouteInIsolate(current);

          // Update route visualization if there are changes
          if (routeData != null && routeData['routeChanged'] == true) {
            await _updateRouteVisualization(routeData);
          }
        }

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

      void listener() => _updatePersonGeojsonSource(animation.value);

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
      await _updatePersonGeojsonSource(update.location);
    }
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

  Future<void> _updatePersonGeojsonSource(Point point) async {
    await _personUpdateLock.synchronized(() async {
      try {
        final coords = point.toGeojsonPoint().coordinates;
        if (personGeoFeature == null) {
          await _addPersonGeojsonSource(point);
          return;
        }
        personGeoFeature!['geometry']['coordinates'] = coords;

        await _map.style.setStyleSourceProperty(
          _personSourceId,
          'data',
          personGeoFeature!,
        );

        _logger.info("Updated person location: $coords");
      } catch (e) {
        _logger.severe("Error updating person location: $e");
        rethrow;
      }
    });
  }

  Future<void> _addPersonGeojsonSource(Point point) async {
    // Create person location GeoJSON source
    try {
      if (personGeoFeature != null) return;

      // Create the GeoJSON source for person location
      final personSource = GeoJsonSource(id: _personSourceId);
      await _map.style.addSource(personSource);

      // Create empty GeoJSON point feature
      personGeoFeature = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": point.toGeojsonPoint().coordinates
        },
        "properties": {"type": "person"}
      };

      // Set initial data
      await _map.style
          .setStyleSourceProperty(_personSourceId, 'data', personGeoFeature!);

      // Create a circle layer for the person location
      final circleLayer = CircleLayer(
          id: _personLayerId,
          sourceId: _personSourceId,
          circleRadius: 10.0,
          circleColor: 0xFF0078D4, // Blue color
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF, // White border
          circlePitchAlignment: CirclePitchAlignment.MAP);

      await _map.style.addLayer(circleLayer);
      _logger.info("Created person location source and layer");
    } catch (e) {
      _logger.severe("Error creating person location source/layer: $e");
    }
  }

  /// Calculates route updates in a separate isolate to avoid blocking the main thread
  ///
  /// Returns a map with route update information or null if no update is needed
  Future<Map<String, dynamic>?> _calculateRouteInIsolate(
      LocationUpdate update) async {
    if (_plannedRoute == null) return null;

    try {
      _logger.info("Starting route calculation in isolate");

      // Create a ReceivePort for receiving the result
      final receivePort = ReceivePort();

      // Convert the planned route to GeoJSON coordinates
      final routeCoordinates = _plannedRoute!.toGeojsonLineStr().coordinates;

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
        if (result.routeData != null) {
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
      return _calculateUpdatedRoute(update);
    }
  }

  @override
  Future<void> dispose() async {
    _logger.info("Cleaning Tracking Mode Data");
    _map.setOnMapTapListener(null);
    try {
      await _map.style.removeStyleLayer(_routeLayerId);
      await _map.style.removeStyleSource(_routeSourceId);
    } catch (e) {
      _logger.warning("Error removing planned route layer/source: $e");
    }
    try {
      await _map.style.removeStyleLayer(_personLayerId);
      await _map.style.removeStyleSource(_personSourceId);
      _logger.info("Removed person location layer and source");
    } catch (e) {
      _logger.warning("Error removing person location layer/source: $e");
    }
    _controller.reset();
    _locNotifier?.removeListener(_addToUpdateQueue);
    _locNotifier = null;
    lastKnownLoc = null;
    _queue.clear();
    _isAnimating = false;
    _plannedRoute = null;

    await _map.location.updateSettings(
      LocationComponentSettings(enabled: false),
    );
    _logger.info("Tracking Mode Data Cleared");
  }
}
