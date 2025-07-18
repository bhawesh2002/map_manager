import 'package:flutter/animation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class PointTween extends Tween<Point> {
  PointTween({required Point begin, required Point end})
      : super(begin: begin, end: end);

  @override
  Point lerp(double t) {
    final double lat = lerpDouble(
        begin!.coordinates.lat.toDouble(), end!.coordinates.lat.toDouble(), t)!;
    final double lng = lerpDouble(
        begin!.coordinates.lng.toDouble(), end!.coordinates.lng.toDouble(), t)!;
    return Point(
        coordinates: Position(lng, lat)); // x: lng, y: lat (geojson order)
  }

  double? lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
