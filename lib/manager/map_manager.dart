import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:map_manager_mapbox/manager/mode_handler.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'data_classes/basic_mode_class.dart';
import 'data_classes/loc_mode_class.dart';
import 'data_classes/tracking_mode_class.dart';
import 'data_classes/route_mode_class.dart';

class MapManager extends ChangeNotifier {
  MapMode _mode;
  final MapboxMap _mapboxMap;
  late final AnimationController _animationController;
  ModeHandler? _currentModeHandler;

  MapManager._(this._mapboxMap, this._mode, this._animationController);

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
    await _currentModeHandler?.dispose(_mapboxMap);
  }

  Future<void> _handleBasicMode(BasicMapMode basic) async {
    _mode.ensureMode<BasicMapMode>();
    _currentModeHandler = await BasicModeClass.initialize(_mapboxMap, basic);
    _logger.info('Mode changed to Basic Map Mode');
  }

  Future<void> _handleLocSelMode(LocationSelectionMode locSel) async {
    _mode.ensureMode<LocationSelectionMode>();
    _currentModeHandler =
        await LocationModeClass.initialize(locSel, _mapboxMap);
    _logger.info('Mode changed to Location Selection');
  }

  Future<void> _handleRouteMode(RouteMode routeMode) async {
    _mode.ensureMode<RouteMode>();
    _currentModeHandler =
        await RouteModeClass.initialize(routeMode, _mapboxMap);
    _logger.info('Mode changed to Route mode');
  }

  Future<void> _handleTrackingMode(TrackingMode tracking) async {
    _mode.ensureMode<TrackingMode>();
    _currentModeHandler = await TrackingModeClass.initialize(
        _mapboxMap, tracking.route, _animationController,
        waypoints: tracking.waypoints);
    _logger.info('Mode changed to Tracking Mode');
  }

  Future<void> onStyleLoaded(StyleLoadedEventData context) async {}

  /// Returns the current map mode
  MapMode get currentMode => _mode;

  /// Returns the current mode handler
  ModeHandler get currentModeHandler => _currentModeHandler!;

  /// Gets the mode handler as a specific type if it matches
  ///
  /// Example usage:
  /// ```dart
  /// if (mapManager.getModeHandlerAs<LocationModeClass>() != null) {
  ///   final locMode = mapManager.getModeHandlerAs<LocationModeClass>()!;
  ///   // Use locMode specific features
  /// }
  /// ```
  T? getModeHandlerAs<T extends ModeHandler>() {
    return _currentModeHandler is T ? _currentModeHandler as T : null;
  }
}
