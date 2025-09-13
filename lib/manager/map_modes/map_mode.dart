import 'package:geojson_vi/geojson_vi.dart';
import 'package:map_manager/map_manager.dart';

mixin _MapModeMixin {
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
      GeoJSONFeature? route,
      List<GeoJSONPoint>? waypoints,
      RouteTraversalSource source,
      DisplayMode displayMode,
    )
    tracking,
  }) => throw UnimplementedError(
    "when() not implemented for this MapMode subtype",
  );

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
      GeoJSONFeature? route,
      List<GeoJSONPoint>? waypoints,
      RouteTraversalSource source,
      DisplayMode displayMode,
    )?
    tracking,
  }) => throw UnimplementedError(
    "whenOrNull() not implemented for this MapMode subtype",
  );
  TResult map<TResult extends Object?>({
    required TResult Function(BasicMapMode value) basic,
    required TResult Function(LocSelMode value) locationSel,
    required TResult Function(RouteMode value) route,
    required TResult Function(TrackingMode value) tracking,
  }) => throw UnimplementedError(
    "map() not implemented for this MapMode subtype",
  );

  TResult? mapOrNull<TResult extends Object?>({
    required TResult? Function(BasicMapMode value)? basic,
    required TResult? Function(LocSelMode value)? locationSel,
    required TResult? Function(RouteMode value)? route,
    required TResult? Function(TrackingMode value)? tracking,
  }) => throw UnimplementedError(
    "mapOrNull() not implemented for this MapMode subtype",
  );
}

abstract class MapMode with _MapModeMixin {
  MapMode.internal();

  factory MapMode.basic({bool trackUserLocation = true}) =>
      BasicMapMode(trackUserLoc: trackUserLocation);

  factory MapMode.locSel({
    int maxSelections = 1,
    Map<String, GeoJSONPoint>? preselected,
  }) => LocSelMode(maxSelections: maxSelections, preselected: preselected);

  factory MapMode.route({Map<String, GeoJSONFeature>? predefinedRoutes}) =>
      RouteMode(predefinedRoutes: predefinedRoutes);

  factory MapMode.tracking({
    GeoJSONFeature? route,
    List<GeoJSONPoint>? waypoints,
    RouteTraversalSource source = RouteTraversalSource.user,
    DisplayMode displayMode = DisplayMode.showAll,
  }) => TrackingMode(
    route: route,
    waypoints: waypoints,
    source: source,
    displayMode: displayMode,
  );
}

extension EnsureMapMode on MapMode {
  bool ensureMode<T extends MapMode>() {
    if (this is T) return true;
    throw MapModeException(
      message: 'Operation not allwoed in $this mode',
      currentMode: this,
      expectedMode: this,
    );
  }

  bool checkMode<T extends MapMode>() => this is T;
}
