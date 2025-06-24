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
      final route = GeoJSONLineString([
        [0.0, 0.0],
        [2.0, 2.0],
        [4.0, 4.0]
      ]);

      // Act
      final result = isUserOnRoute(userLocation, route);

      // Assert
      expect(result.isOnRoute, true);
      expect(result.segmentIndex, 0); // First segment
      expect(result.distance, closeTo(0.0, 0.001)); // User is exactly on route
      expect(result.projectionRatio, closeTo(0.5, 0.001)); // Halfway on segment
    });
    test('isUserOnRoute - user off route', () {
      // Arrange
      final userLocation = GeoJSONPoint([3.0, 0.0]); // Far from route
      final route = GeoJSONLineString([
        [0.0, 0.0],
        [2.0, 2.0],
        [4.0, 4.0]
      ]);

      // Act
      final result = isUserOnRoute(userLocation, route, thresholdMeters: 10);

      // Assert
      expect(result.isOnRoute, false);
      expect(
          result.segmentIndex, anyOf(0, 1)); // Either segment could be closest
      expect(result.distance, greaterThan(10.0)); // Greater than threshold
    });
    test('isUserOnRoute - minimal route', () {
      // Note: We can't create empty GeoJSONLineString, so test with minimal valid route
      // Arrange
      final userLocation = GeoJSONPoint([5.0, 5.0]); // Far from route
      final minimalRoute = GeoJSONLineString([
        [0.0, 0.0],
        [0.0, 0.0] // Same point twice to create minimal valid route
      ]);

      // Act
      final result = isUserOnRoute(userLocation, minimalRoute);

      // Assert
      expect(result.isOnRoute, false);
      expect(result.segmentIndex, 0); // Should find the segment
      expect(result.distance, greaterThan(0.0));
    });
    test('isUserOnRoute - minimal valid route', () {
      // Note: We can't create GeoJSONLineString with single point, use minimal valid route
      // Arrange
      final userLocation = GeoJSONPoint([1.0, 1.0]);
      final minimalRoute = GeoJSONLineString([
        [0.0, 0.0],
        [1.0, 1.0] // Two different points for valid route
      ]);

      // Act
      final result = isUserOnRoute(userLocation, minimalRoute);

      // Assert
      expect(result.isOnRoute, true); // User is exactly on the route
      expect(result.segmentIndex, 0); // First and only segment
      expect(result.distance, closeTo(0.0, 0.001)); // User is exactly on route
    });
  });

  group('Route Modification Tests', () {
    test('shrinkRoute - middle segment projection', () {
      // Arrange
      final projectedPoint = GeoJSONPoint([1.0, 1.0]);
      const segmentIndex = 0;
      const projectionRatio = 0.5; // Middle of segment
      final routePoints = GeoJSONLineString([
        [0.0, 0.0],
        [2.0, 2.0],
        [4.0, 4.0]
      ]);

      // Act
      final result = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(result.updatedRoute.coordinates.length, 3);
      expect(result.updatedRoute.coordinates[0], [1.0, 1.0]); // Projected point
      expect(result.updatedRoute.coordinates[1],
          [2.0, 2.0]); // Original second point
      expect(result.updatedRoute.coordinates[2],
          [4.0, 4.0]); // Original third point
    });
    test('shrinkRoute - start of segment projection', () {
      // Arrange
      final projectedPoint = GeoJSONPoint([0.0, 0.0]);
      const segmentIndex = 0;
      const projectionRatio = 0.0; // Start of segment
      final routePoints = GeoJSONLineString([
        [0.0, 0.0],
        [2.0, 2.0],
        [4.0, 4.0]
      ]);

      // Act
      final result = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(result.updatedRoute.coordinates.length, 3);
      expect(result.updatedRoute.coordinates[0], [0.0, 0.0]);
      expect(result.updatedRoute.coordinates[1], [2.0, 2.0]);
      expect(result.updatedRoute.coordinates[2], [4.0, 4.0]);
    });
    test('shrinkRoute - end of segment projection', () {
      // Arrange
      final projectedPoint = GeoJSONPoint([2.0, 2.0]);
      const segmentIndex = 0;
      const projectionRatio = 1.0; // End of segment
      final routePoints = GeoJSONLineString([
        [0.0, 0.0],
        [2.0, 2.0],
        [4.0, 4.0]
      ]);

      // Act
      final result = shrinkRoute(
          projectedPoint, segmentIndex, projectionRatio, routePoints);

      // Assert
      expect(result.updatedRoute.coordinates.length, 2);
      expect(result.updatedRoute.coordinates[0], [2.0, 2.0]);
      expect(result.updatedRoute.coordinates[1], [4.0, 4.0]);
    });
  });

  group('GeoJSONLineString API Tests', () {
    group('shrinkRoute with GeoJSONLineString API', () {
      test('shrinkRoute - middle segment projection with GeoJSONLineString',
          () {
        // Arrange
        final projectedPoint = GeoJSONPoint([1.0, 1.0]);
        const segmentIndex = 0;
        const projectionRatio = 0.5; // Middle of segment
        final route = GeoJSONLineString([
          [0.0, 0.0],
          [2.0, 2.0],
          [4.0, 4.0]
        ]);

        // Act
        final result =
            shrinkRoute(projectedPoint, segmentIndex, projectionRatio, route);

        // Assert
        expect(result.hasChanged, true);
        expect(result.isGrowing, false);
        expect(result.changedSegmentIndex, 0);
        expect(result.updatedRoute.coordinates.length, 3);
        expect(
            result.updatedRoute.coordinates[0], [1.0, 1.0]); // Projected point
        expect(result.updatedRoute.coordinates[1], [2.0, 2.0]);
        expect(result.updatedRoute.coordinates[2], [4.0, 4.0]);

        // Verify segment information
        expect(result.originalSegment.length, 2);
        expect(result.originalSegment[0].coordinates, [0.0, 0.0]);
        expect(result.originalSegment[1].coordinates, [2.0, 2.0]);

        expect(result.newSegment.length, 2);
        expect(result.newSegment[0].coordinates, [1.0, 1.0]);
        expect(result.newSegment[1].coordinates, [2.0, 2.0]);
      });

      test('shrinkRoute - end of route projection with GeoJSONLineString', () {
        // Arrange
        final projectedPoint = GeoJSONPoint([3.0, 3.0]);
        const segmentIndex = 1; // Last segment
        const projectionRatio = 0.5; // Middle of last segment
        final route = GeoJSONLineString([
          [0.0, 0.0],
          [2.0, 2.0],
          [4.0, 4.0]
        ]);

        // Act
        final result =
            shrinkRoute(projectedPoint, segmentIndex, projectionRatio, route);

        // Assert
        expect(result.hasChanged, true);
        expect(result.isGrowing, false);
        expect(result.changedSegmentIndex, 1);
        expect(result.updatedRoute.coordinates.length, 2);
        expect(
            result.updatedRoute.coordinates[0], [3.0, 3.0]); // Projected point
        expect(result.updatedRoute.coordinates[1], [4.0, 4.0]); // Last point

        // Verify segment information
        expect(result.originalSegment.length, 2);
        expect(result.originalSegment[0].coordinates, [2.0, 2.0]);
        expect(result.originalSegment[1].coordinates, [4.0, 4.0]);

        expect(result.newSegment.length, 2);
        expect(result.newSegment[0].coordinates, [3.0, 3.0]);
        expect(result.newSegment[1].coordinates, [4.0, 4.0]);
      });

      test(
          'shrinkRoute - end of final segment with GeoJSONLineString (nearly complete)',
          () {
        // Arrange
        final projectedPoint = GeoJSONPoint([4.0, 4.0]); // At the very end
        const segmentIndex = 1; // Last segment
        const projectionRatio = 1.0; // End of segment
        final route = GeoJSONLineString([
          [0.0, 0.0],
          [2.0, 2.0],
          [4.0, 4.0]
        ]);

        // Act
        final result =
            shrinkRoute(projectedPoint, segmentIndex, projectionRatio, route);

        // Assert
        expect(result.hasChanged, true);
        expect(result.isGrowing, false);
        expect(result.isNearlyComplete, true);
        expect(result.updatedRoute.coordinates.length, 2);
        expect(result.updatedRoute.coordinates[0], [4.0, 4.0]); // Last point
        expect(result.updatedRoute.coordinates[1],
            [4.0, 4.0]); // Duplicated for valid LineString
      });
      test('shrinkRoute - edge case with invalid input', () {
        // Note: We can't create a GeoJSONLineString with empty coordinates as it's invalid.
        // Instead, test with invalid parameters which should trigger the edge case handling.

        // Arrange
        final projectedPoint = GeoJSONPoint([1.0, 1.0]);
        const segmentIndex = -1; // Invalid segment index
        const projectionRatio = 0.5;
        final route = GeoJSONLineString([
          [0.0, 0.0],
          [1.0, 1.0]
        ]);

        // Act
        final result =
            shrinkRoute(projectedPoint, segmentIndex, projectionRatio, route);

        // Assert
        expect(result.hasChanged, false);
        expect(result.changedSegmentIndex, -1);
        expect(result.updatedRoute, equals(route));
      });

      test('shrinkRoute - edge case with invalid segment index', () {
        // Arrange
        final projectedPoint = GeoJSONPoint([1.0, 1.0]);
        const segmentIndex = 5; // Invalid index
        const projectionRatio = 0.5;
        final route = GeoJSONLineString([
          [0.0, 0.0],
          [2.0, 2.0],
          [4.0, 4.0]
        ]);

        // Act
        final result =
            shrinkRoute(projectedPoint, segmentIndex, projectionRatio, route);

        // Assert
        expect(result.hasChanged, false);
        expect(result.changedSegmentIndex, -1);
        // Should return original route unchanged
        expect(result.updatedRoute.coordinates, route.coordinates);
      });
    });

    group('growRoute with GeoJSONLineString API', () {
      test('growRoute - add user location to start of route', () {
        // Arrange
        final userLocation = GeoJSONPoint([10.0, 10.0]);
        final route = GeoJSONLineString([
          [0.0, 0.0],
          [2.0, 2.0],
          [4.0, 4.0]
        ]);

        // Act
        final result = growRoute(userLocation, route);

        // Assert
        expect(result.hasChanged, true);
        expect(result.isGrowing, true);
        expect(result.changedSegmentIndex, 0);
        expect(result.updatedRoute.coordinates.length, 4);
        expect(
            result.updatedRoute.coordinates[0], [10.0, 10.0]); // User location
        expect(result.updatedRoute.coordinates[1], [0.0, 0.0]);
        expect(result.updatedRoute.coordinates[2], [2.0, 2.0]);
        expect(result.updatedRoute.coordinates[3], [4.0, 4.0]);

        // Verify segment information
        expect(result.originalSegment.length,
            0); // No original segment when growing

        expect(result.newSegment.length, 2);
        expect(result.newSegment[0].coordinates, [10.0, 10.0]); // User location
        expect(result.newSegment[1].coordinates,
            [0.0, 0.0]); // First point of original route
      });
      test('growRoute - edge case with minimal route', () {
        // Note: We can't create a GeoJSONLineString with empty coordinates as it's invalid.
        // Instead, test with a minimal valid route.

        // Arrange
        final userLocation = GeoJSONPoint([10.0, 10.0]);
        final minimalRoute = GeoJSONLineString([
          [0.0, 0.0],
          [0.0, 0.0] // Duplicate point to create minimal valid route
        ]);

        // Act
        final result = growRoute(userLocation, minimalRoute);

        // Assert
        expect(result.hasChanged, true);
        expect(result.isGrowing, true);
        expect(result.changedSegmentIndex, 0);
        expect(result.updatedRoute.coordinates.length, 3);
        expect(
            result.updatedRoute.coordinates[0], [10.0, 10.0]); // User location
        expect(result.updatedRoute.coordinates[1],
            [0.0, 0.0]); // Original route points
        expect(result.updatedRoute.coordinates[2],
            [0.0, 0.0]); // Original route points

        // Verify segment information
        expect(result.originalSegment.length, 0);
        expect(result.newSegment.length, 2);
        expect(result.newSegment[0].coordinates, [10.0, 10.0]);
        expect(result.newSegment[1].coordinates,
            [0.0, 0.0]); // First point of original route
      });

      test('growRoute - preserves all original route points', () {
        // Arrange
        final userLocation = GeoJSONPoint([10.0, 10.0]);
        final route = GeoJSONLineString([
          [0.0, 0.0],
          [2.0, 2.0],
          [4.0, 4.0],
          [6.0, 6.0],
          [8.0, 8.0]
        ]);

        // Act
        final result = growRoute(userLocation, route);

        // Assert
        expect(result.updatedRoute.coordinates.length,
            route.coordinates.length + 1);
        // Check that all original points are preserved in order
        for (int i = 0; i < route.coordinates.length; i++) {
          expect(result.updatedRoute.coordinates[i + 1], route.coordinates[i]);
        }
      });

      test('growRoute - maintains proper segment information', () {
        // Arrange
        final userLocation =
            GeoJSONPoint([5.0, -5.0]); // Off to the side of the route
        final route = GeoJSONLineString([
          [0.0, 0.0],
          [2.0, 2.0]
        ]);

        // Act
        final result = growRoute(userLocation, route);

        // Assert
        expect(result.newSegment.length, 2);
        expect(result.newSegment[0].coordinates, [5.0, -5.0]); // User location
        expect(result.newSegment[1].coordinates,
            [0.0, 0.0]); // First point of original route
        expect(
            result.changedSegmentIndex, 0); // First segment is always changed
        expect(result.isNearlyComplete,
            false); // Growing never marks as nearly complete
      });
      test('growRoute - with minimal valid route', () {
        // Note: We can't create a GeoJSONLineString with a single point as it's invalid.
        // Use a minimal valid LineString instead.

        // Arrange
        final userLocation = GeoJSONPoint([10.0, 10.0]);
        final minimalRoute = GeoJSONLineString([
          [0.0, 0.0],
          [1.0, 1.0] // Two points for valid LineString
        ]);

        // Act
        final result = growRoute(userLocation, minimalRoute);

        // Assert        expect(result.updatedRoute.coordinates.length, 3);
        expect(
            result.updatedRoute.coordinates[0], [10.0, 10.0]); // User location
        expect(result.updatedRoute.coordinates[1],
            [0.0, 0.0]); // First original point
        expect(result.updatedRoute.coordinates[2],
            [1.0, 1.0]); // Second original point
        expect(result.newSegment.length, 2);
        expect(result.newSegment[0].coordinates, [10.0, 10.0]);
        expect(result.newSegment[1].coordinates, [0.0, 0.0]);
      });
    });
  });

  group('Integration Tests', () {
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
      var checkResult = isUserOnRoute(pacificPoint, globalRoute,
          thresholdMeters: 1000000); // 1000km threshold

      // The haversine distance calculation should handle the date line
      // This is a difficult case for projection but should give reasonable results
      expect(checkResult.segmentIndex, anyOf(0, 1));
    });
  });
}
