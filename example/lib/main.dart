import 'package:flutter/material.dart';
import 'package:map_manager_mapbox/map_manager_mapbox.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(const String.fromEnvironment("MAPBOX_API_KEY"));
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Manager Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MapDemoHome(),
    );
  }
}

class MapDemoHome extends StatefulWidget {
  const MapDemoHome({super.key});

  @override
  State<MapDemoHome> createState() => _MapDemoHomeState();
}

class _MapDemoHomeState extends State<MapDemoHome>
    with SingleTickerProviderStateMixin {
  MapManager? _mapManager;
  late AnimationController _animationController;
  MapMode _currentMode = MapMode.basic();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    // Initialize map manager when map is created
    _mapManager = await MapManager.init(
      mapboxMap,
      _animationController,
      mode: _currentMode,
    );

    setState(() {});
  }

  void _changeMode(MapMode mode) async {
    if (_mapManager != null) {
      await _mapManager!.changeMode(mode);
      setState(() {
        _currentMode = mode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Manager Demo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: MapWidget(
              key: const ValueKey('mapWidget'),
              onMapCreated: _onMapCreated,
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(37.7749, -122.4194)),
                zoom: 9.0,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () =>
                        _changeMode(MapMode.basic(trackUserLoc: true)),
                    child: const Text('Basic Mode'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _changeMode(MapMode.locationSel(maxSelections: 3)),
                    child: const Text('Location Mode'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Example route - replace with actual route data
                      final lineString = LineString(coordinates: [
                        Position(-122.4194, 37.7749), // San Francisco
                        Position(-122.2711, 37.8043), // Berkeley
                      ]);
                      _changeMode(MapMode.routeMode(route: lineString));
                    },
                    child: const Text('Route Mode'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
