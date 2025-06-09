import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:map_manager_mapbox/manager/map_utils.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:logging/logging.dart';

/// A class that manages the basic map mode functionality.
///
/// This class handles features such as:
/// * User location tracking
/// * Camera positioning
/// * Location permissions management
/// * Map movement detection
///
/// It's designed to be used with the [MapMode.basic] mode and provides
/// core map functionality that other mode classes can build upon.
class BasicModeClass {
  /// The current map mode configuration.
  BasicMapMode mode;

  /// Private constructor to enforce factory pattern via [initialize].
  BasicModeClass._(this.mode);

  /// Factory method to create and initialize a [BasicModeClass] instance.
  ///
  /// This method sets up the map based on the provided [basicMode] configuration.
  /// If [trackUserLoc] is true in the mode, it will enable location tracking.
  ///
  /// Parameters:
  /// - [map]: The MapboxMap instance to configure
  /// - [basicMode]: The basic map mode configuration
  ///
  /// Returns a fully initialized [BasicModeClass] instance.
  static Future<BasicModeClass> initialize(
    MapboxMap map,
    BasicMapMode basicMode,
  ) async {
    final cls = BasicModeClass._(basicMode);

    if (basicMode.trackUserLoc) {
      await cls.enableLocTracking(map);
    } else {
      await cls.disableLocTracking(map);
    }
    return cls;
  }

  /// Logger instance for this class.
  final Logger _logger = Logger('BasicModeClass');

  /// Enables location tracking on the map.
  ///
  /// Updates the Mapbox location component settings to display the user's location
  /// and sets up a map move listener to detect when the user manually interacts with the map.
  ///
  /// Parameters:
  /// - [map]: The MapboxMap instance to configure
  /// - [enableBearing]: Whether to show the direction the user is facing
  /// - [puckBearing]: The type of bearing to display (COURSE is typically the direction of travel)
  Future<void> enableLocTracking(
    MapboxMap map, {
    bool enableBearing = true,
    PuckBearing puckBearing = PuckBearing.COURSE,
  }) async {
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearingEnabled: enableBearing,
      puckBearing: puckBearing,
    ));
    map.setOnMapMoveListener((gestureContext) {
      mapMoved.value = true;
    });
    followUserLocation(map);
  }

  /// Disables location tracking on the map.
  ///
  /// Updates the Mapbox location component settings to hide the user's location.
  ///
  /// Parameters:
  /// - [map]: The MapboxMap instance to configure
  Future<void> disableLocTracking(
    MapboxMap map,
  ) async {
    await map.location
        .updateSettings(LocationComponentSettings(enabled: false));
    stopFollowingUserLocation();
  }

  /// Subscription to the location updates stream.
  StreamSubscription? _locStreamSub;

  /// Stream controller for broadcasting location updates.
  StreamController<Point>? _streamController;

  /// The user's last known location.
  Point? _lastKnownLoc;

  /// Getter for the user's last known location.
  Point? get lastKnownLoc => _lastKnownLoc;

  /// Tracks whether the user has manually moved the map.
  ///
  /// When true, automatic camera following is disabled.
  ValueNotifier<bool> mapMoved = ValueNotifier(false);

  /// Starts following the user's location with the map camera.
  ///
  /// This method:
  /// 1. Checks if the map has been manually moved by the user
  /// 2. Verifies and requests location permissions if needed
  /// 3. Sets up a location stream to continuously update the map camera
  ///
  /// The camera will only follow the user if they haven't manually moved the map.
  /// When a location update is received, it:
  /// - Updates the [_lastKnownLoc]
  /// - Broadcasts the location via the stream
  /// - Moves the map camera to center on the user's location
  ///
  /// Parameters:
  /// - [map]: The MapboxMap instance to control
  Future<void> followUserLocation(MapboxMap map) async {
    if (!mapMoved.value) {
      final perm = await geolocator.Geolocator.checkPermission();
      if (perm == geolocator.LocationPermission.deniedForever) {
        await geolocator.Geolocator.openAppSettings();
        followUserLocation(map);
      }
      if (perm == geolocator.LocationPermission.whileInUse ||
          perm == geolocator.LocationPermission.always) {
        _locStreamSub =
            geolocator.Geolocator.getPositionStream().listen((position) async {
          _streamController = StreamController.broadcast();
          final point = Point(
              coordinates: Position(position.longitude, position.latitude));
          _lastKnownLoc = point;
          _streamController!.sink.add(point);
          await moveMapCamTo(map, point);
        });
      } else {
        geolocator.Geolocator.requestPermission();
        followUserLocation(map);
      }
    } else {
      stopFollowingUserLocation();
    }
  }

  /// Stops following the user's location with the map camera.
  ///
  /// This method:
  /// 1. Cancels the location stream subscription
  /// 2. Closes the stream controller
  /// 3. Clears the last known location
  ///
  /// Call this method when you no longer need to track the user's location
  /// or when switching to another map mode.
  void stopFollowingUserLocation() async {
    _locStreamSub?.cancel();
    _locStreamSub = null;
    _streamController?.close();
    _streamController = null;
    _lastKnownLoc = null;
  }

  /// Cleans up all resources used by the basic mode.
  ///
  /// This method:
  /// 1. Disables location tracking on the map
  /// 2. Stops following the user's location
  /// 3. Removes map move listeners
  /// 4. Logs that cleanup has completed
  ///
  /// Call this method when switching to a different map mode or
  /// when the map is being disposed.
  ///
  /// Parameters:
  /// - [map]: The MapboxMap instance to clean up
  Future<void> dispose(MapboxMap map) async {
    await disableLocTracking(map);
    stopFollowingUserLocation();
    map.setOnMapMoveListener(null);
    _logger.info("Basic Mode data cleared");
  }
}
