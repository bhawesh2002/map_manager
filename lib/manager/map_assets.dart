import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:map_manager/utils/utils.dart';

class MapAssets {
  static late final MapAsset selectedLoc;
  static late final MapAsset personLoc;
  static late final MapAsset circle;

  static Future<void> init() async {
    try {
      final byteDataPerson = await rootBundle.load(
        'packages/map_manager_mapbox/assets/person-loc.png',
      );
      final byteDataSelected = await rootBundle.load(
        'packages/map_manager_mapbox/assets/selected-loc.png',
      );
      final byteDataCircle = await rootBundle.load(
        'packages/map_manager_mapbox/assets/circle.png',
      );

      final personImage = await decodeImageFromByteData(byteDataPerson);
      final selectedImage = await decodeImageFromByteData(byteDataSelected);
      final circleImage = await decodeImageFromByteData(byteDataCircle);

      selectedLoc = MapAsset(
        asset: addImageFromAsset(byteDataSelected),
        width: selectedImage.width,
        height: selectedImage.height,
      );
      personLoc = MapAsset(
        asset: addImageFromAsset(byteDataPerson),
        width: personImage.width,
        height: personImage.height,
      );
      circle = MapAsset(
        asset: addImageFromAsset(byteDataCircle),
        width: circleImage.width,
        height: circleImage.height,
      );
    } catch (e) {
      debugPrint("Map Assets.init(): $e");
    }
  }
}

class MapAsset {
  final Uint8List asset;
  final int width;
  final int height;

  MapAsset({required this.asset, required this.width, required this.height});
}
