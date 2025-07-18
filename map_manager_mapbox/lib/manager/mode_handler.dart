import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// A common interface for all map mode handlers.
///
/// This interface defines the contract that all mode-specific classes must implement,
/// ensuring consistent behavior across different map modes.
abstract class ModeHandler {
  static Future<void> initialize(MapboxMap map, MapMode mode) {
    throw UnimplementedError();
  }

  /// Disposes the mode handler and cleans up resources.
  ///
  /// This method should be called when switching to a different mode or
  /// when the map is being disposed.
  ///
  /// Parameters:
  /// - [map]: The MapboxMap instance to clean up
  Future<void> dispose();
}
