import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:map_manager_mapbox/utils/utils.dart';

class MapAssets {
  static late final Uint8List selectedLoc;
  static late final Uint8List personLoc;
  static Future<void> init() async {
    try {
      final byteDataPerson = await rootBundle
          .load('packages/map_manager_mapbox/assets/person-loc.png');
      final byteDataSelected = await rootBundle
          .load('packages/map_manager_mapbox/assets/selected-loc.png');

      selectedLoc = addImageFromAsset(byteDataSelected);
      personLoc = addImageFromAsset(byteDataPerson);
    } catch (e) {
      debugPrint("Map Assets.init(): $e");
    }
  }
}
