import 'package:flutter/material.dart';
import 'package:map_manager/map_manager.dart';
import 'package:map_manager_mapbox_example/app_map.dart';
import 'package:map_manager_mapbox_example/sample_data.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geojson_vi/geojson_vi.dart';

class SimpleTrackingTest extends StatefulWidget {
  const SimpleTrackingTest({super.key});

  @override
  State<SimpleTrackingTest> createState() => _SimpleTrackingTestState();
}

class _SimpleTrackingTestState extends State<SimpleTrackingTest> {
  MapManagerMapbox? _mapManager;
  LocationSimulator? _simulator;
  bool _isSimulating = false;
  bool _isTrackingModeActive = false;
  bool _hasPersonTracking = false;

  // Wrapper to convert nullable to non-nullable
  ValueNotifier<LocationUpdate>? _nonNullableLocationNotifier;

  @override
  void dispose() {
    _stopSimulation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Person Tracking Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: AppMap(
              onMapCreated: (manager) {
                _mapManager = manager;
              },
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instructions:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          )),
                  const SizedBox(height: 4),
                  Text(
                    '1. Activate Tracking Mode\n2. Start Simulation\n3. Start Person Tracking\n4. Watch real-time route progress!',
                    style: TextStyle(color: Colors.blue[700], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status:',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                      'Tracking Mode: ${_isTrackingModeActive ? 'Active' : 'Inactive'}'),
                  Text('Simulation: ${_isSimulating ? 'Running' : 'Stopped'}'),
                  Text(
                      'Person Tracking: ${_hasPersonTracking ? 'Active - Real-time tracking!' : 'Inactive'}',
                      style: TextStyle(
                        color: _hasPersonTracking ? Colors.green[700] : null,
                        fontWeight: _hasPersonTracking ? FontWeight.bold : null,
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mode Control
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      !_isTrackingModeActive ? _activateTrackingMode : null,
                  child: const Text("Activate Tracking Mode"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _isTrackingModeActive ? _deactivateTrackingMode : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400]),
                  child: const Text("Deactivate"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Simulation Control
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: !_isSimulating ? _startSimulation : null,
                  child: const Text("Start Simulation"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSimulating ? _stopSimulation : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[400]),
                  child: const Text("Stop Simulation"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Person Tracking
          ElevatedButton(
            onPressed:
                _isTrackingModeActive && _isSimulating && !_hasPersonTracking
                    ? _startPersonTracking
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasPersonTracking ? Colors.green[600] : null,
            ),
            child: Text(
              _hasPersonTracking
                  ? "Person Tracking Active"
                  : "Start Person Tracking",
              style: TextStyle(
                color: _hasPersonTracking ? Colors.white : null,
                fontWeight: _hasPersonTracking ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _activateTrackingMode() async {
    if (_mapManager == null) return;

    // Create the route feature
    final routeFeature = GeoJSONFeature(
      GeoJSONLineString(routeCoordinates),
    );

    // Initialize tracking mode with the route
    await _mapManager!.changeMode(
      MapMode.tracking(
        initialRoutes: {'main-route': routeFeature},
      ),
    );

    setState(() {
      _isTrackingModeActive = true;
    });
  }

  Future<void> _deactivateTrackingMode() async {
    if (_mapManager == null) return;

    // Stop everything first
    _stopSimulation();

    setState(() {
      _isTrackingModeActive = false;
      _hasPersonTracking = false;
    });
  }

  Future<void> _startSimulation() async {
    final route = LineString(coordinates: doubledRoutePositionList);
    _simulator = LocationSimulator(
      route: route,
      updateInterval: const Duration(seconds: 2),
    );
    _simulator!.start();

    // Create non-nullable wrapper
    _nonNullableLocationNotifier = ValueNotifier<LocationUpdate>(
      LocationUpdate(
        location: GeoJSONFeature(GeoJSONPoint([0, 0])),
        lastUpdated: DateTime.now(),
      ),
    );

    // Listen to nullable notifier and update non-nullable one
    _simulator!.locationNotifier.addListener(() {
      final update = _simulator!.locationNotifier.value;
      if (update != null) {
        _nonNullableLocationNotifier!.value = update;
      }
    });

    setState(() {
      _isSimulating = true;
    });
  }

  void _stopSimulation() {
    _simulator?.stop();
    _simulator = null;
    _nonNullableLocationNotifier = null;

    setState(() {
      _isSimulating = false;
      _hasPersonTracking = false;
    });
  }

  Future<void> _startPersonTracking() async {
    if (_mapManager == null ||
        _nonNullableLocationNotifier == null ||
        !_isTrackingModeActive) {
      return;
    }

    _mapManager!.whenTrackingMode((mode) async {
      await mode.addTraversalSource(
        _nonNullableLocationNotifier!,
        'main-route',
        identifier: 'person-tracking',
      );
    });

    setState(() {
      _hasPersonTracking = true;
    });
  }
}
