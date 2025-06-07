import 'package:logging/logging.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../utils/list_value_notifier.dart';
import '../map_mode.dart';

class LocationModeClass {
  final LocationSelectionMode _locationSelectionMode;
  LocationModeClass(this._locationSelectionMode);

  final Logger _logger = Logger('LocationModeClass');

  PointAnnotationManager? _pointAnnotationManager;
  final List<PointAnnotation> _annotations = [];
  ListValueNotifier pointsNotifier = ListValueNotifier<Point>([]);
  Point? _lastTapped;

  List<PointAnnotation> get pointAnnotations => List.unmodifiable(_annotations);
  Point? get lastTapped => _lastTapped;

  static Future<LocationModeClass> initialize(
      LocationSelectionMode mode, MapboxMap map) async {
    LocationModeClass cls = LocationModeClass(mode);
    await cls.initializePointAnnoManager(map);
    map.setOnMapTapListener((context) => cls._onMapTapCallback(context, map));
    if (mode.preSelectedLocs != null && mode.preSelectedLocs!.isNotEmpty) {
      await cls.addInitialPointAnnotations(
          mode.preSelectedLocs!, mode.maxSelections);
      await cls.moveCamTo(cls.pointAnnotations.last.geometry, map);
    }
    return cls;
  }

  void _onMapTapCallback(
      MapContentGestureContext context, MapboxMap map) async {
    if (pointAnnotations.length >= _locationSelectionMode.maxSelections) {
      await removeOldestAnnotation(map);
    }
    _lastTapped = context.point;
    await addPointAtLastKnown();
    await moveCamTo(pointAnnotations.last.geometry, map);
  }

  Future<void> initializePointAnnoManager(MapboxMap map) async {
    //Remove any existing Point Annotation Managers if exists
    map.annotations.removeAnnotationManagerById('pam');
    pointsNotifier.clear();
    _pointAnnotationManager ??=
        await map.annotations.createPointAnnotationManager(id: 'pam');

    _logger.info("Point Anno Manager initialized");
  }

  Future<void> removeOldestAnnotation(MapboxMap map) async {
    final anno = _annotations.removeAt(0);
    await _pointAnnotationManager?.delete(anno);
    pointsNotifier.remove(anno.geometry);
  }

  PointAnnotationOptions _getDefPointAnno(Point geometry) {
    return PointAnnotationOptions(
      geometry: geometry,
      image: MapAssets.selectedLoc,
      iconOffset: [
        0,
        -28 //calculated value. Only compatible with selectedLoc MapAsset. DO NOT MODIFY!
      ],
    );
  }

  Future<void> addPointAtLastKnown() async {
    if (_lastTapped != null) {
      final anno =
          await _pointAnnotationManager!.create(_getDefPointAnno(_lastTapped!));
      _annotations.add(anno);

      pointsNotifier.add(anno.geometry);
    }
  }

  Future<void> addPoint(Point pt) async {
    final anno = await _pointAnnotationManager!.create(_getDefPointAnno(pt));
    _annotations.add(anno);
    pointsNotifier.add(anno.geometry);
  }

  Future<void> removePoint(PointAnnotation annotation) async {
    _pointAnnotationManager!.delete(annotation);
    pointsNotifier.add(annotation.geometry);
  }

  Future<void> addInitialPointAnnotations(List<Point> pts, int maxPts) async {
    pts = pts.take(maxPts).toList();
    for (var pt in pts) {
      await addPoint(pt);
    }
  }

  Future<void> moveCamTo(Point point, MapboxMap map, {int? duration}) async {
    await map.flyTo(CameraOptions(center: point, zoom: 16, pitch: 50),
        MapAnimationOptions(duration: duration ?? 500));
  }

  Future<void> clearAllAnnotations(MapboxMap map) async {
    await _pointAnnotationManager?.deleteAll();
    _annotations.clear();
    pointsNotifier.clear();
    _lastTapped = null;
  }

  Future<void> cleanLocModeDat(MapboxMap map) async {
    _logger.info("Cleaning Location Mode Data");
    _lastTapped = null;
    await clearAllAnnotations(map);
    map.setOnMapLongTapListener(null);
    _pointAnnotationManager = null;
    _logger.info("Location Mode Data Cleared");
  }
}
