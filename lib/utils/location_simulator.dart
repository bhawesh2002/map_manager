import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../manager/location_update.dart';

/// A simple simulator that generates location updates at regular intervals
/// for testing tracking functionality without requiring real GPS.
class LocationSimulator {
  /// The route to follow during simulation
  final LineString route;

  /// Controls update frequency
  final Duration updateInterval;

  /// Notifier that tracking mode will observe
  final ValueNotifier<LocationUpdate?> locationNotifier = ValueNotifier(null);

  /// Current position index along the route coordinates
  int _currentIndex = 0;

  /// Timer for regular updates
  Timer? _timer;

  /// Constructor for the location simulator
  LocationSimulator({
    required this.route,
    this.updateInterval = const Duration(milliseconds: 200),
  }) {
    // Ensure route has at least 2 points
    assert(route.coordinates.length >= 2,
        "Route must have at least 2 coordinates for simulation");
  }

  /// Start the location simulation
  ///
  /// This begins emitting location updates at the specified interval
  /// following the provided route.
  void start() {
    // Reset position to start of route
    _currentIndex = 0;

    // Create initial location
    if (route.coordinates.isNotEmpty) {
      locationNotifier.value = LocationUpdate(
        location: Point(coordinates: route.coordinates.first),
        lastUpdated: DateTime.now(),
      );
    }

    // Start periodic updates
    _timer = Timer.periodic(updateInterval, _updateLocation);
  }

  /// Stop the location simulation
  ///
  /// This cancels the timer and stops emitting location updates.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Update the simulated location based on the route
  ///
  /// This moves along the route and emits location updates through the notifier.
  void _updateLocation(Timer timer) {
    // If we've reached the end of the route, stop
    if (_currentIndex >= route.coordinates.length - 1) {
      stop();
      return;
    }

    // Move to next position
    _currentIndex++;

    // Create and emit location update
    final update = LocationUpdate(
      location: Point(coordinates: route.coordinates[_currentIndex]),
      lastUpdated: DateTime.now(),
    );

    locationNotifier.value = update;
  }
}
