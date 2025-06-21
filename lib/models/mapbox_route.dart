import 'package:geojson_vi/geojson_vi.dart';
import 'package:latlong2/latlong.dart';

/// Represents a complete route from the Mapbox Directions API
class MapboxRoute {
  final RouteGeometry geometry;
  final List<RouteLeg> legs;
  final String weightName;
  final double weight;
  final double duration; // seconds
  final double distance; // meters
  final String voiceLocale;
  final double? weightTypical;
  final double? durationTypical;

  MapboxRoute({
    required this.geometry,
    required this.legs,
    required this.weightName,
    required this.weight,
    required this.duration,
    required this.distance,
    required this.voiceLocale,
    this.weightTypical,
    this.durationTypical,
  });

  /// Creates a MapboxRoute from JSON data
  factory MapboxRoute.fromJson(Map<String, dynamic> json) {
    return MapboxRoute(
      geometry: RouteGeometry.fromJson(json['geometry']),
      legs: (json['legs'] as List)
          .map((leg) => RouteLeg.fromJson(leg as Map<String, dynamic>))
          .toList(),
      weightName: json['weight_name'] as String,
      weight: (json['weight'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      voiceLocale: json['voiceLocale'] as String? ?? 'en-US',
      weightTypical: json['weight_typical'] != null
          ? (json['weight_typical'] as num).toDouble()
          : null,
      durationTypical: json['duration_typical'] != null
          ? (json['duration_typical'] as num).toDouble()
          : null,
    );
  }

  /// Converts this route to JSON
  Map<String, dynamic> toJson() {
    return {
      'geometry': geometry.toJson(),
      'legs': legs.map((leg) => leg.toJson()).toList(),
      'weight_name': weightName,
      'weight': weight,
      'duration': duration,
      'distance': distance,
      'voiceLocale': voiceLocale,
      'weight_typical': weightTypical,
      'duration_typical': durationTypical,
    };
  }

  /// Gets the primary (first) leg of the route
  RouteLeg get primaryLeg => legs.first;

  /// Gets the estimated duration as a Duration object
  Duration get estimatedDuration => Duration(seconds: duration.round());

  /// Gets the distance in kilometers
  double get distanceKilometers => distance / 1000;

  /// Gets all route coordinates
  List<List<double>> get routeCoordinates => geometry.coordinates;

  /// Converts route to a GeoJSON LineString
  GeoJSONLineString toGeoJSONLineString() {
    return geometry.toGeoJSONLineString();
  }

  /// Finds the index of the closest point on the route to the given position
  int findClosestPointIndex(LatLng position) {
    final coordinates = geometry.coordinates;
    if (coordinates.isEmpty) {
      throw Exception('empty coordinates. route does not exists.');
    }
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < coordinates.length; i++) {
      final routePoint = LatLng(
        coordinates[i][1], // latitude
        coordinates[i][0], // longitude
      );

      final distance =
          const Distance().as(LengthUnit.Meter, position, routePoint);

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// Calculates the remaining distance from the given position to the end of the route
  double calculateRemainingDistance(LatLng position) {
    final coordinates = geometry.coordinates;
    if (coordinates.isEmpty) return 0;

    final closestPointIndex = findClosestPointIndex(position);
    double remainingDistance = 0.0;

    // Sum distances of remaining segments
    for (int i = closestPointIndex; i < coordinates.length - 1; i++) {
      final p1 = LatLng(
        coordinates[i][1], // latitude
        coordinates[i][0], // longitude
      );
      final p2 = LatLng(
        coordinates[i + 1][1], // latitude
        coordinates[i + 1][0], // longitude
      );

      remainingDistance += const Distance().as(LengthUnit.Meter, p1, p2);
    }

    // Add distance from current position to closest point
    if (closestPointIndex < coordinates.length) {
      final closestPoint = LatLng(
        coordinates[closestPointIndex][1], // latitude
        coordinates[closestPointIndex][0], // longitude
      );
      remainingDistance +=
          const Distance().as(LengthUnit.Meter, position, closestPoint);
    }

    return remainingDistance;
  }

  /// Calculates the remaining duration from the given position based on current speed
  Duration calculateRemainingDuration(LatLng position, double currentSpeedMps) {
    final remainingDistance = calculateRemainingDistance(position);

    // If valid speed provided, use it for calculation
    if (currentSpeedMps > 0.5) {
      return Duration(seconds: (remainingDistance / currentSpeedMps).round());
    }

    // Otherwise use proportional calculation based on original duration
    final totalDistance = distance;
    if (totalDistance <= 0) return Duration.zero;

    final percentRemaining = remainingDistance / totalDistance;
    return Duration(seconds: (duration * percentRemaining).round());
  }

  /// Checks if the given position is off the route
  bool isOffRoute(LatLng position, double thresholdMeters) {
    final distanceToRoute = calculateDistanceToRoute(position);
    return distanceToRoute > thresholdMeters;
  }

  /// Calculates the shortest distance from the position to any segment of the route
  double calculateDistanceToRoute(LatLng position) {
    final coordinates = geometry.coordinates;
    if (coordinates.length < 2) return double.infinity;

    double minDistance = double.infinity;

    // Check each segment of the route
    for (int i = 0; i < coordinates.length - 1; i++) {
      final p1 = LatLng(
        coordinates[i][1], // latitude
        coordinates[i][0], // longitude
      );
      final p2 = LatLng(
        coordinates[i + 1][1], // latitude
        coordinates[i + 1][0], // longitude
      );

      final segmentDistance = _distanceToSegment(position, p1, p2);
      if (segmentDistance < minDistance) {
        minDistance = segmentDistance;
      }
    }

    return minDistance;
  }

  /// Calculates the distance from a point to a line segment
  double _distanceToSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    const distance = Distance();

    // Calculate vector from lineStart to lineEnd
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    // If the line segment is actually a point
    if (dx == 0 && dy == 0) {
      return distance.as(LengthUnit.Meter, point, lineStart);
    }

    // Calculate projection of point onto line
    final t = ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        (dx * dx + dy * dy);

    // If projection falls outside the segment, use distance to the closer endpoint
    if (t < 0) {
      return distance.as(LengthUnit.Meter, point, lineStart);
    } else if (t > 1) {
      return distance.as(LengthUnit.Meter, point, lineEnd);
    }

    // Calculate the closest point on the line segment
    final projectionLng = lineStart.longitude + t * dx;
    final projectionLat = lineStart.latitude + t * dy;
    final projection = LatLng(projectionLat, projectionLng);

    // Return the distance to the projection point
    return distance.as(LengthUnit.Meter, point, projection);
  }

  /// Gets the upcoming step based on current position
  RouteStep? getUpcomingStep(LatLng position) {
    if (legs.isEmpty) return null;

    final primaryLeg = legs.first;
    if (primaryLeg.steps.isEmpty) return null;

    // Find the closest point to determine where we are on the route
    findClosestPointIndex(position);

    // Find which step contains this point
    for (int i = 0; i < primaryLeg.steps.length; i++) {
      final step = primaryLeg.steps[i];
      final stepCoords = step.geometry.coordinates;

      // Check if this step contains our current position (approximately)
      for (int j = 0; j < stepCoords.length; j++) {
        final coord = stepCoords[j];
        final stepPoint = LatLng(coord[1], coord[0]);
        final dist = const Distance().as(LengthUnit.Meter, position, stepPoint);

        // If we're close to a point in this step, return the next step if available
        if (dist < 20 && i < primaryLeg.steps.length - 1) {
          return primaryLeg.steps[i + 1];
        }
      }
    }

    // If we couldn't determine exactly, return the first step as fallback
    return primaryLeg.steps.first;
  }
}

/// Represents the geometry of a route or step
class RouteGeometry {
  final String type; // Always "LineString"
  final List<List<double>> coordinates; // [longitude, latitude] pairs

  RouteGeometry({
    required this.type,
    required this.coordinates,
  });

  factory RouteGeometry.fromJson(Map<String, dynamic> json) {
    return RouteGeometry(
      type: json['type'] as String,
      coordinates: (json['coordinates'] as List)
          .map((coord) =>
              (coord as List).map((c) => (c as num).toDouble()).toList())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': coordinates,
    };
  }

  /// Converts to GeoJSON LineString
  GeoJSONLineString toGeoJSONLineString() {
    return GeoJSONLineString(coordinates);
  }

  /// Converts to list of LatLng for mapping libraries
  List<LatLng> toLatLngList() {
    return coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
  }
}

/// Represents a segment of the route between waypoints
class RouteLeg {
  final String summary;
  final double weight;
  final double duration; // seconds
  final double distance; // meters
  final List<RouteStep> steps;
  final RouteAnnotation? annotation;
  final List<dynamic>? viaWaypoints;
  final List<dynamic>? admins;
  final double? weightTypical;
  final double? durationTypical;

  RouteLeg({
    required this.summary,
    required this.weight,
    required this.duration,
    required this.distance,
    required this.steps,
    this.annotation,
    this.viaWaypoints,
    this.admins,
    this.weightTypical,
    this.durationTypical,
  });
  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    return RouteLeg(
      summary: json['summary'] as String,
      weight: (json['weight'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      steps: (json['steps'] as List)
          .map((step) => RouteStep.fromJson(step as Map<String, dynamic>))
          .toList(),
      annotation: json['annotation'] != null
          ? RouteAnnotation.fromJson(json['annotation'] as Map<String, dynamic>)
          : null,
      viaWaypoints: json['via_waypoints'] as List<dynamic>?,
      admins: json['admins'] as List<dynamic>?,
      weightTypical: json['weight_typical'] != null
          ? (json['weight_typical'] as num).toDouble()
          : null,
      durationTypical: json['duration_typical'] != null
          ? (json['duration_typical'] as num).toDouble()
          : null,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'weight': weight,
      'duration': duration,
      'distance': distance,
      'steps': steps.map((step) => step.toJson()).toList(),
      'annotation': annotation?.toJson(),
      'via_waypoints': viaWaypoints,
      'admins': admins,
      'weight_typical': weightTypical,
      'duration_typical': durationTypical,
    };
  }

  /// Gets the next step within a specified lookahead distance
  RouteStep? getNextStep(LatLng position, double lookaheadDistanceMeters) {
    if (steps.isEmpty) return null;

    // Find the closest step to the current position
    RouteStep? closestStep;
    double minDistance = double.infinity;

    for (final step in steps) {
      for (final coord in step.geometry.coordinates) {
        final stepPoint = LatLng(coord[1], coord[0]);
        final dist = const Distance().as(LengthUnit.Meter, position, stepPoint);

        if (dist < minDistance) {
          minDistance = dist;
          closestStep = step;
        }
      }
    }

    if (closestStep == null) return steps.first;

    // Find the index of the closest step
    final currentIndex = steps.indexOf(closestStep);

    // Calculate cumulative distance to find next step within lookahead
    double cumulativeDistance = 0;
    for (int i = currentIndex; i < steps.length - 1; i++) {
      cumulativeDistance += steps[i].distance;

      if (cumulativeDistance >= lookaheadDistanceMeters) {
        return steps[i + 1];
      }
    }

    // If no step is within lookahead, return the next step if available
    if (currentIndex < steps.length - 1) {
      return steps[currentIndex + 1];
    }

    return null; // No next step (at the end of the route)
  }
}

/// Represents a turn-by-turn instruction
class RouteStep {
  final Maneuver maneuver;
  final String name; // street name
  final double duration; // seconds
  final double distance; // meters
  final String drivingSide;
  final double weight;
  final String mode;
  final RouteGeometry geometry;
  final List<VoiceInstruction>? voiceInstructions;
  final List<BannerInstruction>? bannerInstructions;
  final List<Intersection>? intersections;
  final String? speedLimitUnit;
  final String? speedLimitSign;
  final String? ref;
  final double? weightTypical;
  final double? durationTypical;

  RouteStep({
    required this.maneuver,
    required this.name,
    required this.duration,
    required this.distance,
    required this.drivingSide,
    required this.weight,
    required this.mode,
    required this.geometry,
    this.voiceInstructions,
    this.bannerInstructions,
    this.intersections,
    this.speedLimitUnit,
    this.speedLimitSign,
    this.ref,
    this.weightTypical,
    this.durationTypical,
  });
  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      maneuver: Maneuver.fromJson(json['maneuver'] as Map<String, dynamic>),
      name: json['name'] as String,
      duration: (json['duration'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      drivingSide: json['driving_side'] as String,
      weight: (json['weight'] as num).toDouble(),
      mode: json['mode'] as String,
      geometry:
          RouteGeometry.fromJson(json['geometry'] as Map<String, dynamic>),
      voiceInstructions: json['voiceInstructions'] != null
          ? (json['voiceInstructions'] as List)
              .map(
                  (vi) => VoiceInstruction.fromJson(vi as Map<String, dynamic>))
              .toList()
          : null,
      bannerInstructions: json['bannerInstructions'] != null
          ? (json['bannerInstructions'] as List)
              .map((bi) =>
                  BannerInstruction.fromJson(bi as Map<String, dynamic>))
              .toList()
          : null,
      intersections: json['intersections'] != null
          ? (json['intersections'] as List)
              .map((i) => Intersection.fromJson(i as Map<String, dynamic>))
              .toList()
          : null,
      speedLimitUnit: json['speedLimitUnit'] as String?,
      speedLimitSign: json['speedLimitSign'] as String?,
      ref: json['ref'] as String?,
      weightTypical: json['weight_typical'] != null
          ? (json['weight_typical'] as num).toDouble()
          : null,
      durationTypical: json['duration_typical'] != null
          ? (json['duration_typical'] as num).toDouble()
          : null,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'maneuver': maneuver.toJson(),
      'name': name,
      'duration': duration,
      'distance': distance,
      'driving_side': drivingSide,
      'weight': weight,
      'mode': mode,
      'geometry': geometry.toJson(),
      'voiceInstructions': voiceInstructions?.map((vi) => vi.toJson()).toList(),
      'bannerInstructions':
          bannerInstructions?.map((bi) => bi.toJson()).toList(),
      'intersections': intersections?.map((i) => i.toJson()).toList(),
      'speedLimitUnit': speedLimitUnit,
      'speedLimitSign': speedLimitSign,
      'ref': ref,
      'weight_typical': weightTypical,
      'duration_typical': durationTypical,
    };
  }

  /// Gets the voice instruction to play at a specific distance from the maneuver
  VoiceInstruction? getVoiceInstructionAtDistance(double distanceFromManeuver) {
    if (voiceInstructions == null || voiceInstructions!.isEmpty) return null;

    // Find the instruction that should be played at this distance
    for (final instruction in voiceInstructions!) {
      if (instruction.distanceAlongGeometry >= distanceFromManeuver) {
        return instruction;
      }
    }

    // If we're past all distances, return the last instruction
    return voiceInstructions!.last;
  }
}

/// Represents a maneuver in the route
class Maneuver {
  final double bearingAfter;
  final double bearingBefore;
  final List<double> location; // [longitude, latitude]
  final String? modifier;
  final String type;

  Maneuver({
    required this.bearingAfter,
    required this.bearingBefore,
    required this.location,
    this.modifier,
    required this.type,
  });

  factory Maneuver.fromJson(Map<String, dynamic> json) {
    return Maneuver(
      bearingAfter: (json['bearing_after'] as num).toDouble(),
      bearingBefore: (json['bearing_before'] as num).toDouble(),
      location:
          (json['location'] as List).map((e) => (e as num).toDouble()).toList(),
      modifier: json['modifier'] as String?,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bearing_after': bearingAfter,
      'bearing_before': bearingBefore,
      'location': location,
      'modifier': modifier,
      'type': type,
    };
  }

  /// Gets the maneuver location as a LatLng
  LatLng get latLng => LatLng(location[1], location[0]);

  /// Gets a human-readable description of the maneuver
  String get description {
    final action = _getActionFromType();
    final direction = modifier ?? '';

    if (direction.isNotEmpty) {
      return '$action $direction';
    }
    return action;
  }

  /// Converts maneuver type to a human-readable action
  String _getActionFromType() {
    switch (type) {
      case 'turn':
        return 'Turn';
      case 'depart':
        return 'Depart';
      case 'arrive':
        return 'Arrive';
      case 'merge':
        return 'Merge';
      case 'fork':
        return 'Take the fork';
      case 'roundabout':
        return 'Enter the roundabout';
      case 'exit roundabout':
        return 'Exit the roundabout';
      case 'rotary':
        return 'Enter the rotary';
      case 'exit rotary':
        return 'Exit the rotary';
      case 'continue':
        return 'Continue';
      default:
        return type;
    }
  }
}

/// Represents detailed metrics for route segments
class RouteAnnotation {
  final List<double>? distance; // meters between coordinate pairs
  final List<double>? duration; // seconds between coordinate pairs
  final List<double>? speed; // m/s for each segment
  final List<SpeedLimit>? maxspeed;
  final List<String>? congestion; // text descriptions
  final List<double>? congestionNumeric; // 0-1 scale

  RouteAnnotation({
    this.distance,
    this.duration,
    this.speed,
    this.maxspeed,
    this.congestion,
    this.congestionNumeric,
  });

  factory RouteAnnotation.fromJson(Map<String, dynamic> json) {
    return RouteAnnotation(
      distance: json['distance'] != null
          ? (json['distance'] as List)
              .map((e) => (e as num).toDouble())
              .toList()
          : null,
      duration: json['duration'] != null
          ? (json['duration'] as List)
              .map((e) => (e as num).toDouble())
              .toList()
          : null,
      speed: json['speed'] != null
          ? (json['speed'] as List).map((e) => (e as num).toDouble()).toList()
          : null,
      maxspeed: json['maxspeed'] != null
          ? (json['maxspeed'] as List)
              .map((e) => SpeedLimit.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      congestion: json['congestion'] != null
          ? (json['congestion'] as List).map((e) => e as String).toList()
          : null,
      congestionNumeric: json['congestion_numeric'] != null
          ? (json['congestion_numeric'] as List)
              .map((e) => e != null ? (e as num).toDouble() : 0.0)
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'duration': duration,
      'speed': speed,
      'maxspeed': maxspeed?.map((sl) => sl.toJson()).toList(),
      'congestion': congestion,
      'congestion_numeric': congestionNumeric,
    };
  }

  /// Gets the average speed across all segments in m/s
  double? getAverageSpeed() {
    if (speed == null || speed!.isEmpty) return null;
    final sum = speed!.reduce((a, b) => a + b);
    return sum / speed!.length;
  }

  /// Gets the average congestion level (0-1 scale)
  double? getAverageCongestion() {
    if (congestionNumeric == null || congestionNumeric!.isEmpty) return null;
    final sum = congestionNumeric!.reduce((a, b) => a + b);
    return sum / congestionNumeric!.length;
  }

  /// Gets the most common congestion level as text
  String? getMostCommonCongestion() {
    if (congestion == null || congestion!.isEmpty) return null;

    final Map<String, int> counts = {};
    for (final level in congestion!) {
      counts[level] = (counts[level] ?? 0) + 1;
    }

    String? mostCommon;
    int maxCount = 0;

    counts.forEach((level, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommon = level;
      }
    });

    return mostCommon;
  }
}

/// Represents a speed limit for a route segment
class SpeedLimit {
  final double? speed;
  final String? unit;
  final bool unknown;

  SpeedLimit({
    this.speed,
    this.unit,
    this.unknown = false,
  });

  factory SpeedLimit.fromJson(Map<String, dynamic> json) {
    // Handle the case where speed limit is unknown
    if (json['unknown'] == true) {
      return SpeedLimit(unknown: true);
    }

    return SpeedLimit(
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      unit: json['unit'] as String?,
      unknown: json['unknown'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    if (unknown) {
      return {'unknown': true};
    }

    return {
      'speed': speed,
      'unit': unit,
    };
  }

  /// Converts the speed limit to kilometers per hour
  double? toKmh() {
    if (unknown || speed == null || unit == null) return null;

    if (unit == 'km/h') return speed;
    if (unit == 'mph') return speed! * 1.60934;
    return speed;
  }
}

/// Represents a voice instruction for navigation
class VoiceInstruction {
  final double distanceAlongGeometry;
  final String announcement;
  final String ssmlAnnouncement;

  VoiceInstruction({
    required this.distanceAlongGeometry,
    required this.announcement,
    required this.ssmlAnnouncement,
  });

  factory VoiceInstruction.fromJson(Map<String, dynamic> json) {
    return VoiceInstruction(
      distanceAlongGeometry: (json['distanceAlongGeometry'] as num).toDouble(),
      announcement: json['announcement'] as String,
      ssmlAnnouncement: json['ssmlAnnouncement'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distanceAlongGeometry': distanceAlongGeometry,
      'announcement': announcement,
      'ssmlAnnouncement': ssmlAnnouncement,
    };
  }
}

/// Represents a visual instruction for navigation
class BannerInstruction {
  final double distanceAlongGeometry;
  final BannerComponent primary;
  final BannerComponent? secondary;

  BannerInstruction({
    required this.distanceAlongGeometry,
    required this.primary,
    this.secondary,
  });

  factory BannerInstruction.fromJson(Map<String, dynamic> json) {
    return BannerInstruction(
      distanceAlongGeometry: (json['distanceAlongGeometry'] as num).toDouble(),
      primary:
          BannerComponent.fromJson(json['primary'] as Map<String, dynamic>),
      secondary: json['secondary'] != null
          ? BannerComponent.fromJson(json['secondary'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distanceAlongGeometry': distanceAlongGeometry,
      'primary': primary.toJson(),
      'secondary': secondary?.toJson(),
    };
  }
}

/// Represents a component of a banner instruction
class BannerComponent {
  final String text;
  final String type;
  final String? modifier;

  BannerComponent({
    required this.text,
    required this.type,
    this.modifier,
  });

  factory BannerComponent.fromJson(Map<String, dynamic> json) {
    return BannerComponent(
      text: json['text'] as String,
      type: json['type'] as String,
      modifier: json['modifier'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'type': type,
      'modifier': modifier,
    };
  }
}

/// Represents an intersection along the route
class Intersection {
  final List<double> location; // [longitude, latitude]
  final List<int>? bearings;
  final List<bool>? entry;
  final int? inBearing;
  final int? outBearing;
  final List<String>? lanes;

  Intersection({
    required this.location,
    this.bearings,
    this.entry,
    this.inBearing,
    this.outBearing,
    this.lanes,
  });

  factory Intersection.fromJson(Map<String, dynamic> json) {
    return Intersection(
      location:
          (json['location'] as List).map((e) => (e as num).toDouble()).toList(),
      bearings: json['bearings'] != null
          ? (json['bearings'] as List).map((e) => e as int).toList()
          : null,
      entry: json['entry'] != null
          ? (json['entry'] as List).map((e) => e as bool).toList()
          : null,
      inBearing: json['in'] as int?,
      outBearing: json['out'] as int?,
      lanes: json['lanes'] != null
          ? (json['lanes'] as List).map((e) => e as String).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location,
      'bearings': bearings,
      'entry': entry,
      'in': inBearing,
      'out': outBearing,
      'lanes': lanes,
    };
  }

  /// Gets the intersection location as a LatLng
  LatLng get latLng => LatLng(location[1], location[0]);
}
