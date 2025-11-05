import 'package:flutter/material.dart';
import 'package:map_manager/map_manager.dart';
import 'package:map_manager_mapbox_example/app_map.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:map_manager_mapbox_example/sample_data.dart';
import 'package:map_manager_mapbox_example/simple_tracking_test.dart';

class RouteModeTest extends StatefulWidget {
  const RouteModeTest({super.key});

  @override
  State<RouteModeTest> createState() => _RouteModeTestState();
}

class _RouteModeTestState extends State<RouteModeTest> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Stack(
        children: [
          AppMap(
            initialMode: MapMode.route(predefinedRoutes: {
              'initialRoute': GeoJSONFeature(
                  GeoJSONLineString(routeCoordinates),
                  properties: {
                    'line-width': 10.0,
                    'line-opacity': 1,
                    'line-cap': "round",
                    'line-join': "round",
                    'line-gradient': [
                      'interpolate',
                      ['linear'],
                      ['line-progress'],
                      0.0,
                      "#0BE3E3",
                      0.5,
                      "#07E6B2",
                      1.0,
                      "#890BE3",
                    ],
                    'line-blur': 0.0,
                    'line-z-offset': -1.0,
                  })
            }),
            onMapCreated: (manager) {},
          ),
          Positioned.fill(
            bottom: 20,
            left: 20,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: IconButton.filled(
                iconSize: 36,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SimpleTrackingTest(),
                    ),
                  );
                },
                icon: Icon(
                  Icons.navigation_rounded,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
