import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

Future<void> moveMapCamTo(MapboxMap map, Point point, {int? duration}) async {
  await map.flyTo(CameraOptions(center: point, zoom: 16, pitch: 50),
      MapAnimationOptions(duration: duration ?? 500));
}

Future<void> moveMapBy(MapboxMap map, double x, double y) async {
  await map.moveBy(
      ScreenCoordinate(x: x, y: y), MapAnimationOptions(duration: 1));
}
