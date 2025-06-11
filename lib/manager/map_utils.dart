import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:logging/logging.dart';

Future<void> moveMapCamTo(MapboxMap map, Point point, {int? duration}) async {
  await map.flyTo(CameraOptions(center: point, zoom: 16, pitch: 50),
      MapAnimationOptions(duration: duration ?? 500));
}

Future<void> moveMapBy(MapboxMap map, double x, double y) async {
  await map.moveBy(
      ScreenCoordinate(x: x, y: y), MapAnimationOptions(duration: 1));
}

/// Zooms the map camera to fit all provided points within the viewport.
///
/// This utility function creates a bounding box that encompasses all provided points
/// and adjusts the camera to show this entire area. If no points are provided or
/// the list is empty, this function does nothing.
///
/// Parameters:
/// - [map]: The MapboxMap instance to control
/// - [points]: List of points to fit within the viewport
/// - [paddingPixels]: Optional padding around the bounds in screen pixels
/// - [animationDuration]: Optional duration for the camera animation in milliseconds
/// - [singlePointZoom]: Zoom level to use when only one point is provided
/// - [logger]: Optional logger for error reporting
///
/// Example usage:
/// ```dart
/// await zoomToFitPoints(
///   mapboxMap,
///   selectedPoints,
///   paddingPixels: 100.0,
///   animationDuration: 1500,
/// );
/// ```
Future<void> zoomToFitPoints(
  MapboxMap map,
  List<Point> points, {
  double paddingPixels = 50.0,
  int animationDuration = 1000,
  double singlePointZoom = 16.0,
  Logger? logger,
}) async {
  if (points.isEmpty) return;

  // If there's only one point, zoom to that point
  if (points.length == 1) {
    await moveMapCamTo(map, points.first);
    return;
  }

  // Calculate the bounds of all points
  double minLng = double.infinity;
  double maxLng = -double.infinity;
  double minLat = double.infinity;
  double maxLat = -double.infinity;

  for (final point in points) {
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
      zoom: calculateOptimalZoomLevel(minLng, minLat, maxLng, maxLat),
    );

    // Animate camera to the bounds
    await map.flyTo(
      cameraOptions,
      MapAnimationOptions(duration: animationDuration),
    );
  } catch (e) {
    logger?.warning("Failed to zoom to bounds: $e");
  }
}

/// Calculates an appropriate zoom level to fit the given coordinate bounds.
///
/// This function analyzes the span between coordinates and returns an optimal
/// zoom level for map viewing.
///
/// Parameters:
/// - [minLng]: Minimum longitude of the bounds
/// - [minLat]: Minimum latitude of the bounds
/// - [maxLng]: Maximum longitude of the bounds
/// - [maxLat]: Maximum latitude of the bounds
///
/// Returns: A zoom level between 8.0 and 18.0
double calculateOptimalZoomLevel(
  double minLng,
  double minLat,
  double maxLng,
  double maxLat,
) {
  // Calculate the span of coordinates
  final double latDiff = (maxLat - minLat).abs();
  final double lngDiff = (maxLng - minLng).abs();

  // Use the larger span to determine zoom level
  final double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

  // More refined zoom level calculation for better visual results
  // These values are empirically determined for good map viewing
  if (maxDiff < 0.0001) return 18.0; // Very close points (within ~10 meters)
  if (maxDiff < 0.0005) return 17.0; // Close points (within ~50 meters)
  if (maxDiff < 0.001) return 16.0;  // Nearby points (within ~100 meters)
  if (maxDiff < 0.005) return 15.0;  // Local area (within ~500 meters)
  if (maxDiff < 0.01) return 14.0;   // Neighborhood (within ~1 km)
  if (maxDiff < 0.05) return 13.0;   // District (within ~5 km)
  if (maxDiff < 0.1) return 12.0;    // City area (within ~10 km)
  if (maxDiff < 0.5) return 11.0;    // Metropolitan area
  if (maxDiff < 1.0) return 10.0;    // Large city/region
  if (maxDiff < 5.0) return 9.0;     // State/province level

  return 8.0; // Country/continent level
}
