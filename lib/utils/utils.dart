import 'package:flutter/services.dart';

Uint8List addImageFromAsset(ByteData asset) {
  final list = asset.buffer.asUint8List();
  return list;
}
