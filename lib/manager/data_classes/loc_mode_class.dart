import 'package:flutter/services.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:map_manager/manager/map_assets.dart';
import 'package:map_manager/map_manager.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class LocationModeClass implements ModeHandler {
  final LocSelMode mode;
  final MapboxMap _map;
  LocationModeClass(this.mode, this._map);

  final ManagerLogger _logger = ManagerLogger('LocationModeClass');

  final Map<String, GeoJSONPoint> _selectedPointsMap = {};
  Map<String, GeoJSONPoint> get selectedPointsMap => _selectedPointsMap;

  List<GeoJSONPoint> get selectedPoints => _selectedPointsMap.values.toList();
  List<String> get pointIdentifiers => _selectedPointsMap.keys.toList();

  GeoJSONPoint? get lastTapped => _selectedPointsMap.values.isNotEmpty
      ? _selectedPointsMap.values.last
      : null;

  static Future<LocationModeClass> initialize(
    LocSelMode mode,
    MapboxMap map,
  ) async {
    LocationModeClass cls = LocationModeClass(mode, map);
    await cls._addDefaultImage();
    cls._map.setOnMapTapListener(cls._onMapTapCallback);
    await cls._addInitialPointAnnotations();
    return cls;
  }

  void _onMapTapCallback(MapContentGestureContext context) async {
    if (selectedPoints.length >= mode.maxSelections) {
      await removeOldestAnnotation();
    }
    await addPoint(context.point.toGeojsonPoint(), zoom: true);
  }

  Future<void> _addDefaultImage() async {
    await _map.style.addStyleImage(
      'def-locsel-img',
      1.0,
      MbxImage(
        width: MapAssets.selectedLoc.width,
        height: MapAssets.selectedLoc.height,
        data: MapAssets.selectedLoc.asset,
      ),
      true,
      [],
      [],
      null,
    );
  }

  Future<void> _addInitialPointAnnotations() async {
    if (mode.preselected != null && mode.preselected!.isNotEmpty) {
      for (var pt
          in mode.preselected!.entries
              .toList()
              .take(mode.maxSelections)
              .toList()) {
        await addPoint(pt.value, id: pt.key);
      }
      // Zoom to the bounding box of pre-selected locations
      if (mode.preselected!.isNotEmpty) {
        await zoomToBounds();
      }
    }
  }

  Future<void> addPoint(
    GeoJSONPoint point, {
    String? id,
    MapAsset? image,
    bool zoom = false,
    ByteData? asset,
  }) async {
    id = id ?? "pointAt_${selectedPoints.length + 1}";
    if (image != null) {
      await _map.style
          .addSource(
            GeoJsonSource(id: '$id-src', data: GeoJSONFeature(point).toJSON()),
          )
          .then((_) {
            _selectedPointsMap.putIfAbsent(id!, () => point);
          });

      await _map.style.addStyleImage(
        '$id-img',
        1.0,
        MbxImage(width: image.width, height: image.height, data: image.asset),
        true,
        [],
        [],
        null,
      );
    }
    await _map.style.addLayer(
      SymbolLayer(
        id: '$id-lyr',
        sourceId: '$id-src',
        iconImage: image == null ? 'def-locsel-img' : '$id-img',
      ),
    );
    zoom ? await zoomToBounds() : null;
  }

  Future<void> removePoint(String identifier) async {
    if (!_selectedPointsMap.containsKey(identifier)) {
      throw Exception('Specified Identifier Was Not Found');
    }
    _selectedPointsMap.remove(identifier);
    await _map.style.removeStyleLayer('$identifier-lyr');
    await _map.style.removeStyleSource('$identifier-src');
  }

  Future<void> removeOldestAnnotation() async {
    final identifier = _selectedPointsMap.keys.last;
    await removePoint(identifier);
  }

  Future<void> clearAllAnnotations() async {
    for (var key in pointIdentifiers) {
      await removePoint(key);
    }
  }

  /// Zooms the map camera to fit all selected points within the viewport.
  ///
  /// This method uses the shared utility function to create a bounding box
  /// that encompasses all currently selected points and adjusts the camera
  /// to show this entire area. If there are no points selected, this method does nothing.
  ///
  /// Parameters:
  /// - [paddingPixels]: Padding around the bounds in screen pixels
  /// - [animationDuration]: Duration for the camera animation in milliseconds
  Future<void> zoomToBounds({
    double paddingPixels = 50.0,
    int animationDuration = 1000,
  }) async {
    await zoomToFitPoints(
      _map,
      selectedPoints,
      paddingPixels: paddingPixels,
      animationDuration: animationDuration,
    );
  }

  @override
  Future<void> dispose() async {
    _logger.info("Cleaning Location Mode Data");
    _map.setOnMapTapListener(null);
    await clearAllAnnotations();
    _logger.info("Location Mode Data Cleared");
  }
}
