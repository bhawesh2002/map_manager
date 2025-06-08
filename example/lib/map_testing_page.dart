import 'package:example/app_map.dart';
import 'package:flutter/material.dart';
import 'package:map_manager_mapbox/manager/map_manager.dart';
import 'package:map_manager_mapbox/manager/map_mode.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapTestingPage extends StatefulWidget {
  const MapTestingPage({super.key});

  @override
  State<MapTestingPage> createState() => _MapTestingPageState();
}

class _MapTestingPageState extends State<MapTestingPage> {
  MapManager? _mapManager;
  MapMode _currentMode = MapMode.basic();

  void _onMapCreated(manager) {
    _mapManager = manager;
  }

  void _changeMode(MapMode mode) async {
    if (_mapManager != null) {
      await _mapManager!.changeMode(mode);
    }
  }

  final _mapModesMap = <Map<String, dynamic>>[
    {'name': 'Basic Mode', 'config': BasicMapMode(trackUserLoc: true)},
    {'name': "Location Selection", 'config': LocationSelectionMode()},
    {'name': "Route Mode", 'config': RouteMode()},
    {
      'name': "Tracking Mode",
      'config': TrackingMode(route: LineString(coordinates: []))
    }
  ];
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppMap(
          initialMode: _mapModesMap.first['config'],
          onMapCreated: _onMapCreated,
        ),
        Positioned.fill(
          top: MediaQuery.viewPaddingOf(context).top + 20,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                    spacing: 12,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Map Manager Testing Suite',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _mapModesMap.map((preset) {
                          final isSelected = preset['config'] == _currentMode;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentMode = preset['config'];
                              });
                              _changeMode(_currentMode);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected ? Colors.blue : Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                preset['name'],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    ])),
          ),
        )
      ],
    );
  }
}
