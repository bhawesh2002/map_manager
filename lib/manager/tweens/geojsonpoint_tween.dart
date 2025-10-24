import 'package:flutter/animation.dart';
import 'package:geojson_vi/geojson_vi.dart';

class GeoJSONPointTween extends Tween<GeoJSONPoint> {
  GeoJSONPointTween({required GeoJSONPoint begin, required GeoJSONPoint end})
    : super(begin: begin, end: end);

  @override
  GeoJSONPoint lerp(double t) {
    final double lat = lerpDouble(
      begin!.coordinates.last.toDouble(),
      end!.coordinates.last.toDouble(),
      t,
    )!;
    final double lng = lerpDouble(
      begin!.coordinates.first.toDouble(),
      end!.coordinates.first.toDouble(),
      t,
    )!;
    return GeoJSONPoint([lng, lat]); // x: lng, y: lat (geojson order)
  }

  double? lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
