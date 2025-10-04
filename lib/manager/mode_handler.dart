import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../map_manager.dart';

/// A common interface for all map mode handlers.
///
/// This interface defines the contract that all mode-specific classes must implement,
/// ensuring consistent behavior across different map modes.
///
/// Provides safe execution of map operations with automatic disposal on platform
/// channel errors, preventing resource leaks when the map becomes detached.
abstract class ModeHandler {
  final ManagerLogger _safeOpLogger = ManagerLogger("ModeHandler");

  bool isDisposed = false;

  static Future<void> initialize(MapboxMap map, MapMode mode) {
    throw UnimplementedError();
  }

  /// Safely executes a map operation with automatic error handling.
  ///
  /// This method wraps the provided [operation] in a try-catch block that specifically
  /// handles [PlatformException]s. If a platform exception is caught (typically indicating
  /// the map is detached), it automatically triggers disposal and returns null.
  ///
  /// Parameters:
  /// - [operation]: The async operation to execute safely
  /// - [operationName]: Optional name for logging purposes
  /// - [shouldDispose]: Whether to auto-dispose on PlatformException (default: true).
  ///   Set to false when calling from dispose() to prevent circular calls.
  ///
  /// Returns:
  /// - The result of the operation if successful
  /// - null if a PlatformException was caught or mode handler is disposed
  ///
  /// Example:
  /// ```dart
  /// await safeExecute(
  ///   () => mapboxMap.easeTo(...),
  ///   operationName: 'moveCamera',
  /// );
  ///
  /// // In dispose method:
  /// await safeExecute(
  ///   () => _map.style.removeStyleLayer(...),
  ///   operationName: 'removeLayer',
  ///   shouldDispose: false,
  /// );
  /// ```
  Future<T?> safeExecute<T>(
    Future<T> Function() operation, {
    String? operationName,
    bool shouldDispose = true,
  }) async {
    // Skip operation if already disposed
    if (isDisposed) {
      _safeOpLogger.warning(
        'Attempted to execute ${operationName ?? 'operation'} on disposed mode handler',
      );
      return null;
    }

    try {
      final result = await operation();
      return result;
    } on PlatformException catch (e) {
      _safeOpLogger.warning(
        'PlatformException during ${operationName ?? 'operation'}: ${e.message}',
      );

      // Auto-dispose on channel errors (map detached from view)
      if (shouldDispose &&
          (e.code == 'channel-error' ||
              e.message?.contains('channel') == true)) {
        _safeOpLogger.info(
          'Detected detached map state. Triggering auto-disposal...',
        );
        await dispose();
      }

      return null;
    } catch (e) {
      // Re-throw non-platform exceptions
      _safeOpLogger.severe(
        'Unexpected error during ${operationName ?? 'operation'}: $e',
      );
      rethrow;
    }
  }

  /// Executes a synchronous operation safely, skipping if disposed.
  ///
  /// Unlike [safeExecute], this doesn't handle exceptions but simply
  /// checks if the mode handler is disposed before executing.
  ///
  /// Parameters:
  /// - [operation]: The synchronous operation to execute
  /// - [operationName]: Optional name for logging purposes
  ///
  /// Returns true if the operation was executed, false if skipped due to disposal.
  bool safeExecuteSync(void Function() operation, {String? operationName}) {
    if (isDisposed) {
      _safeOpLogger.warning(
        'Skipped ${operationName ?? 'operation'} - mode handler is disposed',
      );
      return false;
    }

    operation();
    return true;
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
