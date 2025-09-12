// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:geojson_vi/geojson_vi.dart';

import 'package:map_manager/manager/map_modes/map_mode.dart';
import 'package:map_manager/utils/enums.dart';

class BasicMapMode extends MapMode {
  final bool trackUserLoc;
  BasicMapMode({this.trackUserLoc = true}) : super.internal();

  BasicMapMode copyWith({bool? trackUserLoc}) {
    return BasicMapMode(trackUserLoc: trackUserLoc ?? this.trackUserLoc);
  }

  @override
  String toString() => 'BasicMapMode(trackUserLoc: $trackUserLoc)';

  @override
  bool operator ==(covariant BasicMapMode other) {
    if (identical(this, other)) return true;

    return other.trackUserLoc == trackUserLoc;
  }

  @override
  int get hashCode => trackUserLoc.hashCode;
}

class LocSelMode extends MapMode {
  final int maxSelections;
  final List<GeoJSONPoint>? preselected;
  LocSelMode({this.maxSelections = 1, this.preselected}) : super.internal();

  LocSelMode copyWith({int? maxSelections, List<GeoJSONPoint>? preselected}) {
    return LocSelMode(
      maxSelections: maxSelections ?? this.maxSelections,
      preselected: preselected ?? this.preselected,
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
  RouteMode({this.route}) : super.internal();

  RouteMode copyWith({GeoJSONLineString? route}) {
    return RouteMode(route: route ?? this.route);
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
  TrackingMode({
    this.route,
    this.waypoints,
    this.source = RouteTraversalSource.user,
    this.displayMode = DisplayMode.showAll,
  }) : super.internal();

  TrackingMode copyWith({
    GeoJSONLineString? route,
    List<GeoJSONPoint>? waypoints,
    RouteTraversalSource? source,
    DisplayMode? displayMode,
  }) {
    return TrackingMode(
      route: route ?? this.route,
      waypoints: waypoints ?? this.waypoints,
      source: source ?? this.source,
      displayMode: displayMode ?? this.displayMode,
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
