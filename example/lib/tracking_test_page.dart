import 'package:flutter/material.dart';
import 'package:map_manager/map_manager.dart';
import 'package:map_manager/utils/enums.dart';
import 'package:map_manager_mapbox_example/app_map.dart';
import 'package:map_manager_mapbox_example/sample_data.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class TrackingTestPage extends StatefulWidget {
  const TrackingTestPage({super.key});

  @override
  State<TrackingTestPage> createState() => _TrackingTestPageState();
}

class _TrackingTestPageState extends State<TrackingTestPage> {
  MapManagerMapbox? _mapManager;
  LocationSimulator? _simulator;
  bool _isSimulating = false;
  bool _isTrackingModeActive = false;
  bool _isRouteTrackingActive = false;
  bool _hasPersonTracking = false;
  RouteTraversalSource? _currentActiveSource;
  int _currentRouteIndex = 0; // Track which route is currently active

  // Define multiple routes for switching
  static const List<List<List<double>>> _availableRoutes = [
    routeCoordinates, // Original route from sample_data.dart
    [
      // Alternative route (example - you can replace with your own)
      [79.641000, 21.164000],
      [79.640800, 21.163800],
      [79.640600, 21.163600],
      [79.640400, 21.163400],
      [79.640200, 21.163200],
      [79.640000, 21.163000],
      [79.639800, 21.162800],
      [79.639600, 21.162600],
      [79.639400, 21.162400],
      [79.639200, 21.162200],
    ],
  ];

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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppMap(
              onMapCreated: (manager) {
                _mapManager = manager;
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusSection(),
          const SizedBox(height: 16),
          SizedBox(
              height: 200,
              child: SingleChildScrollView(child: _buildControls())),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode Setup Section
          _buildModeSetupSection(),
          const SizedBox(height: 16),

          // Person Simulation Section
          _buildSimulationSection(),
          const SizedBox(height: 16),

          // Route Tracking Section
          _buildRouteTrackingSection(),
          const SizedBox(height: 16),

          // Source Switching Section
          _buildSourceSwitchingSection(),
          const SizedBox(height: 16),

          // Route Management Section
          _buildRouteManagementSection(),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                'Tracking Mode: ${_isTrackingModeActive ? 'Active' : 'Inactive'}'),
            Text(
                'Route Tracking: ${_isRouteTrackingActive ? 'Active' : 'Inactive'}'),
            Text('Person Simulation: ${_isSimulating ? 'Running' : 'Stopped'}'),
            Text(
                'Person Tracking: ${_hasPersonTracking ? 'Connected' : 'Not Connected'}'),
            Text('Active Source: ${_currentActiveSource?.name ?? 'None'}'),
            Text(
                'Current Route: Route ${_currentRouteIndex + 1} of ${_availableRoutes.length}'),
            if (_simulator?.locationNotifier != null)
              ValueListenableBuilder(
                valueListenable: _simulator!.locationNotifier,
                builder: (context, locUpdate, child) {
                  return Text(
                    'Simulated Position: ${locUpdate!.location.coordinates.lng.toStringAsFixed(4)}, ${locUpdate.location.coordinates.lat.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSetupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Mode Setup',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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
                    child: const Text("Deactivate Mode"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('2. Person Simulation',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTrackingModeActive && !_isSimulating
                        ? _startSimulation
                        : null,
                    child: const Text("Start Person Simulation"),
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
            ElevatedButton(
              onPressed:
                  _isTrackingModeActive && _isSimulating && !_hasPersonTracking
                      ? _connectPersonToTracking
                      : null,
              child: const Text("Connect Person to Tracking"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteTrackingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('3. Route Tracking Control',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTrackingModeActive && !_isRouteTrackingActive
                        ? _startRouteTracking
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600]),
                    child: const Text("Start Route Tracking"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isRouteTrackingActive ? _stopRouteTracking : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600]),
                    child: const Text("Stop Route Tracking"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSwitchingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('4. Real-time Source Switching',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRouteTrackingActive &&
                            _currentActiveSource != RouteTraversalSource.user
                        ? _switchToUserTracking
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentActiveSource == RouteTraversalSource.user
                              ? Colors.blue[700]
                              : null,
                    ),
                    child: Text(
                      "Track User",
                      style: TextStyle(
                        color: _currentActiveSource == RouteTraversalSource.user
                            ? Colors.white
                            : null,
                        fontWeight:
                            _currentActiveSource == RouteTraversalSource.user
                                ? FontWeight.bold
                                : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRouteTrackingActive &&
                            _hasPersonTracking &&
                            _currentActiveSource != RouteTraversalSource.person
                        ? _switchToPersonTracking
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentActiveSource == RouteTraversalSource.person
                              ? Colors.purple[700]
                              : null,
                    ),
                    child: Text(
                      "Track Person",
                      style: TextStyle(
                        color:
                            _currentActiveSource == RouteTraversalSource.person
                                ? Colors.white
                                : null,
                        fontWeight:
                            _currentActiveSource == RouteTraversalSource.person
                                ? FontWeight.bold
                                : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isRouteTrackingActive && _hasPersonTracking)
              ElevatedButton(
                onPressed: _demonstrateRealTimeSwitching,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[600]),
                child: const Text("Demo: Auto Switch Sources"),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('5. Real-time Route Management',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                'Current: Route ${_currentRouteIndex + 1} of ${_availableRoutes.length}',
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTrackingModeActive && _currentRouteIndex > 0
                        ? _switchToPreviousRoute
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[600]),
                    child: const Text("Previous Route"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTrackingModeActive &&
                            _currentRouteIndex < _availableRoutes.length - 1
                        ? _switchToNextRoute
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[600]),
                    child: const Text("Next Route"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed:
                  _isTrackingModeActive ? _demonstrateRouteSwapping : null,
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.teal[600]),
              child: const Text("Demo: Auto Route Switching"),
            ),
          ],
        ),
      ),
    );
  }

  // Mode Management
  Future<void> _activateTrackingMode() async {
    if (_mapManager == null) return;

    await _mapManager!.changeMode(MapMode.tracking(geojson: {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": _availableRoutes[_currentRouteIndex]
      },
      "properties": {
        "name": "Route ${_currentRouteIndex + 1}",
        "description": "Initial tracking route"
      }
    }));
    await _startRouteTracking();

    setState(() {
      _isTrackingModeActive = true;
    });
  }

  Future<void> _deactivateTrackingMode() async {
    if (_mapManager == null) return;

    // Stop everything first
    _stopSimulation();

    // Change to a different mode (you can adjust this to any valid mode in your system)
    // await _mapManager!.changeMode(MapMode.idle()); // or whatever default mode you have

    setState(() {
      _isTrackingModeActive = false;
      _isRouteTrackingActive = false;
      _hasPersonTracking = false;
      _currentActiveSource = null;
    });
  }

  // Simulation Management
  Future<void> _startSimulation() async {
    if (_mapManager == null) return;

    final route = LineString(coordinates: doubledRoutePositionList);
    _simulator = LocationSimulator(
        route: route, updateInterval: const Duration(seconds: 2));

    _simulator!.start();

    setState(() {
      _isSimulating = true;
    });
  }

  void _stopSimulation() {
    _simulator?.stop();
    _simulator = null;

    setState(() {
      _isSimulating = false;
      _hasPersonTracking = false;
    });
  }

  Future<void> _connectPersonToTracking() async {
    if (_mapManager == null || _simulator == null) return;

    _mapManager!.whenTrackingMode((mode) async {
      await mode.addPersonToTracking(_simulator!.locationNotifier);
    });

    setState(() {
      _hasPersonTracking = true;
    });
  }

  // Route Tracking Management
  Future<void> _startRouteTracking() async {
    if (_mapManager == null) return;

    _mapManager!.whenTrackingMode((mode) async {
      await mode.startTracking();
    });

    setState(() {
      _isRouteTrackingActive = true;
      _currentActiveSource = RouteTraversalSource.user; // Default source
    });
  }

  Future<void> _stopRouteTracking() async {
    if (_mapManager == null) return;

    // Note: You might need to add a stopTracking method to TrackingModeClass
    // For now, we'll just reset the state
    _mapManager!.whenTrackingMode((mode) async {
      await mode.stopActiveSourceTracking();
    });
    setState(() {
      _isRouteTrackingActive = false;
      _currentActiveSource = null;
    });
  }

  // Source Switching
  Future<void> _switchToUserTracking() async {
    if (_mapManager == null) return;

    _mapManager!.whenTrackingMode((mode) async {
      await mode.setRouteTrackingMode(RouteTraversalSource.user);
    });

    setState(() {
      _currentActiveSource = RouteTraversalSource.user;
    });
  }

  Future<void> _switchToPersonTracking() async {
    if (_mapManager == null) return;

    _mapManager!.whenTrackingMode((mode) async {
      await mode.setRouteTrackingMode(RouteTraversalSource.person);
    });

    setState(() {
      _currentActiveSource = RouteTraversalSource.person;
    });
  }

  // Demo: Real-time switching
  Future<void> _demonstrateRealTimeSwitching() async {
    if (_mapManager == null) return;

    // Switch between sources every 3 seconds
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(seconds: 3));

      if (i % 2 == 0) {
        await _switchToPersonTracking();
      } else {
        await _switchToUserTracking();
      }
    }
  }

  // Route Management Methods
  Future<void> _switchToPreviousRoute() async {
    if (_currentRouteIndex > 0) {
      _currentRouteIndex--;
      await _updateCurrentRoute();
    }
  }

  Future<void> _switchToNextRoute() async {
    if (_currentRouteIndex < _availableRoutes.length - 1) {
      _currentRouteIndex++;
      await _updateCurrentRoute();
    }
  }

  Future<void> _updateCurrentRoute() async {
    if (_mapManager == null) return;

    final newRouteGeoJson = {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": _availableRoutes[_currentRouteIndex]
      },
      "properties": {
        "name": "Route ${_currentRouteIndex + 1}",
        "description": "Real-time switched route"
      }
    };

    _mapManager!.whenTrackingMode((mode) async {
      await mode.updateRoute(newRouteGeoJson);
      await mode.startTracking();
    });

    setState(() {
      // UI will reflect the route change
    });
  }

  Future<void> _demonstrateRouteSwapping() async {
    if (_mapManager == null) return;

    final originalIndex = _currentRouteIndex;

    // Switch between routes every 4 seconds
    for (int i = 0; i < 4; i++) {
      await Future.delayed(const Duration(seconds: 4));

      // Alternate between routes
      if (_currentRouteIndex == 0 && _availableRoutes.length > 1) {
        await _switchToNextRoute();
      } else if (_currentRouteIndex > 0) {
        await _switchToPreviousRoute();
      }
    }

    // Return to original route
    _currentRouteIndex = originalIndex;
    await _updateCurrentRoute();
  }
}
