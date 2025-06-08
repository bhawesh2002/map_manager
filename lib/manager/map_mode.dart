import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:map_manager_mapbox/manager/map_exceptions.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

part 'map_mode.freezed.dart';

@freezed
class MapMode with _$MapMode {
  factory MapMode.basic({@Default(true) bool trackUserLoc}) = BasicMapMode;
  @Assert('(preSelectedLocs?.length ?? 0)<= maxSelections',
      'pre selection loctations must not exceed maxSelections')
  factory MapMode.locationSel(
      {@Default(1) int maxSelections,
      @Default([]) List<Point>? preSelectedLocs}) = LocationSelectionMode;
  factory MapMode.route({LineString? route}) = RouteMode;
  factory MapMode.tracking(
      {required LineString route, List<Point>? waypoints}) = TrackingMode;

  const MapMode._();
}

extension EnsureMapModeExt on MapMode {
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
