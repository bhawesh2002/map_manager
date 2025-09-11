import 'dart:isolate';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:map_manager/map_manager.dart';

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
      message.sendPort.send(
        RouteCalculationResult(
          routeData: RouteCalculationData.error(),
          success: false,
          errorMessage: "Route has fewer than 2 points",
        ),
      );
      return;
    }

    if (geoRoute.coordinates.length < 2) {
      message.sendPort.send(
        RouteCalculationResult(
          routeData: RouteCalculationData.error(),
          success: false,
          errorMessage: "Route too short for processing",
        ),
      );
      return;
    }

    // Use the centralized calculation function
    final calculationResult = calculateUpdatedRoute(userLocation, geoRoute);

    if (calculationResult != null) {
      message.sendPort.send(
        RouteCalculationResult(success: true, routeData: calculationResult),
      );
    } else {
      // This shouldn't happen with the current implementation, but handle it just in case
      message.sendPort.send(
        RouteCalculationResult(
          routeData: RouteCalculationData.unchanged(
            isOnRoute: false,
            distanceFromRoute: double.infinity,
          ),
          success: true,
        ),
      );
    }
  } catch (e) {
    message.sendPort.send(
      RouteCalculationResult(
        routeData: RouteCalculationData.error(),
        success: false,
        errorMessage: e.toString(),
      ),
    );
  }
}
