import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:logging/logging.dart';

class BasicModeClass {
  static Future<BasicModeClass> initialize() async {
    final cls = BasicModeClass();
    return cls;
  }

  final Logger _logger = Logger('BasicModeClass');

  Future<void> enableLocTracking(
    MapboxMap map,
  ) async {
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearingEnabled: true,
      puckBearing: PuckBearing.COURSE,
    ));
  }

  Future<void> disableLocTracking(
    MapboxMap map,
  ) async {
    await map.location
        .updateSettings(LocationComponentSettings(enabled: false));
  }

  Future<void> clearBasicModeDat(MapboxMap map) async {
    await disableLocTracking(map);
    _logger.info("Basic Mode data cleared");
  }
}
