import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:map_manager_mapbox/manager/map_utils.dart';
import 'package:map_manager_mapbox/utils/list_value_notifier.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'data_classes/basic_mode_class.dart';
import 'data_classes/loc_mode_class.dart';
import 'data_classes/ride_tracking_mode_class.dart';
import 'data_classes/route_mode_class.dart';
import 'location_update.dart';

class MapManager extends ChangeNotifier {
  MapMode _mode;
  final MapboxMap _mapboxMap;
  late final AnimationController _animationController;
  MapManager._(this._mapboxMap, this._mode, this._animationController);

  RideTrackingModeClass? _trackingModeClass;
  BasicModeClass? _basicModeClass;
  LocationModeClass? _locationModeClass;
  RouteModeClass? _routeModeClass;

  static Future<MapManager> init(
    MapboxMap mapboxMap,
    AnimationController animController, {
    MapMode? mode,
  }) async {
    if (kDebugMode) {
      Logger.root.onRecord.listen((log) {
        debugPrint(
            "${log.loggerName} : ${log.level} : ${log.message} : ${log.time} ");
      });
    }

    mode = mode ?? MapMode.basic();
    final manager = MapManager._(mapboxMap, mode, animController);
    await manager.changeMode(mode);
    return manager;
  }

  final Logger _logger = Logger("MapManager");

  MapMode get mapMode => _mode;

  Future<void> changeMode(MapMode mode) async {
    await _cleanExistingModeData();
    _mode = mode;
    await _mode.map(basic: (basic) async {
      await _handleBasicMode(basic);
    }, locationSel: (locationSel) async {
      await _handleLocSelMode(locationSel);
    }, routeMode: (routeMode) async {
      await _handleRouteMode(routeMode);
    }, rideTracking: (RideTrackingMode value) async {
      await _handleRideTrackingMode(value);
    });
  }

  Future<void> _cleanExistingModeData() async {
    await _mode.map(basic: (basic) async {
      await _basicModeClass?.clearBasicModeDat(_mapboxMap);
      _basicModeClass = null;
    }, locationSel: (locationSel) async {
      await _locationModeClass?.cleanLocModeDat(_mapboxMap);
      _locationModeClass = null;
    }, routeMode: (routeMode) async {
      await _routeModeClass?.cleanRouteModeDat(_mapboxMap);
      _routeModeClass = null;
    }, rideTracking: (RideTrackingMode value) async {
      await _trackingModeClass?.cleanRideTrackingData(_mapboxMap);
      _trackingModeClass = null;
    });
  }

  Future<void> addRoute(LineString route) async {
    _mode.ensureMode<RouteMode>();
    await _routeModeClass!.addLineString(route, _mapboxMap);
  }

  Future<void> startTracking(
      ValueNotifier<LocationUpdate?> personLocation) async {
    _mode.ensureMode<RideTrackingMode>();
    await _trackingModeClass?.startTracking(personLocation);
  }

  LineString get routeTraversed => _trackingModeClass!.routeTraversed;

  Future<void> _handleRideTrackingMode(RideTrackingMode tracking) async {
    _mode.ensureMode<RideTrackingMode>();
    _trackingModeClass = await RideTrackingModeClass.initialize(
        _mapboxMap, tracking.route, _animationController,
        waypoints: tracking.waypoints);
    _logger.info('Mode changed to Ride Tracking Mode');
  }

  Future<void> _handleBasicMode(BasicMapMode basic) async {
    _mode.ensureMode<BasicMapMode>();
    _basicModeClass = await BasicModeClass.initialize(_mapboxMap, basic);
    _logger.info('Mode changed to Basic Map Mode');
  }

  Future<void> _handleLocSelMode(LocationSelectionMode locSel) async {
    _mode.ensureMode<LocationSelectionMode>();
    _locationModeClass = await LocationModeClass.initialize(locSel, _mapboxMap);
    _logger.info('Mode changed to Location Selection');
  }

  ListValueNotifier? get pointsNotifier => _locationModeClass?.pointsNotifier;
  Point? get lastTapped => _locationModeClass?.lastTapped;

  Future<void> _handleRouteMode(RouteMode routeMode) async {
    _mode.ensureMode<RouteMode>();
    _routeModeClass = await RouteModeClass.initialize(routeMode, _mapboxMap);
    _logger.info('Mode changed to Route mode');
  }

  Future<void> moveCamTo(Point point) async =>
      await moveMapCamTo(_mapboxMap, point);
  Future<void> moveBy(double x, double y) async =>
      await moveMapBy(_mapboxMap, x, y);

  Future<void> onStyleLoaded(StyleLoadedEventData context) async {}
}
