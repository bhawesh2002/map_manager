import 'package:flutter/material.dart';
import 'package:map_manager/manager/map_assets.dart';
import 'package:map_manager/map_manager.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapManagerMapbox extends ChangeNotifier {
  MapMode _mode;
  final MapboxMap _mapboxMap;
  late final AnimationController _animationController;
  MapManagerMapbox._(this._mapboxMap, this._mode, this._animationController);

  static Future<MapManagerMapbox> init(
    MapboxMap mapboxMap,
    AnimationController animController, {
    MapMode? mode,
  }) async {
    await MapAssets.init();
    mode = mode ?? MapMode.basic();
    final manager = MapManagerMapbox._(mapboxMap, mode, animController);
    await manager.changeMode(mode);
    return manager;
  }

  final ManagerLogger _logger = ManagerLogger("MapManagerMapbox");

  ModeHandler? _currentModeHandler;

  MapMode get mapMode => _mode;
  MapboxMap get mapboxMap => _mapboxMap;

  Future<void> changeMode(MapMode mode) async {
    await _cleanExistingModeData();
    _mode = mode;
    await _mode.map(
      basic: (basic) async {
        await _handleBasicMode(basic);
      },
      locationSel: (locationSel) async {
        await _handleLocSelMode(locationSel);
      },
      route: (routeMode) async {
        await _handleRouteMode(routeMode);
      },
      tracking: (TrackingMode value) async {
        await _handleTrackingMode(value);
      },
    );
    notifyListeners();
  }

  Future<void> _cleanExistingModeData() async {
    if (_currentModeHandler != null) {
      try {
        await _currentModeHandler!.dispose();
        _currentModeHandler = null;

        // Small delay to ensure cleanup is complete
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        _logger.warning("Error disposing current mode handler: $e");
        _currentModeHandler = null;
      }
    }
  }

  Future<void> _handleBasicMode(BasicMapMode basic) async {
    _mode.ensureMode<BasicMapMode>();
    _currentModeHandler = await BasicModeClass.initialize(_mapboxMap, basic);
    _logger.info('Mode changed to Basic Map Mode');
  }

  Future<void> _handleLocSelMode(LocationSelectionMode locSel) async {
    _mode.ensureMode<LocationSelectionMode>();
    _currentModeHandler = await LocationModeClass.initialize(
      locSel,
      _mapboxMap,
    );
    _logger.info('Mode changed to Location Selection');
  }

  Future<void> _handleRouteMode(RouteMode routeMode) async {
    _mode.ensureMode<RouteMode>();
    _currentModeHandler = await RouteModeClass.initialize(
      routeMode,
      _mapboxMap,
    );
    _logger.info('Mode changed to Route mode');
  }

  Future<void> _handleTrackingMode(TrackingMode tracking) async {
    _mode.ensureMode<TrackingMode>();
    _currentModeHandler = await TrackingModeClass.initialize(
      tracking,
      _mapboxMap,
      _animationController,
    );
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

  /// Executes the provided callback if the current mode is a BasicModeClass
  ///
  /// Returns true if the callback was executed, false otherwise
  bool whenBasicMode(void Function(BasicModeClass mode) callback) {
    final basicMode = getModeHandlerAs<BasicModeClass>();
    if (basicMode != null) {
      callback(basicMode);
      return true;
    }
    return false;
  }

  /// Executes the provided callback if the current mode is a LocationModeClass
  ///
  /// Returns true if the callback was executed, false otherwise
  bool whenLocationMode(void Function(LocationModeClass mode) callback) {
    final locationMode = getModeHandlerAs<LocationModeClass>();
    if (locationMode != null) {
      callback(locationMode);
      return true;
    }
    return false;
  }

  /// Executes the provided callback if the current mode is a RouteModeClass
  ///
  /// Returns true if the callback was executed, false otherwise
  bool whenRouteMode(void Function(RouteModeClass mode) callback) {
    final routeMode = getModeHandlerAs<RouteModeClass>();
    if (routeMode != null) {
      callback(routeMode);
      return true;
    }
    return false;
  }

  /// Executes the provided callback if the current mode is a TrackingModeClass
  ///
  /// Returns true if the callback was executed, false otherwise
  bool whenTrackingMode(void Function(TrackingModeClass mode) callback) {
    final trackingMode = getModeHandlerAs<TrackingModeClass>();
    if (trackingMode != null) {
      callback(trackingMode);
      return true;
    }
    return false;
  }

  /// Pattern matches on the current mode handler and executes the corresponding callback
  ///
  /// This method allows for handling different mode types in a concise way, similar to
  /// switch expressions or pattern matching in other languages.
  ///
  /// Example usage:
  /// ```dart
  /// mapManager.matchModeHandler(
  ///   basic: (basicMode) => basicMode.zoomToLocation(),
  ///   location: (locMode) => print('Selected points: ${locMode.selectedPoints}'),
  ///   route: (routeMode) => print('Current route: ${routeMode.route}'),
  ///   tracking: (trackingMode) => trackingMode.updateLocation(newLocation),
  ///   orElse: () => print('Unknown mode type'),
  /// );
  /// ```
  void matchModeHandler({
    void Function(BasicModeClass mode)? basic,
    void Function(LocationModeClass mode)? location,
    void Function(RouteModeClass mode)? route,
    void Function(TrackingModeClass mode)? tracking,
    void Function()? orElse,
  }) {
    if (basic != null && whenBasicMode(basic)) {
      return;
    }
    if (location != null && whenLocationMode(location)) {
      return;
    }
    if (route != null && whenRouteMode(route)) {
      return;
    }
    if (tracking != null && whenTrackingMode(tracking)) {
      return;
    }
    if (orElse != null) {
      orElse();
    }
  }

  /// Pattern matches on the current mode handler and returns the result of the corresponding callback
  ///
  /// This method is similar to [matchModeHandler] but allows for returning values from the callbacks.
  ///
  /// Example usage:
  /// ```dart
  /// String status = mapManager.mapModeHandlerTo(
  ///   basic: (basicMode) => 'Basic mode active',
  ///   location: (locMode) => 'Selected ${locMode.selectedPoints.length} points',
  ///   route: (routeMode) => 'Route with ${routeMode.route?.coordinates.length ?? 0} points',
  ///   tracking: (trackingMode) => 'Tracking mode with location: ${trackingMode.lastKnownLoc}',
  ///   orElse: () => 'Unknown mode',
  /// );
  /// ```
  T mapModeHandlerTo<T>({
    T Function(BasicModeClass mode)? basic,
    T Function(LocationModeClass mode)? location,
    T Function(RouteModeClass mode)? route,
    T Function(TrackingModeClass mode)? tracking,
    required T Function() orElse,
  }) {
    if (basic != null) {
      final basicMode = getModeHandlerAs<BasicModeClass>();
      if (basicMode != null) {
        return basic(basicMode);
      }
    }
    if (location != null) {
      final locationMode = getModeHandlerAs<LocationModeClass>();
      if (locationMode != null) {
        return location(locationMode);
      }
    }
    if (route != null) {
      final routeMode = getModeHandlerAs<RouteModeClass>();
      if (routeMode != null) {
        return route(routeMode);
      }
    }
    if (tracking != null) {
      final trackingMode = getModeHandlerAs<TrackingModeClass>();
      if (trackingMode != null) {
        return tracking(trackingMode);
      }
    }
    return orElse();
  }

  /// Convenience getters to check which mode is currently active

  /// Returns true if the current mode is a BasicModeClass
  bool get isBasicMode => _currentModeHandler is BasicModeClass;

  /// Returns true if the current mode is a LocationModeClass
  bool get isLocationMode => _currentModeHandler is LocationModeClass;

  /// Returns true if the current mode is a RouteModeClass
  bool get isRouteMode => _currentModeHandler is RouteModeClass;

  /// Returns true if the current mode is a TrackingModeClass
  bool get isTrackingMode => _currentModeHandler is TrackingModeClass;

  /// Direct getters for the mode handlers (will throw if the mode doesn't match)

  /// Returns the current mode handler as a BasicModeClass
  ///
  /// Throws an exception if the current mode is not a BasicModeClass
  BasicModeClass get basicModeHandler => _currentModeHandler is BasicModeClass
      ? _currentModeHandler as BasicModeClass
      : throw _createWrongModeException<BasicModeClass>();

  /// Returns the current mode handler as a LocationModeClass
  ///
  /// Throws an exception if the current mode is not a LocationModeClass
  LocationModeClass get locationModeHandler =>
      _currentModeHandler is LocationModeClass
      ? _currentModeHandler as LocationModeClass
      : throw _createWrongModeException<LocationModeClass>();

  /// Returns the current mode handler as a RouteModeClass
  ///
  /// Throws an exception if the current mode is not a RouteModeClass
  RouteModeClass get routeModeHandler => _currentModeHandler is RouteModeClass
      ? _currentModeHandler as RouteModeClass
      : throw _createWrongModeException<RouteModeClass>();

  /// Returns the current mode handler as a TrackingModeClass
  ///
  /// Throws an exception if the current mode is not a TrackingModeClass
  TrackingModeClass get trackingModeHandler =>
      _currentModeHandler is TrackingModeClass
      ? _currentModeHandler as TrackingModeClass
      : throw _createWrongModeException<TrackingModeClass>();

  /// Creates an exception for wrong mode access
  Exception _createWrongModeException<T extends ModeHandler>() {
    return Exception(
      'Cannot access ${T.toString()} handler. Current mode is ${_currentModeHandler.runtimeType}',
    );
  }
}
