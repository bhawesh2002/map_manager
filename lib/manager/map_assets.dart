import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:map_manager/utils/utils.dart';

class MapAssets {
  static const String _packageName = 'map_manager';
  static const _base = 'packages/$_packageName/assets/';

  static late final MapAsset selectedLoc;
  static late final MapAsset personLoc;
  static late final MapAsset circle;

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      personLoc = await _loadAsset('person-loc.png');
      selectedLoc = await _loadAsset('selected-loc.png');
      circle = await _loadAsset('circle.png');

      _initialized = true;
    } catch (e, st) {
      debugPrint(
        "MapAssets.init() map_manager/lib/map_assets.dart error: $e\n$st",
      );
      rethrow;
    }
  }

  static Future<MapAsset> _loadAsset(String fileName) async {
    final byteData = await rootBundle.load('$_base$fileName');
    final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
    final frame = await codec.getNextFrame();

    return MapAsset(
      asset: addImageFromAsset(byteData),
      width: frame.image.width,
      height: frame.image.height,
    );
  }
}

class MapAsset {
  final Uint8List asset;
  final int width;
  final int height;

  MapAsset({required this.asset, required this.width, required this.height});
}
