import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map_manager/map_manager.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class AppMap extends StatefulWidget {
  final MapMode? initialMode;
  final Function(MapManagerMapbox manager)? onMapCreated;
  const AppMap({super.key, this.initialMode, this.onMapCreated});

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  MapManagerMapbox? manager;
  MapboxMap? mapboxMap;

  @override
  void dispose() {
    manager?.dispose();
    debugPrint("MapManager: Disposed App Map");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      onMapCreated: (controller) async {
        mapboxMap = controller;
        try {
          await controller.scaleBar
              .updateSettings(ScaleBarSettings(enabled: false));
          await controller.compass
              .updateSettings(CompassSettings(enabled: false));
          await controller.logo.updateSettings(
              LogoSettings(position: OrnamentPosition.TOP_RIGHT));
          await controller.attribution.updateSettings(
              AttributionSettings(position: OrnamentPosition.BOTTOM_LEFT));
        } on PlatformException catch (e) {
          debugPrint("Platform exception in AppMap: $e");
        }

        manager =
            await MapManagerMapbox.init(controller, mode: widget.initialMode);

        if (widget.onMapCreated != null) {
          widget.onMapCreated!(manager!);
        }
      },
      onStyleLoadedListener: manager?.onStyleLoaded,
      styleUri: "mapbox://styles/mapbox/navigation-day-v1",
      cameraOptions: CameraOptions(zoom: 4),
    );
  }
}
