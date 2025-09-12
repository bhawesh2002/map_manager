import 'package:geojson_vi/geojson_vi.dart';

class LocationUpdate {
  final GeoJSONPoint location;
  final DateTime lastUpdated;

  LocationUpdate({required this.location, required this.lastUpdated});

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      location: GeoJSONPoint.fromJSON(json['location']),
      lastUpdated: json.containsKey('last_updated')
          ? DateTime.parse(json['last_updated'])
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LocationUpdate) return false;

    return (location.coordinates[1] == other.location.coordinates[1]) &&
        (location.coordinates[0] == other.location.coordinates[0]);
  }

  @override
  int get hashCode => Object.hash(
    location.coordinates[1],
    location.coordinates[0],
    lastUpdated,
  );
}
