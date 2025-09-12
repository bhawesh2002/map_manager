// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:geojson_vi/geojson_vi.dart';

import 'package:map_manager/manager/map_modes/map_mode.dart';
import 'package:map_manager/utils/enums.dart';

class BasicMapMode extends MapMode {
  final bool trackUserLocl;
  BasicMapMode(this.trackUserLocl) : super.internal();

  BasicMapMode copyWith({bool? trackUserLocl}) {
    return BasicMapMode(trackUserLocl ?? this.trackUserLocl);
  }

  @override
  String toString() => 'BasicMapMode(trackUserLocl: $trackUserLocl)';

  @override
  bool operator ==(covariant BasicMapMode other) {
    if (identical(this, other)) return true;

    return other.trackUserLocl == trackUserLocl;
  }

  @override
  int get hashCode => trackUserLocl.hashCode;
}

class LocSelMode extends MapMode {
  final int maxSelections;
  final List<GeoJSONPoint>? preselected;
  LocSelMode(this.maxSelections, this.preselected) : super.internal();

  LocSelMode copyWith({int? maxSelections, List<GeoJSONPoint>? preselected}) {
    return LocSelMode(
      maxSelections ?? this.maxSelections,
      preselected ?? this.preselected,
    );
  }

  @override
  String toString() =>
      'LocSelMode(maxSelections: $maxSelections, preselected: $preselected)';

  @override
  bool operator ==(covariant LocSelMode other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other.maxSelections == maxSelections &&
        listEquals(other.preselected, preselected);
  }

  @override
  int get hashCode => maxSelections.hashCode ^ preselected.hashCode;
}

class RouteMode extends MapMode {
  final GeoJSONLineString? route;
  RouteMode(this.route) : super.internal();

  RouteMode copyWith({GeoJSONLineString? route}) {
    return RouteMode(route ?? this.route);
  }

  @override
  String toString() => 'RouteMode(route: $route)';

  @override
  bool operator ==(covariant RouteMode other) {
    if (identical(this, other)) return true;

    return other.route == route;
  }

  @override
  int get hashCode => route.hashCode;
}

class TrackingMode extends MapMode {
  final GeoJSONLineString? route;
  final List<GeoJSONPoint>? waypoints;
  final RouteTraversalSource source;
  final DisplayMode displayMode;
  TrackingMode(this.route, this.waypoints, this.source, this.displayMode)
    : super.internal();

  TrackingMode copyWith({
    GeoJSONLineString? route,
    List<GeoJSONPoint>? waypoints,
    RouteTraversalSource? source,
    DisplayMode? displayMode,
  }) {
    return TrackingMode(
      route ?? this.route,
      waypoints ?? this.waypoints,
      source ?? this.source,
      displayMode ?? this.displayMode,
    );
  }

  @override
  String toString() {
    return 'TrackingMode(route: $route, waypoints: $waypoints, source: $source, displayMode: $displayMode)';
  }

  @override
  bool operator ==(covariant TrackingMode other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other.route == route &&
        listEquals(other.waypoints, waypoints) &&
        other.source == source &&
        other.displayMode == displayMode;
  }

  @override
  int get hashCode {
    return route.hashCode ^
        waypoints.hashCode ^
        source.hashCode ^
        displayMode.hashCode;
  }
}
