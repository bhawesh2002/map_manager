import 'dart:isolate';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:map_manager_mapbox/utils/route_utils.dart';
import 'package:map_manager_mapbox/utils/extensions.dart';
import '../location_update.dart';

/// Message sent to the isolate for route calculation
class RouteCalculationMessage {
  final LocationUpdate update;
  final List<List<double>> routeCoordinates;
  final SendPort sendPort;

  RouteCalculationMessage({
    required this.update,
    required this.routeCoordinates,
    required this.sendPort,
  });
}

/// Result from the route calculation isolate
class RouteCalculationResult {
  final RouteCalculationData routeData;
  final bool success;
  final String? errorMessage;

  RouteCalculationResult({
    required this.routeData,
    required this.success,
    this.errorMessage,
  });
}

/// Entry point for the isolate
void routeCalculationIsolate(RouteCalculationMessage message) {
  try {
    // Convert the user's location to GeoJSON point
    final userLocation = message.update.location.toGeojsonPoint();

    // Create GeoJSON LineString from the provided coordinates
    final geoRoute = GeoJSONLineString(message.routeCoordinates);

    // Extra safeguard - ensure we have at least 2 coordinates for the LineString
    if (message.routeCoordinates.length < 2) {
      message.sendPort.send(RouteCalculationResult(
        routeData: RouteCalculationData.error(),
        success: false,
        errorMessage: "Route has fewer than 2 points",
      ));
      return;
    }

    if (geoRoute.coordinates.length < 2) {
      message.sendPort.send(RouteCalculationResult(
        routeData: RouteCalculationData.error(),
        success: false,
        errorMessage: "Route too short for processing",
      ));
      return;
    } // Check if user is on route
    final checkResult =
        isUserOnRoute(userLocation, geoRoute, thresholdMeters: 50.0);
    RouteUpdateResult routeUpdateResult;
    bool isOnRoute = checkResult.isOnRoute;

    if (isOnRoute) {
      // User is on route - shrink
      routeUpdateResult = shrinkRoute(checkResult.projectedPoint,
          checkResult.segmentIndex, checkResult.projectionRatio, geoRoute);
    } else {
      // User is off route - grow
      routeUpdateResult = growRoute(userLocation, geoRoute);
    }

    // Only return data if there's actually a change
    if (routeUpdateResult.hasChanged) {
      message.sendPort.send(RouteCalculationResult(
        success: true,
        routeData: RouteCalculationData.routeChanged(
          isOnRoute: isOnRoute,
          distanceFromRoute: checkResult.distance,
          changedSegmentIndex: routeUpdateResult.changedSegmentIndex,
          originalSegment: routeUpdateResult.originalSegment,
          newSegment: routeUpdateResult.newSegment,
          isGrowing: routeUpdateResult.isGrowing,
          isNearlyComplete: routeUpdateResult.isNearlyComplete,
          updatedRoute: routeUpdateResult.updatedRoute,
        ),
      ));
    } else {
      message.sendPort.send(RouteCalculationResult(
        success: true,
        routeData: RouteCalculationData.unchanged(
            isOnRoute: isOnRoute, distanceFromRoute: checkResult.distance),
      ));
    }
  } catch (e) {
    message.sendPort.send(RouteCalculationResult(
      routeData: RouteCalculationData.error(),
      success: false,
      errorMessage: e.toString(),
    ));
  }
}
