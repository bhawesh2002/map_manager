import 'package:example/app_map.dart';
import 'package:example/sample_data.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_manager_mapbox/map_manager_mapbox.dart';
import 'package:map_manager_mapbox/utils/location_simulator.dart';

class TrackingTestPage extends StatefulWidget {
  const TrackingTestPage({super.key});

  @override
  State<TrackingTestPage> createState() => _TrackingTestPageState();
}

class _TrackingTestPageState extends State<TrackingTestPage> {
  MapManager? _mapManager;
  LocationSimulator? _simulator;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _stopSimulation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Mode Test'),
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
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Simulation controls
          ElevatedButton(
            onPressed: _isSimulating ? _stopSimulation : _startSimulation,
            child: Text(_isSimulating ? 'Stop Simulation' : 'Start Simulation'),
          ),
          const SizedBox(height: 8),

          // Status and position info
          Text('Status: ${_isSimulating ? 'Running' : 'Stopped'}',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          _simulator?.locationNotifier != null
              ? ValueListenableBuilder(
                  valueListenable: _simulator!.locationNotifier,
                  builder: (context, locUpdate, child) {
                    return Text(
                      'Current position: ${locUpdate!.location.coordinates.lng}, ${locUpdate.location.coordinates.lat}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  })
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  void _startSimulation() {
    if (_mapManager == null) return;

    // Create a test route
    final route = LineString(coordinates: routePositionList);

    // Initialize simulator with the route
    _simulator = LocationSimulator(
        route: route, updateInterval: const Duration(milliseconds: 500));

    // Set the map to tracking mode
    _mapManager!.changeMode(MapMode.tracking(route: route));

    // Start the location updates after a short delay to ensure mode is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      // Connect the simulator to the tracking mode
      _mapManager!.matchModeHandler(tracking: (trackingMode) async {
        await trackingMode.startTracking(_simulator!.locationNotifier);
      });

      // Start the simulation
      _simulator!.start();

      setState(() {
        _isSimulating = true;
      });
    });
  }

  void _stopSimulation() {
    _simulator?.stop();

    setState(() {
      _isSimulating = false;
    });
  }
}
