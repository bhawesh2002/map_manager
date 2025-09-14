import 'package:flutter/widgets.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:map_manager/manager/location_update.dart';
import 'package:map_manager/utils/route_utils.dart';

class TraversalPair {
  final String _pairId;
  final ValueNotifier<LocationUpdate> traversalSource;
  final GeoJSONFeature originalRoute;

  String get pairId => _pairId;

  TraversalPair({
    required String pairId,
    required this.traversalSource,
    required this.originalRoute,
  }) : _pairId = pairId;

  final GeoJSONFeature _traversedRoute = GeoJSONFeature(null, properties: {});
  final GeoJSONFeature _remainingRoute = GeoJSONFeature(null, properties: {});

  void _ensureProperties() {
    final tSrc = traversalSource.value;
    tSrc.location.properties ??= {};
    tSrc.location.properties!['traversal-source-id'] = '$pairId-source';
    _traversedRoute.properties!['traversed-route-id'] = '$pairId-traversed';
    _remainingRoute.properties!['remaining-route-id'] = '$pairId-remaining';
  }

  void _updateTraversalRoutes() {
    final currentPos = traversalSource.value.point;
    final originalLineString = originalRoute.geometry as GeoJSONLineString;

    final routeCollection = updateRouteGeojson(currentPos, originalLineString);

    // Extract traversed and remaining routes from the collection
    for (final feature in routeCollection.features) {
      if (feature == null) continue;
      final routeType = feature.properties?['route-type'];

      if (routeType == 'traversed' && feature.geometry != null) {
        _traversedRoute.geometry = feature.geometry!;
      } else if (routeType == 'remaining' && feature.geometry != null) {
        _remainingRoute.geometry = feature.geometry!;
      }
    }
  }

  GeoJSONFeatureCollection get traversalFeatureCollection {
    _ensureProperties();
    _updateTraversalRoutes();
    return GeoJSONFeatureCollection([
      traversalSource.value.location,
      _traversedRoute,
      _remainingRoute,
    ]);
  }
}
