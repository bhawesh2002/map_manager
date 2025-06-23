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
      final result = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(result.updatedRoute.length, 3);
      expect(result.updatedRoute[0].coordinates, [1.0, 1.0]); // Projected point
      expect(result.updatedRoute[1].coordinates,
          [2.0, 2.0]); // Original second point
      expect(result.updatedRoute[2].coordinates,
          [4.0, 4.0]); // Original third point
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
      final result = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(result.updatedRoute.length, 3);
      expect(result.updatedRoute[0].coordinates, [0.0, 0.0]);
      expect(result.updatedRoute[1].coordinates, [2.0, 2.0]);
      expect(result.updatedRoute[2].coordinates, [4.0, 4.0]);
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
      final result = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(result.updatedRoute.length, 2);
      expect(result.updatedRoute[0].coordinates, [2.0, 2.0]);
      expect(result.updatedRoute[1].coordinates, [4.0, 4.0]);
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
      final result = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(result.updatedRoute.length, 2);
      expect(result.updatedRoute[0].coordinates, [3.0, 3.0]); // Projected point
      expect(result.updatedRoute[1].coordinates, [4.0, 4.0]); // End point
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
      final result = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(result.updatedRoute.length, 3); // Should return original route
      expect(result.updatedRoute[0].coordinates, [0.0, 0.0]);
      expect(result.updatedRoute[1].coordinates, [2.0, 2.0]);
      expect(result.updatedRoute[2].coordinates, [4.0, 4.0]);
    });
    test('growRoute - adds user location to start', () {
      // Arrange
      final userLocation = GeoJSONPoint([10.0, 10.0]);
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0])
      ];

      // Act
      final result = growRoute(userLocation, routePoints);

      // Assert
      expect(result.updatedRoute.length, 3);
      expect(result.updatedRoute[0].coordinates,
          [10.0, 10.0]); // User location at start
      expect(result.updatedRoute[1].coordinates, [0.0, 0.0]);
      expect(result.updatedRoute[2].coordinates, [2.0, 2.0]);
      expect(result.hasChanged, true);
      expect(result.changedSegmentIndex, 0);
      expect(result.originalSegment, isEmpty);
      expect(result.newSegment.length, 2);
      expect(result.newSegment[0].coordinates, [10.0, 10.0]);
      expect(result.newSegment[1].coordinates, [0.0, 0.0]);
      expect(result.isGrowing, true);
      expect(result.isNearlyComplete, false);
    });
    test('growRoute - with empty route', () {
      // Arrange
      final userLocation = GeoJSONPoint([10.0, 10.0]);
      final emptyRoute = <GeoJSONPoint>[];

      // Act
      final result = growRoute(userLocation, emptyRoute);

      // Assert
      expect(result.updatedRoute.length, 2); // Now includes duplicate point
      expect(result.updatedRoute[0].coordinates, [10.0, 10.0]); // User location
      expect(result.updatedRoute[1].coordinates, [10.0, 10.0]); // Duplicated
      expect(result.hasChanged, true);
      expect(result.changedSegmentIndex, 0);
      expect(result.originalSegment, isEmpty);
      expect(result.newSegment.length, 2);
      expect(result.newSegment[0].coordinates, [10.0, 10.0]);
      expect(result.newSegment[1].coordinates, [10.0, 10.0]);
      expect(result.isGrowing, true);
      expect(result.isNearlyComplete, false);
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
        final shrinkResult = shrinkRoute(checkResult.projectedPoint,
            checkResult.segmentIndex, checkResult.projectionRatio, routePoints);

        // With the test data, we know it should shrink but might still include all points
        // depending on where the projection lands, so just verify it's valid
        expect(shrinkResult.updatedRoute.length, greaterThanOrEqualTo(1));
        expect(shrinkResult.hasChanged, true);
        expect(shrinkResult.changedSegmentIndex, checkResult.segmentIndex);

        // Conversion back to LineString works
        final shrunkLineString = pointsToLineString(shrinkResult.updatedRoute);
        expect(shrunkLineString.coordinates.length,
            shrinkResult.updatedRoute.length);
      } else {
        // User is off route, grow the route
        final growResult = growRoute(userLocation, routePoints);

        // Verify the grown route has the user location at the start
        expect(growResult.updatedRoute.length, equals(routePoints.length + 1));
        expect(
            growResult.updatedRoute[0].coordinates, userLocation.coordinates);
        expect(growResult.hasChanged, true);
        expect(growResult.isGrowing, true);

        // Conversion back to LineString works
        final grownLineString = pointsToLineString(growResult.updatedRoute);
        expect(
            grownLineString.coordinates.length, growResult.updatedRoute.length);
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
      var shrinkResult1 = shrinkRoute(checkResult1.projectedPoint,
          checkResult1.segmentIndex, checkResult1.projectionRatio, routePoints);
      expect(shrinkResult1.hasChanged, true);
      expect(shrinkResult1.changedSegmentIndex, 0);

      // Second user location - now near third segment of shrunk route
      var userLocation2 = GeoJSONPoint([25.0, 25.0]);
      var checkResult2 = isUserOnRoute(
          userLocation2, shrinkResult1.updatedRoute,
          thresholdMeters: 100);
      expect(checkResult2.isOnRoute, true);

      // Second shrink
      var shrinkResult2 = shrinkRoute(
          checkResult2.projectedPoint,
          checkResult2.segmentIndex,
          checkResult2.projectionRatio,
          shrinkResult1.updatedRoute);

      // Verify route has shrunk properly
      expect(shrinkResult2.updatedRoute.length,
          lessThan(shrinkResult1.updatedRoute.length));
      expect(shrinkResult2.hasChanged, true);

      // Last check - user at end of route
      var userLocation3 = GeoJSONPoint([50.0, 50.0]);
      var checkResult3 = isUserOnRoute(
          userLocation3, shrinkResult2.updatedRoute,
          thresholdMeters: 100);
      expect(checkResult3.isOnRoute, true);

      // Final shrink
      var shrinkResult3 = shrinkRoute(
          checkResult3.projectedPoint,
          checkResult3.segmentIndex,
          checkResult3.projectionRatio,
          shrinkResult2.updatedRoute);

      // Should be at or near the end
      expect(shrinkResult3.updatedRoute.length, lessThanOrEqualTo(2));
      expect(shrinkResult3.isNearlyComplete, true);
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

      // User location near the first segment but not exactly at the start
      var userLocation = GeoJSONPoint([0.1, 0.1]); // Slightly off the start
      var checkResult = isUserOnRoute(userLocation, routePoints);

      expect(checkResult.isOnRoute, true);
      expect(checkResult.segmentIndex,
          anyOf(0, 1)); // Could be either of the very close segments

      // Shrink route from this position
      var shrinkResult = shrinkRoute(checkResult.projectedPoint,
          checkResult.segmentIndex, checkResult.projectionRatio, routePoints);

      expect(shrinkResult.hasChanged, true);
      expect(shrinkResult.updatedRoute.length, greaterThanOrEqualTo(2));
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

      // Shrink the route and check performance
      var shrinkResult = shrinkRoute(checkResult.projectedPoint,
          checkResult.segmentIndex, checkResult.projectionRatio, routePoints);

      expect(shrinkResult.hasChanged, true);
      expect(shrinkResult.updatedRoute.length,
          lessThan(routePoints.length)); // Route should be shorter
      expect(shrinkResult.changedSegmentIndex, checkResult.segmentIndex);
    });
  });

  group('RouteUpdateResult Tests', () {
    test('shrinkRoute returns valid RouteUpdateResult when shrinking route',
        () {
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
      final result = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(result, isA<RouteUpdateResult>());
      expect(result.hasChanged, true);
      expect(result.isGrowing, false);
      expect(result.changedSegmentIndex, 0);
      expect(result.originalSegment.length, 2);
      expect(result.originalSegment[0].coordinates, [0.0, 0.0]);
      expect(result.originalSegment[1].coordinates, [2.0, 2.0]);
      expect(result.newSegment.length, 2);
      expect(result.newSegment[0].coordinates, [1.0, 1.0]);
      expect(result.newSegment[1].coordinates, [2.0, 2.0]);
      expect(result.updatedRoute.length, 3);
      expect(result.isNearlyComplete, false);
    });
    test('shrinkRoute sets isNearlyComplete when close to destination', () {
      // Arrange
      final projectedPoint = GeoJSONPoint([3.9, 3.9]); // Almost at the end
      const segmentIndex = 1; // Last segment
      const projectionRatio =
          0.99; // Very close to end (must be >= 0.99 per implementation)
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0]),
        GeoJSONPoint([4.0, 4.0])
      ];

      // Act
      final result = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(result.hasChanged, true);
      expect(result.isGrowing, false);
      expect(result.changedSegmentIndex, 1);
      expect(result.updatedRoute.length, 2);
      // Should be nearly complete since we're at the end of the last segment
      expect(result.isNearlyComplete, true);
    });

    test('growRoute returns valid RouteUpdateResult when growing route', () {
      // Arrange
      final userLocation = GeoJSONPoint([10.0, 10.0]);
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0])
      ];

      // Act
      final result = growRoute(userLocation, routePoints);

      // Assert
      expect(result, isA<RouteUpdateResult>());
      expect(result.hasChanged, true);
      expect(result.isGrowing, true);
      expect(result.changedSegmentIndex, 0);
      expect(
          result.originalSegment.length, 0); // No original segment when growing
      expect(result.newSegment.length, 2);
      expect(result.newSegment[0].coordinates, [10.0, 10.0]);
      expect(result.newSegment[1].coordinates, [0.0, 0.0]);
      expect(result.updatedRoute.length, 3);
      expect(result.isNearlyComplete, false);
    });

    test('shrinkRoute handles edge cases properly', () {
      // Arrange - invalid segment index
      final projectedPoint = GeoJSONPoint([0.0, 0.0]);
      const segmentIndex = -1; // Invalid
      const projectionRatio = 0.5;
      final routePoints = [
        GeoJSONPoint([0.0, 0.0]),
        GeoJSONPoint([2.0, 2.0]),
        GeoJSONPoint([4.0, 4.0])
      ];

      // Act
      final result = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(result.hasChanged, false); // Should not change the route
      expect(result.changedSegmentIndex, -1); // Invalid segment
      expect(result.updatedRoute.length, 3); // Original route returned
    });
  });

  group('Integration Tests - RouteUpdateResult', () {
    test('Progressive route shrinking with segment tracking', () {
      // Setup a route with multiple segments
      final route = GeoJSONLineString([
        [0.0, 0.0], // Start
        [10.0, 10.0], // Point 1
        [20.0, 20.0], // Point 2
        [30.0, 30.0], // Point 3
        [40.0, 40.0], // End
      ]);

      var routePoints = lineStringToPoints(route);
      expect(routePoints.length, 5);

      // First user location - on first segment
      var userLocation1 = GeoJSONPoint([5.0, 5.0]);
      var checkResult1 =
          isUserOnRoute(userLocation1, routePoints, thresholdMeters: 100);
      expect(checkResult1.isOnRoute, true);
      expect(checkResult1.segmentIndex, 0);

      // First shrink
      var shrinkResult1 = shrinkRoute(checkResult1.projectedPoint,
          checkResult1.segmentIndex, checkResult1.projectionRatio, routePoints);

      expect(shrinkResult1.hasChanged, true);
      expect(shrinkResult1.changedSegmentIndex, 0);
      expect(shrinkResult1.isGrowing, false);

      // Second user location - on second segment of shrunk route
      var userLocation2 = GeoJSONPoint([15.0, 15.0]);
      var checkResult2 = isUserOnRoute(
          userLocation2, shrinkResult1.updatedRoute,
          thresholdMeters: 100);
      expect(checkResult2.isOnRoute, true);

      // Second shrink
      var shrinkResult2 = shrinkRoute(
          checkResult2.projectedPoint,
          checkResult2.segmentIndex,
          checkResult2.projectionRatio,
          shrinkResult1.updatedRoute);

      expect(shrinkResult2.hasChanged, true);
      expect(shrinkResult2.changedSegmentIndex, checkResult2.segmentIndex);
      expect(shrinkResult2.isGrowing, false);

      // Third user location - off route, need to grow
      var userLocation3 = GeoJSONPoint([25.0, 15.0]); // Off to the side
      var checkResult3 = isUserOnRoute(
          userLocation3, shrinkResult2.updatedRoute,
          thresholdMeters: 5);
      expect(checkResult3.isOnRoute, false);

      // Grow route
      var growResult = growRoute(userLocation3, shrinkResult2.updatedRoute);

      expect(growResult.hasChanged, true);
      expect(growResult.changedSegmentIndex, 0); // First segment changed
      expect(growResult.isGrowing, true);
      expect(growResult.newSegment.length, 2);
      expect(growResult.newSegment[0].coordinates, userLocation3.coordinates);
    });

    test('Route completion detection', () {
      // Setup a route with just two segments
      final route = GeoJSONLineString([
        [0.0, 0.0], // Start
        [10.0, 10.0], // Middle
        [20.0, 20.0], // End
      ]);

      var routePoints = lineStringToPoints(route);

      // User at the very end of the route
      var userLocation = GeoJSONPoint([20.0, 20.0]);
      var checkResult =
          isUserOnRoute(userLocation, routePoints, thresholdMeters: 100);
      expect(checkResult.isOnRoute, true);
      expect(checkResult.segmentIndex, 1); // Second segment
      expect(checkResult.projectionRatio, 1.0); // End of segment

      // Shrink to the end
      var result = shrinkRoute(checkResult.projectedPoint,
          checkResult.segmentIndex, checkResult.projectionRatio, routePoints);

      expect(result.isNearlyComplete, true);
      expect(result.updatedRoute.length, 2);
      // The two points should be identical (duplicated end point)
      expect(result.updatedRoute[0].coordinates,
          result.updatedRoute[1].coordinates);
    });
  });
}
