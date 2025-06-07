import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class LocationUpdate {
  final Point location;
  final DateTime lastUpdated;

  LocationUpdate({required this.location, required this.lastUpdated});

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
        location: Point.fromJson(json['location']),
        lastUpdated: json.containsKey('last_updated')
            ? DateTime.parse(json['last_updated'])
            : DateTime.now());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LocationUpdate) return false;

    return (location.coordinates.lat == other.location.coordinates.lat) &&
        (location.coordinates.lng == other.location.coordinates.lng);
  }

  @override
  int get hashCode => Object.hash(
        location.coordinates.lat,
        location.coordinates.lng,
        lastUpdated,
      );
}
