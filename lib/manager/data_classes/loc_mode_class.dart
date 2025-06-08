import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:map_manager_mapbox/map_manager_mapbox.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class LocationModeClass {
  final LocationSelectionMode mode;
  LocationModeClass(this.mode);

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
    LocationModeClass cls = LocationModeClass(mode);
    await cls._initializePointAnnoManager(map);
    map.setOnMapTapListener((context) => cls._onMapTapCallback(context, map));
    cls._addInitialPointAnnotations();
    return cls;
  }

  void _onMapTapCallback(
      MapContentGestureContext context, MapboxMap map) async {
    if (pointAnnotations.length >= mode.maxSelections) {
      await removeOldestAnnotation(map);
    }
    await addPoint(context.point);
    await moveMapCamTo(map, pointAnnotations.last.geometry);
  }

  Future<void> _initializePointAnnoManager(MapboxMap map) async {
    _pointAnnotationManager =
        await map.annotations.createPointAnnotationManager(id: 'pam');
  }

  void _addInitialPointAnnotations() async {
    if (mode.preSelectedLocs != null && mode.preSelectedLocs!.isNotEmpty) {
      for (var pt in mode.preSelectedLocs!.take(mode.maxSelections).toList()) {
        await addPoint(pt);
      }
    }
  }

  Future<void> addPoint(Point pt, {ByteData? asset}) async {
    final anno = await _pointAnnotationManager.create(PointAnnotationOptions(
      geometry: pt,
      image: asset != null ? addImageFromAsset(asset) : null,
      iconOffset: [
        0,
        -28 //calculated value. Only compatible with selectedLoc MapAsset. DO NOT MODIFY!
      ],
    ));
    _annotations.add(anno);
    pointsNotifier.add(anno.geometry);
  }

  Future<void> removeOldestAnnotation(MapboxMap map) async {
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

  Future<void> clearAllAnnotations(MapboxMap map) async {
    await _pointAnnotationManager.deleteAll();
    _annotations.clear();
    pointsNotifier.clear();
  }

  Future<void> cleanLocModeData(MapboxMap map) async {
    _logger.info("Cleaning Location Mode Data");
    map.setOnMapTapListener(null);
    await clearAllAnnotations(map);
    //Remove any existing Point Annotation Managers if exists
    await map.annotations.removeAnnotationManagerById('pam');
    _logger.info("Location Mode Data Cleared");
  }
}
