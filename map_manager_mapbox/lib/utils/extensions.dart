import 'package:geojson_vi/geojson_vi.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geolocator;

extension ToMapboxPoint on LatLng {
  Point toMapboxPoint() => Point(coordinates: Position(longitude, latitude));
}

extension ToLatLng on Point {
  LatLng toLatLng() =>
      LatLng(coordinates.lat.toDouble(), coordinates.lng.toDouble());
}

extension LatLngToGeoJsonPoint on LatLng {
  GeoJSONPoint toGeojsonPoint() => GeoJSONPoint([longitude, latitude]);
}

extension GeoJsonPointToLatLng on GeoJSONPoint {
  LatLng toLatLng() => LatLng(coordinates[1], coordinates[0]);
}

extension GeoJsonPointToMapboxPoint on GeoJSONPoint {
  Point toMbPoint() =>
      Point(coordinates: Position(coordinates[0], coordinates[1]));
}

extension MapboxPointToGeojsonPoint on Point {
  GeoJSONPoint toGeojsonPoint() =>
      GeoJSONPoint([coordinates.lng.toDouble(), coordinates.lat.toDouble()]);
}

extension GeoJsonLineStringToMapboxLineString on GeoJSONLineString {
  LineString toMbLineString() => LineString.fromJson(toMap());
}

extension MbLineStrToGeojsonLineStr on LineString {
  GeoJSONLineString toGeojsonLineStr() => GeoJSONLineString(
      coordinates.map((e) => [e.lng.toDouble(), e.lat.toDouble()]).toList());
}

extension PositionToLatLng on geolocator.Position {
  LatLng toLatLng() => LatLng(latitude, longitude);
}
