/// A Flutter package that provides an abstraction layer over mapbox_maps_flutter.
///
/// This package simplifies map interactions for developers by providing
/// a mode-based approach to handling different map functionalities.
library;

// Export main manager class
export 'manager/map_manager_mapbox.dart';

// Export map modes
export 'manager/map_mode.dart';
export 'manager/mode_handler.dart';
export 'manager/map_utils.dart';
export 'manager/map_exceptions.dart';
export 'manager/location_update.dart';

// Export data classes
export 'manager/data_classes/basic_mode_class.dart';
export 'manager/data_classes/loc_mode_class.dart';
export 'manager/data_classes/route_mode_class.dart';
export 'manager/data_classes/tracking_mode_class.dart';

// Export utilities
export 'utils/utils.dart';
export 'utils/route_utils.dart';
export 'utils/list_value_notifier.dart';
export 'utils/location_simulator.dart';

// Export models
export 'models/mapbox_route.dart';
