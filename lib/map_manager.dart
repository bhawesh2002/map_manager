/// A Flutter package that provides an abstraction layer over mapbox_maps_flutter.
///
/// This package simplifies map interactions for developers by providing
/// a mode-based approach to handling different map functionalities.
library;

// Export main manager class
export 'manager/map_manager_mapbox.dart';

// Export map modes
export 'manager/map_modes/map_mode.dart';
export 'manager/map_modes/supported_modes.dart';

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

// Export all files from lib/manager/tweens
export 'manager/tweens/point_tween.dart';

// Export all files from lib/models
export 'models/mode_customization.dart';

// Export all files from lib/utils
export 'utils/enums.dart';
export 'utils/extensions.dart';
export 'utils/geojson_extensions.dart';
export 'utils/geolocator_utils.dart';
export 'utils/manager_logger.dart';
export 'utils/predefined_layers_props.dart';
