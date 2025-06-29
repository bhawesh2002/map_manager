import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:map_manager_mapbox/utils/utils.dart';

class MapAssets {
  static late final Uint8List selectedLoc;
  static late final Uint8List personLoc;
  static late final Uint8List circle;
  static late final int selectedLocWidth;
  static late final int selectedLocHeight;
  static late final int personLocWidth;
  static late final int personLocHeight;
  static late final int circleWidth;
  static late final int circleHeight;

  static Future<void> init() async {
    try {
      final byteDataPerson = await rootBundle
          .load('packages/map_manager_mapbox/assets/person-loc.png');
      final byteDataSelected = await rootBundle
          .load('packages/map_manager_mapbox/assets/selected-loc.png');
      final byteDataCircle = await rootBundle
          .load('packages/map_manager_mapbox/assets/circle.png');

      // Decode images to get dimensions
      final personImage = await _decodeImageFromByteData(byteDataPerson);
      final selectedImage = await _decodeImageFromByteData(byteDataSelected);
      final circleImage = await _decodeImageFromByteData(byteDataCircle);

      // Store dimensions
      personLocWidth = personImage.width;
      personLocHeight = personImage.height;
      selectedLocWidth = selectedImage.width;
      selectedLocHeight = selectedImage.height;
      circleWidth = circleImage.width;
      circleHeight = circleImage.height;

      // Store processed image data
      selectedLoc = addImageFromAsset(byteDataSelected);
      personLoc = addImageFromAsset(byteDataPerson);
      circle = addImageFromAsset(byteDataCircle);
    } catch (e) {
      debugPrint("Map Assets.init(): $e");
    }
  }

  static Future<ui.Image> _decodeImageFromByteData(ByteData byteData) async {
    final Uint8List bytes = byteData.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }
}
