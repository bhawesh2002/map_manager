import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'data_classes/basic_mode_class.dart';
import 'data_classes/loc_mode_class.dart';
import 'data_classes/tracking_mode_class.dart';
import 'data_classes/route_mode_class.dart';

class MapManager extends ChangeNotifier {
  MapMode _mode;
  final MapboxMap _mapboxMap;
  late final AnimationController _animationController;
  MapManager._(this._mapboxMap, this._mode, this._animationController);

  TrackingModeClass? _trackingModeClass;
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
    }, route: (routeMode) async {
      await _handleRouteMode(routeMode);
    }, tracking: (TrackingMode value) async {
      await _handleTrackingMode(value);
    });
  }

  Future<void> _cleanExistingModeData() async {
    await _mode.map(basic: (basic) async {
      await _basicModeClass?.dispose(_mapboxMap);
      _basicModeClass = null;
    }, locationSel: (locationSel) async {
      await _locationModeClass?.dispose(_mapboxMap);
      _locationModeClass = null;
    }, route: (routeMode) async {
      await _routeModeClass?.dispose(_mapboxMap);
      _routeModeClass = null;
    }, tracking: (TrackingMode value) async {
      await _trackingModeClass?.dispose(_mapboxMap);
      _trackingModeClass = null;
    });
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

  Future<void> _handleRouteMode(RouteMode routeMode) async {
    _mode.ensureMode<RouteMode>();
    _routeModeClass = await RouteModeClass.initialize(routeMode, _mapboxMap);
    _logger.info('Mode changed to Route mode');
  }

  Future<void> _handleTrackingMode(TrackingMode tracking) async {
    _mode.ensureMode<TrackingMode>();
    _trackingModeClass = await TrackingModeClass.initialize(
        _mapboxMap, tracking.route, _animationController,
        waypoints: tracking.waypoints);
    _logger.info('Mode changed to Tracking Mode');
  }

  Future<void> onStyleLoaded(StyleLoadedEventData context) async {}

  dynamic get currentMode => _mode;
}
