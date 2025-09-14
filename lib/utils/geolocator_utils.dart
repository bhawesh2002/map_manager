import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map_manager/manager/location_update.dart';
import 'package:map_manager/utils/geojson_extensions.dart';
import 'package:map_manager/utils/manager_logger.dart';

class GeolocatorUtils {
  StreamSubscription? _subscription;
  static final StreamController<Position> _streamController =
      StreamController<Position>.broadcast();
  static Stream<Position> get positionStream => _streamController.stream;
  static final ValueNotifier<LocationUpdate?> positionValueNotifier =
      ValueNotifier(null);

  static LocationUpdate? get update => positionValueNotifier.value;

  bool get _started => _subscription != null;

  final ManagerLogger _logger = ManagerLogger("GeolocatorUtils");

  static Future<void> startLocationUpdates() async {
    final GeolocatorUtils utils = GeolocatorUtils();
    if (utils._started == true) return;
    utils._subscription = Geolocator.getPositionStream().listen(
      (position) {
        _streamController.sink.add(position);
        positionValueNotifier.value = LocationUpdate(
          location: GeoJSONFeature(position.geojsonPoint),
          lastUpdated: DateTime.now(),
        );
      },
      onDone: () {
        utils._subscription!.cancel();
      },
      onError: (err) {
        utils._subscription!.cancel();
      },
    );
    utils._logger.info("Location updates started ");
  }
}
