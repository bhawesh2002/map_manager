import 'package:geojson_vi/geojson_vi.dart';

class LocationUpdate {
  final GeoJSONFeature location;
  final DateTime lastUpdated;

  LocationUpdate({required this.location, required this.lastUpdated});

  GeoJSONPoint get point => location.geometry as GeoJSONPoint;

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      location: GeoJSONFeature.fromJSON(json['location']),
      lastUpdated: json.containsKey('last_updated')
          ? DateTime.parse(json['last_updated'])
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LocationUpdate) return false;

    return (point.coordinates[1] == other.point.coordinates[1]) &&
        (point.coordinates[0] == other.point.coordinates[0]);
  }

  @override
  int get hashCode =>
      Object.hash(point.coordinates[1], point.coordinates[0], lastUpdated);
}
