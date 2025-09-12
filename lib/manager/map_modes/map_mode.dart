import 'package:geojson_vi/geojson_vi.dart';
import 'package:map_manager/manager/map_modes/supported_modes.dart';
import 'package:map_manager/utils/enums.dart';

abstract class MapMode {
  MapMode.internal();

  factory MapMode.basic({bool trackUserLocation = true}) =>
      BasicMapMode(trackUserLocation);

  factory MapMode.locSel({
    int maxSelections = 1,
    List<GeoJSONPoint>? preselected,
  }) => LocSelMode(maxSelections, preselected);

  factory MapMode.route({GeoJSONLineString? route}) => RouteMode(route);

  factory MapMode.tracking({
    GeoJSONLineString? route,
    List<GeoJSONPoint>? waypoints,
    RouteTraversalSource source = RouteTraversalSource.user,
    DisplayMode displayMode = DisplayMode.showAll,
  }) => TrackingMode(route, waypoints, source, displayMode);
}
