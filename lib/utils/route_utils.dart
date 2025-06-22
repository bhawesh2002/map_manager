import 'dart:math' as math;
import 'package:geojson_vi/geojson_vi.dart';

/// Represents the result of projecting a point onto a route segment.
class ProjectionResult {
  /// The projected point on the segment
  final GeoJSONPoint projectedPoint;

  /// Whether the projected point falls on the segment (t between 0 and 1)
  final bool onSegment;

  /// The ratio along the segment (0 = start, 1 = end)
  final double ratio;

  ProjectionResult({
    required this.projectedPoint,
    required this.onSegment,
    required this.ratio,
  });
}

/// Represents the result of checking if a user's location is on a route.
class RouteCheckResult {
  /// Whether the user is on the route (within threshold distance)
  final bool isOnRoute;

  /// The distance from the user to the nearest point on the route (in meters)
  final double distance;

  /// The projected point on the route
  final GeoJSONPoint projectedPoint;

  /// The index of the segment in the route where the projection was found
  final int segmentIndex;

  /// The ratio along the segment (0 = start, 1 = end)
  final double projectionRatio;

  RouteCheckResult({
    required this.isOnRoute,
    required this.distance,
    required this.projectedPoint,
    required this.segmentIndex,
    this.projectionRatio = 0.0,
  });
}

/// Converts a GeoJSONLineString to a List of GeoJSONPoints.
///
/// Useful for converting a GeoJSON LineString to a list of points for projection.
///
/// Parameters:
/// - [lineString]: The GeoJSONLineString to convert
///
/// Returns a list of GeoJSONPoint objects.
List<GeoJSONPoint> lineStringToPoints(GeoJSONLineString lineString) {
  List<GeoJSONPoint> points = [];
  for (var coord in lineString.coordinates) {
    // Create GeoJSONPoint objects from LineString coordinates
    points.add(GeoJSONPoint(coord));
  }
  return points;
}

/// Converts a List of GeoJSONPoints to a GeoJSONLineString.
///
/// Useful for converting a modified list of points back to a GeoJSON LineString.
///
/// Parameters:
/// - [points]: The list of points to convert
///
/// Returns a GeoJSONLineString object.
GeoJSONLineString pointsToLineString(List<GeoJSONPoint> points) {
  List<List<double>> coordinates = [];
  for (GeoJSONPoint point in points) {
    coordinates.add(point.coordinates);
  }
  return GeoJSONLineString(coordinates);
}

/// Projects a point onto a line segment defined by two points.
///
/// Uses vector math to calculate the projection.
///
/// Parameters:
/// - [point]: The point to project
/// - [segmentStart]: The start point of the line segment
/// - [segmentEnd]: The end point of the line segment
///
/// Returns a [ProjectionResult] containing the projected point and metadata.
ProjectionResult projectPointOnSegment(
    GeoJSONPoint point, GeoJSONPoint segmentStart, GeoJSONPoint segmentEnd) {
  // Create segment vector
  double segmentX = segmentEnd.coordinates[0] - segmentStart.coordinates[0];
  double segmentY = segmentEnd.coordinates[1] - segmentStart.coordinates[1];

  // Create vector from segment start to point
  double pointX = point.coordinates[0] - segmentStart.coordinates[0];
  double pointY = point.coordinates[1] - segmentStart.coordinates[1];

  // Calculate dot product
  double dotProduct = pointX * segmentX + pointY * segmentY;

  // Calculate segment length squared
  double segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;

  // If segment is too short, return the start point
  if (segmentLengthSquared < 1e-10) {
    return ProjectionResult(
        projectedPoint: segmentStart, onSegment: true, ratio: 0.0);
  }

  // Calculate projection ratio (t)
  double t = dotProduct / segmentLengthSquared;

  // Constrain t to segment bounds [0,1]
  double clampedT = (t < 0) ? 0 : ((t > 1) ? 1 : t);

  // Determine if projection falls on segment
  bool onSegment = (t >= 0 && t <= 1);

  // Calculate projected point
  GeoJSONPoint projectedPoint = GeoJSONPoint([
    segmentStart.coordinates[0] + clampedT * segmentX,
    segmentStart.coordinates[1] + clampedT * segmentY
  ]);

  return ProjectionResult(
      projectedPoint: projectedPoint, onSegment: onSegment, ratio: clampedT);
}

/// Calculates the distance between two points using the Haversine formula.
///
/// This accounts for the Earth's curvature to give accurate distances in meters.
///
/// Parameters:
/// - [point1]: First point
/// - [point2]: Second point
///
/// Returns the distance in meters.
double haversineDistance(GeoJSONPoint point1, GeoJSONPoint point2) {
  const double kEarthRadius = 6371000; // meters

  // Convert degrees to radians
  double lat1Rad = point1.coordinates[1] * (math.pi / 180);
  double lng1Rad = point1.coordinates[0] * (math.pi / 180);
  double lat2Rad = point2.coordinates[1] * (math.pi / 180);
  double lng2Rad = point2.coordinates[0] * (math.pi / 180);

  // Haversine formula
  double dLat = lat2Rad - lat1Rad;
  double dLng = lng2Rad - lng1Rad;

  double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1Rad) *
          math.cos(lat2Rad) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);

  double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return kEarthRadius * c;
}

/// Checks if a user's location is on a route within a threshold distance.
///
/// Parameters:
/// - [userLocation]: The user's current location
/// - [routePoints]: List of points defining the route
/// - [thresholdMeters]: Distance threshold in meters (default: 15.0)
///
/// Returns a [RouteCheckResult] with the outcome and detailed information.
RouteCheckResult isUserOnRoute(
    GeoJSONPoint userLocation, List<GeoJSONPoint> routePoints,
    {double thresholdMeters = 15.0}) {
  // Handle edge cases
  if (routePoints.length < 2) {
    return RouteCheckResult(
        isOnRoute: false,
        distance: double.infinity,
        projectedPoint: userLocation,
        segmentIndex: -1);
  }

  // Check each segment
  for (int i = 0; i < routePoints.length - 1; i++) {
    // Get projection of user location onto this segment
    ProjectionResult projection =
        projectPointOnSegment(userLocation, routePoints[i], routePoints[i + 1]);

    // Calculate distance using Haversine formula
    double distance =
        haversineDistance(userLocation, projection.projectedPoint);

    // Early return if user is on route
    if (distance <= thresholdMeters) {
      return RouteCheckResult(
          isOnRoute: true,
          projectedPoint: projection.projectedPoint,
          segmentIndex: i,
          distance: distance,
          projectionRatio: projection.ratio);
    }
  }

  // If we get here, user is not on any segment within threshold
  // Find nearest point for reference (useful for growing the route later)
  double minDistance = double.infinity;
  GeoJSONPoint closestPoint = userLocation;
  int closestSegmentIndex = -1;
  double closestRatio = 0.0;

  for (int i = 0; i < routePoints.length - 1; i++) {
    ProjectionResult projection =
        projectPointOnSegment(userLocation, routePoints[i], routePoints[i + 1]);

    double distance =
        haversineDistance(userLocation, projection.projectedPoint);

    if (distance < minDistance) {
      minDistance = distance;
      closestPoint = projection.projectedPoint;
      closestSegmentIndex = i;
      closestRatio = projection.ratio;
    }
  }

  return RouteCheckResult(
      isOnRoute: false,
      projectedPoint: closestPoint,
      segmentIndex: closestSegmentIndex,
      distance: minDistance,
      projectionRatio: closestRatio);
}

/// Modifies a route by shrinking it based on the user's projected position.
///
/// Creates a new route starting from the projected point and including all
/// subsequent points in the original route. Takes into account the projection
/// ratio to handle the current segment properly.
///
/// Parameters:
/// - [projectedPoint]: The user's projected point on the route
/// - [segmentIndex]: The index of the segment where the projection was found
/// - [projectionRatio]: How far along the segment the projection is (0.0 to 1.0)
/// - [routePoints]: The original route points
///
/// Returns a new list of route points.
List<GeoJSONPoint> shrinkRoute(GeoJSONPoint projectedPoint, int segmentIndex,
    double projectionRatio, List<GeoJSONPoint> routePoints) {
  if (routePoints.length < 2 ||
      segmentIndex < 0 ||
      segmentIndex >= routePoints.length - 1) {
    return List.from(routePoints);
  }

  List<GeoJSONPoint> newRoute = [];

  // Handle the first segment specially
  if (segmentIndex == 0) {
    // If we're at the very start of the first segment, return the whole route
    if (projectionRatio <= 0.01) {
      return List.from(routePoints);
    }
  }

  // Case 1: Projection at start of segment (within small threshold)
  if (projectionRatio <= 0.01 && segmentIndex > 0) {
    // Include the start point of the segment
    newRoute.add(routePoints[segmentIndex]);
    newRoute.addAll(routePoints.sublist(segmentIndex + 1));
  }
  // Case 2: Projection at end of segment (within small threshold)
  else if (projectionRatio >= 0.99) {
    // Skip this segment entirely, start from the next point

    // Handle the last segment specially
    if (segmentIndex == routePoints.length - 2) {
      // If we're at the end of the last segment, return an empty route
      // or just the destination point if needed
      newRoute.add(routePoints.last);
    } else {
      // Normal case - start from the end point of the current segment
      newRoute.addAll(routePoints.sublist(segmentIndex + 1));
    }
  }
  // Case 3: Projection in middle of segment
  else {
    // Create new segment from projected point to end of current segment
    newRoute.add(projectedPoint);
    newRoute.addAll(routePoints.sublist(segmentIndex + 1));
  }

  return newRoute;
}

/// Modifies a route by growing it to include the user's current off-route position.
///
/// Simply adds the user's location to the start of the route.
///
/// Parameters:
/// - [userLocation]: The user's current location
/// - [routePoints]: The original route points
///
/// Returns a new list of route points.
List<GeoJSONPoint> growRoute(
    GeoJSONPoint userLocation, List<GeoJSONPoint> routePoints) {
  List<GeoJSONPoint> newRoute = [userLocation];
  newRoute.addAll(routePoints);
  return newRoute;
}
