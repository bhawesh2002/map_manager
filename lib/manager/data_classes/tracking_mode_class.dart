import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/manager/map_assets.dart';
import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:map_manager_mapbox/utils/utils.dart';
import 'package:map_manager_mapbox/utils/route_utils.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:synchronized/synchronized.dart';
import 'package:geojson_vi/geojson_vi.dart';

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
        // Get the next item from the queue with lock
        final current = _queue.removeAt(0);
        _logger.info("Processing queue item ${current.location.toJson()}");

        // Animate the person annotation
        await _animatePersonMarker(current);

        // Calculate route updates based on the new location
        if (_plannedRoute != null) {
          _logger.info("Calculating route updates");
          final routeData = _calculateUpdatedRoute(current);

          // Update the route visualization if needed
          if (routeData != null) {
            await _updateRouteVisualization(routeData);
          }
        }

        // Update lastKnownLoc after successful processing
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

  /// Calculates an updated route based on the user's current location
  /// Returns a map with update information or null if no update is needed
  Map<String, dynamic>? _calculateUpdatedRoute(LocationUpdate update) {
    // Skip if no planned route exists
    if (_plannedRoute == null) return null;    try {
      _logger.info(
          "Calculating updated route based on location: ${update.location}");

      // Convert Mapbox Point coordinates to GeoJSON Point
      // Mapbox uses [lng, lat] which is compatible with GeoJSON
      final List<double> pointCoords = [
        update.location.coordinates[0]?.toDouble() ?? 0.0,
        update.location.coordinates[1]?.toDouble() ?? 0.0
      ];
      final userLocation = GeoJSONPoint(pointCoords);

      // Convert Mapbox LineString coordinates to GeoJSON format
      List<List<double>> geoJsonCoords = [];
      for (var position in _plannedRoute!.coordinates) {
        geoJsonCoords.add(
            [position[0]?.toDouble() ?? 0.0, position[1]?.toDouble() ?? 0.0]);
      }
      
      // Extra safeguard - ensure we have at least 2 coordinates for the LineString
      if (geoJsonCoords.length < 2) {
        _logger.warning("Route has fewer than 2 points - adding duplicate end point");
        if (geoJsonCoords.isNotEmpty) {
          // Duplicate the last point to ensure we have at least 2 points
          geoJsonCoords.add(List<double>.from(geoJsonCoords.last));
        } else {
          // If somehow we have no points, we can't process
          _logger.severe("Route has no points - cannot process");
          return null;
        }
      }
      
      final geoRoute = GeoJSONLineString(geoJsonCoords);

      // Convert to list of points for processing
      final routePoints = lineStringToPoints(geoRoute);

      // Skip processing if route is too short
      if (routePoints.length < 2) {
        _logger.info(
            "Route too short for processing (${routePoints.length} points)");
        return null;
      }

      // Check if user is on route (using a reasonable threshold, e.g., 50 meters)
      final checkResult =
          isUserOnRoute(userLocation, routePoints, thresholdMeters: 50.0);      // Update route based on check result
      List<GeoJSONPoint> updatedPoints;
      bool isOnRoute = checkResult.isOnRoute;

      if (isOnRoute) {
        _logger.info(
            "User is on route - shrinking route at segment ${checkResult.segmentIndex}");
        // User is on route - shrink
        updatedPoints = shrinkRoute(checkResult.projectedPoint,
            checkResult.segmentIndex, checkResult.projectionRatio, routePoints);
        
        // Special handling for near-completion - if we have only duplicated points,
        // this may indicate we've essentially completed the route
        if (updatedPoints.length == 2 && 
            updatedPoints[0].coordinates[0] == updatedPoints[1].coordinates[0] &&
            updatedPoints[0].coordinates[1] == updatedPoints[1].coordinates[1]) {
          _logger.info("Route nearly complete - maintaining minimal valid route");
        }
      } else {
        _logger.info(
            "User is off route (${checkResult.distance}m away) - growing route");
        // User is off route - grow
        updatedPoints = growRoute(userLocation, routePoints);
      }

      // Only return data if there's actually a change
      if (updatedPoints.length != routePoints.length ||
          !_areRoutePointsEqual(updatedPoints, routePoints)) {
        // Convert back to LineString format for Mapbox
        final updatedGeoJsonLineString = pointsToLineString(updatedPoints);

        // Convert GeoJSON coordinates back to Mapbox format
        List<List<double>> mapboxCoords = updatedGeoJsonLineString.coordinates;

        // Create the GeoJSON feature
        final data = {
          "type": "Feature",
          "geometry": {"type": "LineString", "coordinates": mapboxCoords},
          "properties": {}
        };

        // Create Mapbox LineString
        List<Position> positions = [];
        for (var coord in mapboxCoords) {
          positions.add(Position(coord[0], coord[1]));
        }

        return {
          "updatedLineString": LineString(coordinates: positions),
          "data": data,
          "isOnRoute": isOnRoute,
          "distanceFromRoute": checkResult.distance,
          "routeChanged": true
        };
      } else {
        _logger.info("No significant route change needed");
        return {
          "routeChanged": false,
          "isOnRoute": isOnRoute,
          "distanceFromRoute": checkResult.distance
        };
      }    } catch (e) {
      _logger.warning("Error calculating updated route: $e");
      if (e.toString().contains('coordinates.length >= 2')) {
        _logger.warning("Route has fewer than 2 points - this typically happens at the end of a route");
      }
      return null;
    }
  }

  /// Helper to check if two lists of GeoJSON points represent the same route
  bool _areRoutePointsEqual(
      List<GeoJSONPoint> route1, List<GeoJSONPoint> route2) {
    if (route1.length != route2.length) return false;

    for (int i = 0; i < route1.length; i++) {
      if (route1[i].coordinates[0] != route2[i].coordinates[0] ||
          route1[i].coordinates[1] != route2[i].coordinates[1]) {
        return false;
      }
    }

    return true;
  }

  /// Updates the route visualization on the map based on the calculated route data
  ///
  /// This method handles updating the GeoJSON source data and the planned route
  /// object based on the results from _calculateUpdatedRoute
  Future<void> _updateRouteVisualization(Map<String, dynamic> routeData) async {
    // Skip if no change needed
    if (!(routeData['routeChanged'] as bool)) {
      return;
    }

    try {
      _logger.info("Updating route visualization");

      // Update the internal route object
      if (routeData.containsKey('updatedLineString')) {
        _plannedRoute = routeData['updatedLineString'] as LineString;
      }

      // Get the GeoJSON data
      final Map<String, dynamic> data =
          routeData['data'] as Map<String, dynamic>;

      // Check if the source exists
      bool sourceExists = false;
      try {
        await _map.style.getStyleSourceProperty(_routeSourceId, 'type');
        sourceExists = true;
      } catch (e) {
        _logger.warning("Route source doesn't exist, will create: $e");
      }

      if (sourceExists) {
        // Update existing source data
        await _map.style.setStyleSourceProperty(
          _routeSourceId,
          'data',
          data,
        );
        _logger.info("Updated existing route source");
      } else {
        // Create a new source if it doesn't exist
        final geoJsonSource =
            GeoJsonSource(id: _routeSourceId, lineMetrics: true);
        await _map.style.addSource(geoJsonSource);
        await _map.style.setStyleSourceProperty(
          _routeSourceId,
          'data',
          data,
        );

        // Create and add the line layer
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
          lineBorderColor: 0xFFFFFFFF,
          lineBorderWidth: 1.0,
          lineZOffset: -1.0,
        );

        await _map.style.addLayer(lineLayer);
        _logger.info("Created new route source and layer");
      }

      // Update waypoints positions if needed
      // This could be implemented later if needed

      _logger.info("Route visualization updated successfully");
    } catch (e) {
      _logger.severe("Error updating route visualization: $e");
    }
  }
}
