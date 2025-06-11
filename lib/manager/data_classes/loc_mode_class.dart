import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/manager/map_assets.dart';
import 'package:map_manager_mapbox/map_manager_mapbox.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class LocationModeClass implements ModeHandler {
  final LocationSelectionMode mode;
  final MapboxMap _map;
  LocationModeClass(this.mode, this._map);

  final Logger _logger = Logger('LocationModeClass');

  late final PointAnnotationManager _pointAnnotationManager;
  final List<PointAnnotation> _annotations = [];
  ListValueNotifier<Point> pointsNotifier = ListValueNotifier<Point>([]);

  List<PointAnnotation> get pointAnnotations => List.unmodifiable(_annotations);
  List<Point> get selectedPoints => pointsNotifier.value;
  Point? get lastTapped =>
      pointsNotifier.value.isNotEmpty ? pointsNotifier.value.last : null;

  static Future<LocationModeClass> initialize(
      LocationSelectionMode mode, MapboxMap map) async {
    LocationModeClass cls = LocationModeClass(mode, map);
    await cls._initializePointAnnoManager();
    cls._map.setOnMapTapListener(cls._onMapTapCallback);
    await cls._addInitialPointAnnotations();
    return cls;
  }

  void _onMapTapCallback(MapContentGestureContext context) async {
    if (pointAnnotations.length >= mode.maxSelections) {
      await removeOldestAnnotation();
    }
    await addPoint(context.point, zoom: true);
  }

  Future<void> _initializePointAnnoManager() async {
    _pointAnnotationManager =
        await _map.annotations.createPointAnnotationManager(id: 'pam');
  }

  Future<void> _addInitialPointAnnotations() async {
    if (mode.preSelectedLocs != null && mode.preSelectedLocs!.isNotEmpty) {
      for (var pt in mode.preSelectedLocs!.take(mode.maxSelections).toList()) {
        await addPoint(pt);
      }

      // Zoom to the bounding box of pre-selected locations
      if (mode.preSelectedLocs!.isNotEmpty) {
        await zoomToBounds();
      }
    }
  }

  Future<void> addPoint(Point pt, {bool zoom = false, ByteData? asset}) async {
    final anno = await _pointAnnotationManager.create(PointAnnotationOptions(
      geometry: pt,
      image: asset != null ? addImageFromAsset(asset) : MapAssets.selectedLoc,
      iconOffset: [
        0,
        -28 //calculated value. Only compatible with selectedLoc MapAsset. DO NOT MODIFY!
      ],
    ));
    _annotations.add(anno);
    pointsNotifier.add(anno.geometry);
    zoom ? await zoomToBounds() : null;
  }

  Future<void> removeOldestAnnotation() async {
    final anno = _annotations.removeAt(0);
    await _pointAnnotationManager.delete(anno);
    pointsNotifier.remove(anno.geometry);
  }

  Future<void> removePoint(PointAnnotation annotation) async {
    if (_annotations.contains(annotation)) {
      _pointAnnotationManager.delete(annotation);
      _annotations.remove(annotation);
      pointsNotifier.remove(annotation.geometry);
    }
  }
  Future<void> clearAllAnnotations() async {
    await _pointAnnotationManager.deleteAll();
    _annotations.clear();
    pointsNotifier.clear();
  }

  /// Zooms the map camera to fit all selected points within the viewport.
  ///
  /// This method creates a bounding box that encompasses all currently selected points
  /// and adjusts the camera to show this entire area. If there are no points selected,
  /// this method does nothing.
  ///
  /// Parameters:
  /// - [paddingPixels]: Padding around the bounds in screen pixels
  /// - [minZoom]: Minimum zoom level to enforce (prevents zooming out too far)
  /// - [maxZoom]: Maximum zoom level to enforce (prevents zooming in too close)
  /// - [animationDuration]: Duration for the camera animation in milliseconds
  /// - [includeUserLocation]: Whether to include user's current location in bounds calculation
  /// - [preserveCameraBearing]: Whether to preserve the current camera bearing (direction)
  /// - [preserveCameraPitch]: Whether to preserve the current camera pitch (tilt)
  Future<void> zoomToBounds({
    double paddingPixels = 50.0,
    int animationDuration = 1000,
  }) async {
    if (selectedPoints.isEmpty) return;

    // If there's only one point, zoom to that point
    if (selectedPoints.length == 1) {
      await moveMapCamTo(_map, selectedPoints.first);
      return;
    }

    // Calculate the bounds of all points
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    double minLat = double.infinity;
    double maxLat = -double.infinity;

    for (final point in selectedPoints) {
      final lng = point.coordinates.lng as double;
      final lat = point.coordinates.lat as double;

      minLng = lng < minLng ? lng : minLng;
      maxLng = lng > maxLng ? lng : maxLng;
      minLat = lat < minLat ? lat : minLat;
      maxLat = lat > maxLat ? lat : maxLat;
    }

    try {
      // Create camera options with the bounds
      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(
            (minLng + maxLng) / 2,
            (minLat + maxLat) / 2,
          ),
        ),
        zoom: calculateZoomLevel(minLng, minLat, maxLng, maxLat, paddingPixels),
      );
      final camState = await (_map.getCameraState());
      print(camState.zoom);

      // Animate camera to the bounds
      await _map.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: animationDuration),
      );
    } catch (e) {
      _logger.warning("Failed to zoom to bounds: $e");
    }
  }

  /// Calculates an appropriate zoom level to fit the given bounds
  double calculateZoomLevel(
    double minLng,
    double minLat,
    double maxLng,
    double maxLat,
    double padding,
  ) {
    // Simple heuristic for zoom level calculation
    // Higher values = closer zoom
    const double baseZoom = 15.0;
    final double latDiff = (maxLat - minLat).abs();
    final double lngDiff = (maxLng - minLng).abs();

    // The larger the difference, the more we need to zoom out
    final double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    // Logarithmic scale for zoom level
    // This is a simplified approach - for more precise control,
    // you might need to consider the viewport size and aspect ratio
    if (maxDiff < 0.001) return baseZoom; // Very close points
    if (maxDiff < 0.01) return baseZoom - 2;
    if (maxDiff < 0.1) return baseZoom - 4;
    if (maxDiff < 1.0) return baseZoom - 6;

    return baseZoom - 8; // Very distant points
  }

  @override
  Future<void> dispose() async {
    _logger.info("Cleaning Location Mode Data");
    _map.setOnMapTapListener(null);
    await clearAllAnnotations();
    //Remove any existing Point Annotation Managers if exists
    await _map.annotations.removeAnnotationManagerById('pam');
    _logger.info("Location Mode Data Cleared");
  }

  /// Zooms to fit all selected points in the viewport.
  ///
  /// This is a convenience method that can be called by client code
  /// to manually trigger zooming to the bounds of all selected points.
  ///
  /// Example usage:
  /// ```dart
  /// // Access through the MapManager
  /// mapManager.whenLocationMode((locationMode) {
  ///   locationMode.zoomToSelectedPoints();
  /// });
  /// ```
  Future<void> zoomToSelectedPoints() async {
    await zoomToBounds();
  }
}
