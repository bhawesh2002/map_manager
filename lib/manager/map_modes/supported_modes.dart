// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:geojson_vi/geojson_vi.dart';

import 'package:map_manager/manager/map_modes/map_mode.dart';
import 'package:map_manager/utils/enums.dart';

class BasicMapMode extends MapMode {
  @override
  TResult when<TResult extends MapMode>({
    required TResult Function(bool trackUserLoc) basic,
    required TResult Function(
      int maxSelections,
      Map<String, GeoJSONPoint>? preselected,
    )
    locSel,
    required TResult Function(Map<String, GeoJSONFeature>? predefinedRoutes)
    routeMode,
    required TResult Function(
      Map<String, GeoJSONFeature>? initialRoutes,
      Map<String, GeoJSONFeature>? initialWaypoints,
      DisplayMode displayMode,
    )
    tracking,
  }) {
    return basic(trackUserLoc);
  }

  @override
  TResult? whenOrNull<TResult extends MapMode>({
    required TResult? Function(bool trackUserLoc)? basic,
    required TResult? Function(
      int maxSelections,
      Map<String, GeoJSONPoint>? preselected,
    )?
    locSel,
    required TResult? Function(Map<String, GeoJSONFeature>? predefinedRoutes)?
    routeMode,
    required TResult? Function(
      Map<String, GeoJSONFeature>? initialRoutes,
      Map<String, GeoJSONFeature>? initialWaypoints,
      DisplayMode displayMode,
    )?
    tracking,
  }) {
    return basic != null ? basic(trackUserLoc) : null;
  }

  @override
  TResult map<TResult extends Object?>({
    required TResult Function(BasicMapMode value) basic,
    required TResult Function(LocSelMode value) locationSel,
    required TResult Function(RouteMode value) route,
    required TResult Function(TrackingMode value) tracking,
  }) {
    return basic(this);
  }

  @override
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicMapMode value)? basic,
    TResult? Function(LocSelMode value)? locationSel,
    TResult? Function(RouteMode value)? route,
    TResult? Function(TrackingMode value)? tracking,
  }) {
    return basic != null ? basic(this) : null as TResult;
  }

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
  final Map<String, GeoJSONPoint>? preselected;
  LocSelMode({this.maxSelections = 1, this.preselected}) : super.internal();

  LocSelMode copyWith({
    int? maxSelections,
    Map<String, GeoJSONPoint>? preselected,
  }) {
    return LocSelMode(
      maxSelections: maxSelections ?? this.maxSelections,
      preselected: preselected ?? this.preselected,
    );
  }

  @override
  TResult when<TResult extends MapMode>({
    required TResult Function(bool trackUserLoc) basic,
    required TResult Function(
      int maxSelections,
      Map<String, GeoJSONPoint>? preselected,
    )
    locSel,
    required TResult Function(Map<String, GeoJSONFeature>? predefinedRoutes)
    routeMode,
    required TResult Function(
      Map<String, GeoJSONFeature>? initialRoutes,
      Map<String, GeoJSONFeature>? initialWaypoints,
      DisplayMode displayMode,
    )
    tracking,
  }) => locSel(maxSelections, preselected);

  @override
  TResult? whenOrNull<TResult extends MapMode>({
    required TResult? Function(bool trackUserLoc)? basic,
    required TResult? Function(
      int maxSelections,
      Map<String, GeoJSONPoint>? preselected,
    )?
    locSel,
    required TResult? Function(Map<String, GeoJSONFeature>? predefinedRoutes)?
    routeMode,
    required TResult? Function(
      Map<String, GeoJSONFeature>? initialRoutes,
      Map<String, GeoJSONFeature>? initialWaypoints,
      DisplayMode displayMode,
    )?
    tracking,
  }) => locSel != null ? locSel(maxSelections, preselected) : null;

  @override
  TResult map<TResult extends Object?>({
    required TResult Function(BasicMapMode value) basic,
    required TResult Function(LocSelMode value) locationSel,
    required TResult Function(RouteMode value) route,
    required TResult Function(TrackingMode value) tracking,
  }) {
    return locationSel(this);
  }

  @override
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicMapMode value)? basic,
    TResult? Function(LocSelMode value)? locationSel,
    TResult? Function(RouteMode value)? route,
    TResult? Function(TrackingMode value)? tracking,
  }) {
    return locationSel != null ? locationSel(this) : null as TResult;
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
  final Map<String, GeoJSONFeature>? predefinedRoutes;
  RouteMode({this.predefinedRoutes}) : super.internal();

  RouteMode copyWith({Map<String, GeoJSONFeature>? predefinedRoutes}) {
    return RouteMode(
      predefinedRoutes: predefinedRoutes ?? this.predefinedRoutes,
    );
  }

  @override
  TResult when<TResult extends MapMode>({
    required TResult Function(bool trackUserLoc) basic,
    required TResult Function(
      int maxSelections,
      Map<String, GeoJSONPoint>? preselected,
    )
    locSel,
    required TResult Function(Map<String, GeoJSONFeature>? predefinedRoutes)
    routeMode,
    required TResult Function(
      Map<String, GeoJSONFeature>? initialRoutes,
      Map<String, GeoJSONFeature>? initialWaypoints,
      DisplayMode displayMode,
    )
    tracking,
  }) {
    return routeMode(predefinedRoutes);
  }

  @override
  TResult? whenOrNull<TResult extends MapMode>({
    required TResult? Function(bool trackUserLoc)? basic,
    required TResult? Function(
      int maxSelections,
      Map<String, GeoJSONPoint>? preselected,
    )?
    locSel,
    required TResult? Function(Map<String, GeoJSONFeature>? predefinedRoutes)?
    routeMode,
    required TResult? Function(
      Map<String, GeoJSONFeature>? initialRoutes,
      Map<String, GeoJSONFeature>? initialWaypoints,
      DisplayMode displayMode,
    )?
    tracking,
  }) {
    return routeMode != null ? routeMode(predefinedRoutes) : null;
  }

  @override
  TResult map<TResult extends Object?>({
    required TResult Function(BasicMapMode value) basic,
    required TResult Function(LocSelMode value) locationSel,
    required TResult Function(RouteMode value) route,
    required TResult Function(TrackingMode value) tracking,
  }) {
    return route(this);
  }

  @override
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicMapMode value)? basic,
    TResult? Function(LocSelMode value)? locationSel,
    TResult? Function(RouteMode value)? route,
    TResult? Function(TrackingMode value)? tracking,
  }) {
    return route != null ? route(this) : null;
  }

  @override
  String toString() => 'RouteMode(route: $predefinedRoutes)';

  @override
  bool operator ==(covariant RouteMode other) {
    if (identical(this, other)) return true;

    return other.predefinedRoutes == predefinedRoutes;
  }

  @override
  int get hashCode => predefinedRoutes.hashCode;
}

class TrackingMode extends MapMode {
  final Map<String, GeoJSONFeature>? initialRoutes;
  final Map<String, GeoJSONFeature>? initialWaypoints;
  final DisplayMode displayMode;

  TrackingMode({
    this.initialRoutes,
    this.initialWaypoints,
    this.displayMode = DisplayMode.showAll,
  }) : super.internal();

  TrackingMode copyWith({
    Map<String, GeoJSONFeature>? initialRoutes,
    Map<String, GeoJSONFeature>? initialWaypoints,
    DisplayMode? displayMode,
  }) {
    return TrackingMode(
      initialRoutes: initialRoutes ?? this.initialRoutes,
      initialWaypoints: initialWaypoints ?? this.initialWaypoints,
      displayMode: displayMode ?? this.displayMode,
    );
  }

  @override
  TResult when<TResult extends MapMode>({
    required TResult Function(bool trackUserLoc) basic,
    required TResult Function(
      int maxSelections,
      Map<String, GeoJSONPoint>? preselected,
    )
    locSel,
    required TResult Function(Map<String, GeoJSONFeature>? predefinedRoutes)
    routeMode,
    required TResult Function(
      Map<String, GeoJSONFeature>? initialRoutes,
      Map<String, GeoJSONFeature>? initialWaypoints,
      DisplayMode displayMode,
    )
    tracking,
  }) => tracking(initialRoutes, initialWaypoints, displayMode);

  @override
  TResult? whenOrNull<TResult extends MapMode>({
    required TResult? Function(bool trackUserLoc)? basic,
    required TResult? Function(
      int maxSelections,
      Map<String, GeoJSONPoint>? preselected,
    )?
    locSel,
    required TResult? Function(Map<String, GeoJSONFeature>? predefinedRoutes)?
    routeMode,
    required TResult? Function(
      Map<String, GeoJSONFeature>? initialRoutes,
      Map<String, GeoJSONFeature>? initialWaypoints,
      DisplayMode displayMode,
    )?
    tracking,
  }) {
    return tracking != null
        ? tracking(initialRoutes, initialWaypoints, displayMode)
        : null;
  }

  @override
  TResult map<TResult extends Object?>({
    required TResult Function(BasicMapMode value) basic,
    required TResult Function(LocSelMode value) locationSel,
    required TResult Function(RouteMode value) route,
    required TResult Function(TrackingMode value) tracking,
  }) {
    return tracking(this);
  }

  @override
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicMapMode value)? basic,
    TResult? Function(LocSelMode value)? locationSel,
    TResult? Function(RouteMode value)? route,
    TResult? Function(TrackingMode value)? tracking,
  }) {
    return tracking != null ? tracking(this) : null;
  }

  @override
  String toString() {
    return 'TrackingMode(initialRoutes: $initialRoutes, initialWaypoints: $initialWaypoints, displayMode: $displayMode)';
  }

  @override
  bool operator ==(covariant TrackingMode other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other.initialRoutes == initialRoutes &&
        listEquals(other.initialRoutes, initialRoutes) &&
        other.displayMode == displayMode;
  }

  @override
  int get hashCode {
    return initialRoutes.hashCode ^
        initialWaypoints.hashCode ^
        displayMode.hashCode;
  }
}
