import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logging/logging.dart';

class GeolocatorUtils {
  StreamSubscription? _subscription;
  static final StreamController<Position> _streamController =
      StreamController<Position>.broadcast();
  static Stream<Position> get positionStream => _streamController.stream;
  static final ValueNotifier<Position?> positionValueNotifier =
      ValueNotifier(null);

  static Position? get position => positionValueNotifier.value;

  bool get _started => _subscription != null || _subscription?.isPaused != true;

  final Logger _logger = Logger("GeolocatorUtils");

  static void startLocationUpdates() async {
    final GeolocatorUtils utils = GeolocatorUtils();
    if (utils._started == true) return;
    final lastKnown = await Geolocator.getLastKnownPosition();
    positionValueNotifier.value = lastKnown;
    lastKnown != null ? _streamController.sink.add(lastKnown) : null;
    utils._subscription = Geolocator.getPositionStream().listen((position) {
      _streamController.sink.add(position);
      positionValueNotifier.value = position;
    }, onDone: () {
      utils._subscription!.cancel();
    }, onError: (err) {
      utils._subscription!.cancel();
    });
    utils._logger.info("Location updates started ");
  }
}
