import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

Uint8List addImageFromAsset(ByteData asset) {
  final list = asset.buffer.asUint8List();
  return list;
}

Future<Uint8List> fetchImageFromNetworkImage(String imageUrl) async {
  try {
    final networkImage = NetworkImage(imageUrl);
    final imageStream = networkImage.resolve(const ImageConfiguration());

    final completer = Completer<ui.Image>();
    imageStream.addListener(ImageStreamListener((info, _) {
      completer.complete(info.image);
    }));

    final image = await completer.future;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      return byteData.buffer.asUint8List();
    } else {
      throw Exception('Failed to convert image to bytes');
    }
  } catch (e) {
    print('Error fetching image with NetworkImage: $e');
    rethrow;
  }
}
