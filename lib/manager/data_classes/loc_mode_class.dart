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

  final _featureCollection = GeoJSONFeatureCollection([]);

  static const String _sourceId = 'location-selection-source';
  static const String _layerId = 'location-selection-layer';

  String get defImageId => 'def-locsel-img';

  GeoJSONPoint? get lastTapped => _selectedPointsMap.values.isNotEmpty
      ? _selectedPointsMap.values.last
      : null;

  static Future<LocationModeClass> initialize(
    LocSelMode mode,
    MapboxMap map,
  ) async {
    LocationModeClass cls = LocationModeClass(mode, map);
    await cls._addDefaultImage();
    await cls._setupSource();
    cls._map.setOnMapTapListener(cls._onMapTapCallback);
    await cls._addInitialPointAnnotations();
    return cls;
  }

  void _onMapTapCallback(MapContentGestureContext context) async {
    if (selectedPoints.length >= mode.maxSelections) {
      await removeOldestPoint();
    }
    await addPoint(context.point.toGeojsonPoint(), zoom: true);
  }

  Future<void> _setupSource() async {
    await _map.style.addSource(
      GeoJsonSource(id: _sourceId, data: _featureCollection.toJSON()),
    );

    await _map.style.addLayer(
      SymbolLayer(
        id: _layerId,
        sourceId: _sourceId,
        iconImage: defImageId,
        iconOffset: [0.0, -22.0],
        iconAllowOverlap: true,
        iconColor: 0xFF0DC8C8,
      ),
    );
  }

  Future<void> _updateSource() async {
    final features = _selectedPointsMap.entries.map((entry) {
      return GeoJSONFeature(entry.value, properties: {'id': entry.key});
    }).toList();

    final featureCollection = GeoJSONFeatureCollection(features);

    await _map.style.setStyleSourceProperty(
      _sourceId,
      'data',
      featureCollection.toJSON(),
    );
  }

  Future<void> _addDefaultImage() async {
    await _map.style.addStyleImage(
      defImageId,
      2.5,
      MbxImage(
        width: MapAssets.selectedLoc.width,
        height: MapAssets.selectedLoc.height,
        data: MapAssets.selectedLoc.asset,
      ),
      true, //sdf as true does not retains original png colors
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
        _selectedPointsMap.putIfAbsent(pt.key, () => pt.value);
      }

      // Update the source with preselected points
      await _updateSource();

      // Zoom to the bounding box of pre-selected locations
      if (mode.preselected!.isNotEmpty) {
        await zoomToBounds();
      }
    }
  }

  static int pointsCount = 0;

  Future<void> addPoint(
    GeoJSONPoint point, {
    String? id,
    bool zoom = false,
  }) async {
    id = id ?? "pointAt_$pointsCount";
    _selectedPointsMap.putIfAbsent(id, () {
      pointsCount++;
      return point;
    });
    _logger.info(
      "${_selectedPointsMap.length} ${_selectedPointsMap.keys.toList()}",
    );
    await _updateSource();

    if (zoom) {
      await zoomToBounds();
    }
  }

  Future<void> removeOldestPoint() async {
    if (_selectedPointsMap.isNotEmpty) {
      final oldestKey = _selectedPointsMap.keys.first;
      _selectedPointsMap.remove(oldestKey);
      await _updateSource();
    }
  }

  Future<void> removePoint(String identifier) async {
    if (!_selectedPointsMap.containsKey(identifier)) {
      throw Exception('Specified Identifier Was Not Found');
    }
    _selectedPointsMap.remove(identifier);
    await _updateSource();
  }

  Future<void> clearAllAnnotations() async {
    _selectedPointsMap.clear();
    await _updateSource();
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

    // Remove layer and source
    try {
      await _map.style.removeStyleLayer(_layerId);
      await _map.style.removeStyleSource(_sourceId);
    } catch (e) {
      _logger.warning("Error removing style elements: $e");
    }

    _selectedPointsMap.clear();
    _logger.info("Location Mode Data Cleared");
  }
}
