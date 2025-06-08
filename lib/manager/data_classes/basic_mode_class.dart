import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:map_manager_mapbox/manager/map_utils.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:logging/logging.dart';

class BasicModeClass {
  BasicMapMode mode;

  BasicModeClass._(this.mode);
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

  final Logger _logger = Logger('BasicModeClass');
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
  }

  Future<void> disableLocTracking(
    MapboxMap map,
  ) async {
    await map.location
        .updateSettings(LocationComponentSettings(enabled: false));
  }

  StreamSubscription? _locStreamSub;
  StreamController<Point>? _streamController;
  Point? _lastKnownLoc;
  Point? get lastKnownLoc => _lastKnownLoc;

  ValueNotifier<bool> mapMoved = ValueNotifier(false);

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
    }
  }

  Future<void> stopFollowingUserLocation() async {
    _locStreamSub?.cancel();
    _locStreamSub = null;
    _streamController?.close();
    _streamController = null;
    _lastKnownLoc = null;
  }

  Future<void> clearBasicModeData(MapboxMap map) async {
    await disableLocTracking(map);
    stopFollowingUserLocation();
    map.setOnMapMoveListener(null);
    _logger.info("Basic Mode data cleared");
  }
}
