import 'package:flutter/material.dart';
import 'package:map_manager_mapbox_example/map_testing_page.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
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

class _MapDemoHomeState extends State<MapDemoHome> {
  Future<bool> grantLocPerm() async {
    const locPerm = Permission.location;
    if (!await Permission.location.isGranted &&
        !await Permission.locationWhenInUse.isGranted) {
      await locPerm.request();
      locPerm.onDeniedCallback(grantLocPerm);
    }
    return await locPerm.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
          future: grantLocPerm(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasError) {
              return const Center(
                  child: Text("Error while requesting location permission"));
            }
            if (snapshot.hasData && snapshot.data == false) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                      child: TextButton(
                          onPressed: () async {
                            await grantLocPerm();
                          },
                          child: const Text("Grant location permission"))),
                ],
              );
            }
            return const MapTestingPage();
          }),
    );
  }
}
