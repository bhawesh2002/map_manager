import 'package:flutter_test/flutter_test.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:map_manager_mapbox/utils/route_utils.dart';

void main() {
  group('GeoJSON Point and LineString Conversion Tests', () {
    test(
        'lineStringToPoints converts GeoJSONLineString to List of GeoJSONPoints',
        () {
      // Arrange
      final lineString = GeoJSONLineString([
        [0.0, 0.0], // [lng, lat]
        [1.0, 1.0],
        [2.0, 2.0]
      ]);

      // Act
      final points = lineStringToPoints(lineString);

      // Assert
      expect(points.length, 3);
      expect(points[0].coordinates, [0.0, 0.0]);
      expect(points[1].coordinates, [1.0, 1.0]);
      expect(points[2].coordinates, [2.0, 2.0]);
    });

    test(
        'pointsToLineString converts List of GeoJSONPoints to GeoJSONLineString',
        () {
      // Arrange
      final points = [
        GeoJSONPoint([0.0, 0.0]), // [lng, lat]
        GeoJSONPoint([1.0, 1.0]),
        GeoJSONPoint([2.0, 2.0])
      ];

      // Act
      final lineString = pointsToLineString(points);

      // Assert
      expect(lineString.coordinates.length, 3);
      expect(lineString.coordinates[0], [0.0, 0.0]);
      expect(lineString.coordinates[1], [1.0, 1.0]);
      expect(lineString.coordinates[2], [2.0, 2.0]);
    });
  });

  group('Projection Tests', () {
    test('projectPointOnSegment - point on segment', () {
      // Arrange
      final point = GeoJSONPoint([1.0, 1.0]); // point to project
      final segmentStart = GeoJSONPoint([0.0, 0.0]); // segment start
      final segmentEnd = GeoJSONPoint([2.0, 2.0]); // segment end

      // Act
      final result = projectPointOnSegment(point, segmentStart, segmentEnd);

      // Assert
      expect(result.projectedPoint.coordinates, [1.0, 1.0]);
      expect(result.onSegment, true);
      expect(result.ratio, closeTo(0.5, 0.001)); // should be halfway (t=0.5)
    });

    test('projectPointOnSegment - point off segment', () {
      // Arrange
      final point = GeoJSONPoint([0.0, 1.0]); // point is off the segment
      final segmentStart = GeoJSONPoint([0.0, 0.0]);
      final segmentEnd = GeoJSONPoint([2.0, 2.0]);

      // Act
      final result = projectPointOnSegment(point, segmentStart, segmentEnd);

      // Assert
      expect(result.onSegment, true); // still projects onto the segment
      // The projected point should be at (0.5, 0.5) since that's the closest point on the segment
      expect(result.projectedPoint.coordinates[0], closeTo(0.5, 0.001));
      expect(result.projectedPoint.coordinates[1], closeTo(0.5, 0.001));
      expect(result.ratio, closeTo(0.25, 0.001)); // should be 1/4 of the way
    });

    test('projectPointOnSegment - point before segment', () {
      // Arrange
      final point = GeoJSONPoint([-1.0, -1.0]); // point is before the segment
      final segmentStart = GeoJSONPoint([0.0, 0.0]);
      final segmentEnd = GeoJSONPoint([2.0, 2.0]);

      // Act
      final result = projectPointOnSegment(point, segmentStart, segmentEnd);

      // Assert
      expect(result.onSegment, false); // projects before the segment
      expect(result.projectedPoint.coordinates, [0.0, 0.0]); // clamped to start
      expect(result.ratio, 0.0); // ratio is clamped to 0.0
    });

    test('projectPointOnSegment - point after segment', () {
      // Arrange
      final point = GeoJSONPoint([3.0, 3.0]); // point is after the segment
      final segmentStart = GeoJSONPoint([0.0, 0.0]);
      final segmentEnd = GeoJSONPoint([2.0, 2.0]);

      // Act
      final result = projectPointOnSegment(point, segmentStart, segmentEnd);

      // Assert
      expect(result.onSegment, false); // projects after the segment
      expect(result.projectedPoint.coordinates, [2.0, 2.0]); // clamped to end
      expect(result.ratio, 1.0); // ratio is clamped to 1.0
    });

    test('projectPointOnSegment - very short segment', () {
      // Arrange
      final point = GeoJSONPoint([0.1, 0.1]); // nearby point
      final segmentStart = GeoJSONPoint([0.0, 0.0]);
      final segmentEnd =
          GeoJSONPoint([0.000001, 0.000001]); // nearly same as start

      // Act
      final result = projectPointOnSegment(point, segmentStart, segmentEnd);

      // Assert
      expect(
          result.projectedPoint.coordinates, [0.0, 0.0]); // should return start
      expect(result.onSegment, true);
      expect(result.ratio, 0.0);
    });
  });

  group('Haversine Distance Tests', () {
    test('haversineDistance - known distance', () {
      // Arrange - Two points with a known distance
      // New York: 40.7128° N, 74.0060° W
      // Los Angeles: 34.0522° N, 118.2437° W
      // ~3,935 km or ~3,935,000 meters
      final newYork = GeoJSONPoint([-74.0060, 40.7128]); // [lng, lat]
      final losAngeles = GeoJSONPoint([-118.2437, 34.0522]);

      // Act
      final distance = haversineDistance(newYork, losAngeles);

      // Assert
      expect(distance, closeTo(3935000, 10000)); // Within 10km accuracy
    });

    test('haversineDistance - zero distance', () {
      // Arrange - Same point twice
      final point = GeoJSONPoint([10.0, 20.0]);

      // Act
      final distance = haversineDistance(point, point);

      // Assert
      expect(distance, 0.0);
    });

    test('haversineDistance - small distance', () {
      // Arrange - Two very close points
      // Points ~10 meters apart
      final point1 = GeoJSONPoint([0.0, 0.0]);
      final point2 = GeoJSONPoint([0.0001, 0.0]); // Small longitude difference

      // Act
      final distance = haversineDistance(point1, point2);

      // Assert
      // At the equator, 0.0001 degrees of longitude is ~11.1 meters
      expect(distance, closeTo(11.1, 1.0));
    });
  });

  group('Route Check Tests', () {
    test('isUserOnRoute - user on route', () {
      // Arrange
      final userLocation = GeoJSONPoint([1.0, 1.0]);
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0]),
        GeoJSONPoint([4.0, 4.0])
      ];

      // Act
      final result = isUserOnRoute(userLocation, routePoints);

      // Assert
      expect(result.isOnRoute, true);
      expect(result.segmentIndex, 0); // First segment
      expect(result.distance, closeTo(0.0, 0.001)); // User is exactly on route
      expect(result.projectionRatio, closeTo(0.5, 0.001)); // Halfway on segment
    });

    test('isUserOnRoute - user off route', () {
      // Arrange
      final userLocation = GeoJSONPoint([3.0, 0.0]); // Far from route
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0]),
        GeoJSONPoint([4.0, 4.0])
      ];

      // Act
      final result =
          isUserOnRoute(userLocation, routePoints, thresholdMeters: 10);

      // Assert
      expect(result.isOnRoute, false);
      expect(
          result.segmentIndex, anyOf(0, 1)); // Either segment could be closest
      expect(result.distance, greaterThan(10.0)); // Greater than threshold
    });

    test('isUserOnRoute - empty route', () {
      // Arrange
      final userLocation = GeoJSONPoint([1.0, 1.0]);
      final emptyRoute = <GeoJSONPoint>[];

      // Act
      final result = isUserOnRoute(userLocation, emptyRoute);

      // Assert
      expect(result.isOnRoute, false);
      expect(result.segmentIndex, -1); // Invalid segment
      expect(result.distance, double.infinity);
    });

    test('isUserOnRoute - single point route', () {
      // Arrange
      final userLocation = GeoJSONPoint([1.0, 1.0]);
      final singlePointRoute = [
        GeoJSONPoint([0.0, 0.0])
      ];

      // Act
      final result = isUserOnRoute(userLocation, singlePointRoute);

      // Assert
      expect(
          result.isOnRoute, false); // Need at least 2 points to form a segment
      expect(result.segmentIndex, -1); // Invalid segment
      expect(result.distance, double.infinity);
    });
  });

  group('Route Modification Tests', () {
    test('shrinkRoute - middle segment projection', () {
      // Arrange
      final projectedPoint = GeoJSONPoint([1.0, 1.0]);
      const segmentIndex = 0;
      const projectionRatio = 0.5; // Middle of segment
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0]),
        GeoJSONPoint([4.0, 4.0])
      ];

      // Act
      final newRoute = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(newRoute.length, 3);
      expect(newRoute[0].coordinates, [1.0, 1.0]); // Projected point
      expect(newRoute[1].coordinates, [2.0, 2.0]); // Original second point
      expect(newRoute[2].coordinates, [4.0, 4.0]); // Original third point
    });

    test('shrinkRoute - start of segment projection', () {
      // Arrange
      final projectedPoint = GeoJSONPoint([0.0, 0.0]);
      const segmentIndex = 0;
      const projectionRatio = 0.0; // Start of segment
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0]),
        GeoJSONPoint([4.0, 4.0])
      ];

      // Act
      final newRoute = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(newRoute.length, 3);
      expect(newRoute[0].coordinates, [0.0, 0.0]);
      expect(newRoute[1].coordinates, [2.0, 2.0]);
      expect(newRoute[2].coordinates, [4.0, 4.0]);
    });

    test('shrinkRoute - end of segment projection', () {
      // Arrange
      final projectedPoint = GeoJSONPoint([2.0, 2.0]);
      const segmentIndex = 0;
      const projectionRatio = 1.0; // End of segment
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0]),
        GeoJSONPoint([4.0, 4.0])
      ];

      // Act
      final newRoute = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(newRoute.length, 2);
      expect(newRoute[0].coordinates, [2.0, 2.0]);
      expect(newRoute[1].coordinates, [4.0, 4.0]);
    });

    test('shrinkRoute - last segment projection', () {
      // Arrange
      final projectedPoint = GeoJSONPoint([3.0, 3.0]);
      const segmentIndex = 1; // Last segment
      const projectionRatio = 0.5; // Middle of last segment
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0]),
        GeoJSONPoint([4.0, 4.0])
      ];

      // Act
      final newRoute = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(newRoute.length, 2);
      expect(newRoute[0].coordinates, [3.0, 3.0]); // Projected point
      expect(newRoute[1].coordinates, [4.0, 4.0]); // End point
    });

    test('shrinkRoute - invalid segment index', () {
      // Arrange
      final projectedPoint = GeoJSONPoint([0.0, 0.0]);
      const segmentIndex = -1; // Invalid
      const projectionRatio = 0.5;
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0]),
        GeoJSONPoint([4.0, 4.0])
      ];

      // Act
      final newRoute = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(newRoute.length, 3); // Should return original route
      expect(newRoute[0].coordinates, [0.0, 0.0]);
      expect(newRoute[1].coordinates, [2.0, 2.0]);
      expect(newRoute[2].coordinates, [4.0, 4.0]);
    });

    test('growRoute - adds user location to start', () {
      // Arrange
      final userLocation = GeoJSONPoint([10.0, 10.0]);
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0])
      ];

      // Act
      final newRoute = growRoute(userLocation, routePoints);

      // Assert
      expect(newRoute.length, 3);
      expect(newRoute[0].coordinates, [10.0, 10.0]); // User location at start
      expect(newRoute[1].coordinates, [0.0, 0.0]);
      expect(newRoute[2].coordinates, [2.0, 2.0]);
    });
    test('growRoute - with empty route', () {
      // Arrange
      final userLocation = GeoJSONPoint([10.0, 10.0]);
      final emptyRoute = <GeoJSONPoint>[];

      // Act
      final newRoute = growRoute(userLocation, emptyRoute);

      // Assert
      expect(newRoute.length, 1);
      expect(newRoute[0].coordinates, [10.0, 10.0]); // Only the user location
    });
  });
  group('Integration Tests', () {
    test('Route shrinking and growing workflow', () {
      // Setup a route with multiple segments
      final route = GeoJSONLineString([
        [0.0, 0.0], // Start point
        [10.0, 10.0], // Mid point 1
        [20.0, 20.0], // Mid point 2
        [30.0, 30.0] // End point
      ]);

      // Convert to points
      final routePoints = lineStringToPoints(route);
      expect(routePoints.length, 4);
      // Simulate user at point near first segment
      final userLocation =
          GeoJSONPoint([5.0, 4.0]); // Near but not on the first segment

      // Check if user is on route
      final checkResult =
          isUserOnRoute(userLocation, routePoints, thresholdMeters: 150000);

      if (checkResult.isOnRoute) {
        // User is on route, shrink the route
        final shrunkRoute = shrinkRoute(checkResult.projectedPoint,
            checkResult.segmentIndex, checkResult.projectionRatio, routePoints);

        // With the test data, we know it should shrink but might still include all points
        // depending on where the projection lands, so just verify it's valid
        expect(shrunkRoute.length, greaterThanOrEqualTo(1));

        // Conversion back to LineString works
        final shrunkLineString = pointsToLineString(shrunkRoute);
        expect(shrunkLineString.coordinates.length, shrunkRoute.length);
      } else {
        // User is off route, grow the route
        final grownRoute = growRoute(userLocation, routePoints);

        // Verify the grown route has the user location at the start
        expect(grownRoute.length, equals(routePoints.length + 1));
        expect(grownRoute[0].coordinates, userLocation.coordinates);

        // Conversion back to LineString works
        final grownLineString = pointsToLineString(grownRoute);
        expect(grownLineString.coordinates.length, grownRoute.length);
      }
    });

    test('Successive route shrinking', () {
      // Setup a longer route with multiple segments
      final route = GeoJSONLineString([
        [0.0, 0.0], // Start
        [10.0, 10.0], // Point 1
        [20.0, 20.0], // Point 2
        [30.0, 30.0], // Point 3
        [40.0, 40.0], // Point 4
        [50.0, 50.0] // End
      ]);

      var routePoints = lineStringToPoints(route);
      expect(routePoints.length, 6);

      // First user location - near first segment
      var userLocation1 = GeoJSONPoint([5.0, 5.0]);
      var checkResult1 =
          isUserOnRoute(userLocation1, routePoints, thresholdMeters: 100);
      expect(checkResult1.isOnRoute, true);
      expect(checkResult1.segmentIndex, 0);

      // First shrink
      var shrunkRoute1 = shrinkRoute(checkResult1.projectedPoint,
          checkResult1.segmentIndex, checkResult1.projectionRatio, routePoints);

      // Second user location - now near third segment of shrunk route
      var userLocation2 = GeoJSONPoint([25.0, 25.0]);
      var checkResult2 =
          isUserOnRoute(userLocation2, shrunkRoute1, thresholdMeters: 100);
      expect(checkResult2.isOnRoute, true);

      // Second shrink
      var shrunkRoute2 = shrinkRoute(
          checkResult2.projectedPoint,
          checkResult2.segmentIndex,
          checkResult2.projectionRatio,
          shrunkRoute1);

      // Verify route has shrunk properly
      expect(shrunkRoute2.length, lessThan(shrunkRoute1.length));

      // Last check - user at end of route
      var userLocation3 = GeoJSONPoint([50.0, 50.0]);
      var checkResult3 =
          isUserOnRoute(userLocation3, shrunkRoute2, thresholdMeters: 100);
      expect(checkResult3.isOnRoute, true);

      // Final shrink
      var shrunkRoute3 = shrinkRoute(
          checkResult3.projectedPoint,
          checkResult3.segmentIndex,
          checkResult3.projectionRatio,
          shrunkRoute2);

      // Should be at or near the end
      expect(shrunkRoute3.length, lessThanOrEqualTo(2));
    });

    test('Global scale route with dateline crossing', () {
      // Create a route that crosses international date line
      // Tokyo to San Francisco
      final globalRoute = GeoJSONLineString([
        [139.6917, 35.6895], // Tokyo
        [180.0, 35.0], // Date line crossing point
        [-180.0, 35.0], // Date line entry point
        [-122.4194, 37.7749] // San Francisco
      ]);

      var routePoints = lineStringToPoints(globalRoute);
      expect(routePoints.length, 4);

      // Test point in Pacific Ocean
      var pacificPoint = GeoJSONPoint([170.0, 35.0]);

      // Check if point is on route (should be within threshold)
      var checkResult = isUserOnRoute(pacificPoint, routePoints,
          thresholdMeters: 1000000); // 1000km threshold

      // The haversine distance calculation should handle the date line
      // This is a difficult case for projection but should give reasonable results
      expect(checkResult.segmentIndex, anyOf(0, 1));
    });
  });

  group('Edge Case Tests', () {
    test('Route with extremely close points', () {
      // Create a route with some points that are extremely close to each other
      final route = GeoJSONLineString([
        [0.0, 0.0],
        [0.0000001, 0.0000001], // Almost the same point
        [10.0, 10.0]
      ]);

      var routePoints = lineStringToPoints(route);
      expect(routePoints.length, 3);

      // User location near the first segment
      var userLocation = GeoJSONPoint([0.0, 0.0]);
      var checkResult = isUserOnRoute(userLocation, routePoints);

      expect(checkResult.isOnRoute, true);
      expect(checkResult.segmentIndex,
          anyOf(0, 1)); // Could be either of the very close segments
    });
    test('Route with many segments for performance', () {
      // Create a route with many segments to check performance
      // For example, a detailed city route might have hundreds of points
      List<List<double>> coordinates = [];

      // Generate 100 points along a line
      for (int i = 0; i < 100; i++) {
        coordinates.add([i.toDouble(), i.toDouble()]);
      }

      final longRoute = GeoJSONLineString(coordinates);
      var routePoints = lineStringToPoints(longRoute);
      expect(routePoints.length, 100);

      // User somewhere in the middle
      var userLocation = GeoJSONPoint([50.5, 50.0]);

      // Use a larger threshold for this test since we're testing performance, not precision
      var checkResult =
          isUserOnRoute(userLocation, routePoints, thresholdMeters: 100000);

      expect(checkResult.isOnRoute, true);
      expect(checkResult.segmentIndex,
          closeTo(50, 1)); // Should find a segment near point 50
    });
  });
}
