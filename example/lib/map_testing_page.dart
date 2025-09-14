import 'package:flutter/material.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:map_manager/map_manager.dart';
import 'package:map_manager_mapbox_example/app_map.dart';
import 'package:map_manager_mapbox_example/simple_tracking_test.dart';

class MapTestingPage extends StatefulWidget {
  const MapTestingPage({super.key});

  @override
  State<MapTestingPage> createState() => _MapTestingPageState();
}

class _MapTestingPageState extends State<MapTestingPage> {
  MapManagerMapbox? _mapManager;
  String _currentModeType = 'Basic Mode';

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
    {'name': "Location Selection", 'config': LocSelMode(maxSelections: 4)},
    {
      'name': "Route Mode",
      'config': RouteMode(predefinedRoutes: {
        'predefined': GeoJSONFeature(
            properties: {
              "styling": {
                "line-color": "#FF5722",
                "line-width": 6.0,
                "line-opacity": 0.9,
                "line-cap": "round",
                "line-join": "round",
                "line-dasharray": [5.0, 3.0]
              }
            },
            GeoJSONLineString([
              [-122.420679, 37.772537],
              [-122.420247, 37.773245],
              [-122.419198, 37.773662],
              [-122.418640, 37.774097],
              [-122.417961, 37.774357],
              [-122.417297, 37.774674],
              [-122.416289, 37.775180],
              [-122.415389, 37.775596],
              [-122.414331, 37.776005],
              [-122.413467, 37.776335]
            ]))
      })
    },
    {'name': "Tracking Mode", 'config': 'move'}
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
                          final isSelected = preset['name'] == _currentModeType;
                          return GestureDetector(
                            onTap: () {
                              if (preset['name'] == "Tracking Mode") {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) =>
                                        const SimpleTrackingTest()));
                                return;
                              } else {
                                setState(() {
                                  _currentModeType = preset['name'];
                                });
                                _changeMode(preset['config']);
                              }
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
