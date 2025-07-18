import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/map_manager_mapbox.dart';
import 'package:map_manager_mapbox/utils/geojson_extensions.dart';

class GeolocatorUtils {
  StreamSubscription? _subscription;
  static final StreamController<Position> _streamController =
      StreamController<Position>.broadcast();
  static Stream<Position> get positionStream => _streamController.stream;
  static final ValueNotifier<LocationUpdate?> positionValueNotifier =
      ValueNotifier(null);

  static LocationUpdate? get update => positionValueNotifier.value;

  bool get _started => _subscription != null;

  final Logger _logger = Logger("GeolocatorUtils");

  static Future<void> startLocationUpdates() async {
    final GeolocatorUtils utils = GeolocatorUtils();
    if (utils._started == true) return;
    utils._subscription = Geolocator.getPositionStream().listen((position) {
      _streamController.sink.add(position);
      positionValueNotifier.value = LocationUpdate(
          location: position.mapboxPoint, lastUpdated: DateTime.now());
    }, onDone: () {
      utils._subscription!.cancel();
    }, onError: (err) {
      utils._subscription!.cancel();
    });
    utils._logger.info("Location updates started ");
  }
}
