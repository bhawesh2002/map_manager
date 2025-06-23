import 'package:flutter/animation.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'dart:math' as math;

/// A tween that interpolates between two lists of GeoJSONPoint objects.
///
/// This tween is useful for animating changes in routes, where the
/// route is represented as a list of points. It handles cases where
/// the begin and end lists have different lengths by interpolating
/// points that exist in both lists and gradually fading in/out points
/// that only exist in one list.
class RoutePointsTween extends Tween<List<GeoJSONPoint>> {
  /// The original (beginning) list of route points
  final List<GeoJSONPoint> _beginPoints;
  
  /// The target (ending) list of route points
  final List<GeoJSONPoint> _endPoints;
  
  /// The segment index that changed, used to optimize the interpolation
  final int changedSegmentIndex;
  
  /// Whether the route is growing (true) or shrinking (false)
  final bool isGrowing;

  /// Creates a [RoutePointsTween] to interpolate between two lists of GeoJSONPoint objects.
  ///
  /// The [begin] list is the starting route points, and [end] is the target route points.
  /// The [changedSegmentIndex] indicates which segment of the route changed,
  /// which helps optimize the interpolation.
  /// The [isGrowing] flag indicates whether the route is growing (true) or shrinking (false).
  RoutePointsTween({
    required List<GeoJSONPoint> begin,
    required List<GeoJSONPoint> end,
    this.changedSegmentIndex = -1,
    this.isGrowing = false,
  })  : _beginPoints = List.from(begin),
        _endPoints = List.from(end),
        super(begin: begin, end: end);

  /// Interpolates between the beginning and ending route points at the progress
  /// specified by [t].
  ///
  /// The interpolation creates a smooth transition between the routes by:
  /// - Keeping unchanged points as-is
  /// - Interpolating points that exist in both routes but have moved
  /// - Adding/removing points as needed when the route grows or shrinks
  @override
  List<GeoJSONPoint> lerp(double t) {
    // Handle edge cases
    if (t <= 0.0) return List.from(_beginPoints);
    if (t >= 1.0) return List.from(_endPoints);
    
    // If the lists are identical, no interpolation is needed
    if (_areListsIdentical(_beginPoints, _endPoints)) {
      return List.from(_beginPoints);
    }

    List<GeoJSONPoint> result = [];
    
    // When growing: we're adding points at the beginning or removing from the end
    // When shrinking: we're removing points from the beginning
    if (isGrowing) {
      // Interpolate the new segment at the beginning
      result = _lerpGrowing(t);
    } else {
      // Handle shrinking route
      result = _lerpShrinking(t);
    }
    
    return result;
  }
  
  /// Interpolates a growing route
  List<GeoJSONPoint> _lerpGrowing(double t) {
    final result = <GeoJSONPoint>[];
    
    // If we're adding a new segment at the beginning (most common case)
    if (changedSegmentIndex == 0 && _endPoints.length > _beginPoints.length) {
      // The new point(s) at the beginning
      final newPointsCount = _endPoints.length - _beginPoints.length;
      
      // Add the new points with an appearing effect
      for (int i = 0; i < newPointsCount; i++) {
        // Interpolate the new point from the nearest existing point to its final position
        final newPoint = _lerpPoint(
          _beginPoints.isNotEmpty ? _beginPoints.first : _endPoints[i + 1], 
          _endPoints[i], 
          t
        );
        result.add(newPoint);
      }
      
      // Add the existing points
      for (int i = 0; i < _beginPoints.length; i++) {
        result.add(_beginPoints[i]);
      }
    } else {
      // Default case: just interpolate all points
      return _lerpAllPoints(t);
    }
    
    return result;
  }
  
  /// Interpolates a shrinking route
  List<GeoJSONPoint> _lerpShrinking(double t) {
    final result = <GeoJSONPoint>[];
    
    // If the route is shrinking from the beginning (most common case)
    if (changedSegmentIndex >= 0 && _beginPoints.length > _endPoints.length) {
      // Figure out how many points are being removed
      final removedPointsCount = _beginPoints.length - _endPoints.length;
      
      // For each point that will remain in the final route
      for (int i = 0; i < _endPoints.length; i++) {
        final beginIndex = i + removedPointsCount;
        
        // If this point exists in both routes, interpolate between its positions
        if (beginIndex < _beginPoints.length) {
          result.add(_lerpPoint(_beginPoints[beginIndex], _endPoints[i], t));
        } else {
          // Point only exists in the end route
          result.add(_endPoints[i]);
        }
      }
    } else {
      // Default case: just interpolate all points
      return _lerpAllPoints(t);
    }
    
    return result;
  }
  
  /// Default interpolation that handles any route changes by finding the best matches
  List<GeoJSONPoint> _lerpAllPoints(double t) {
    final int maxLength = math.max(_beginPoints.length, _endPoints.length);
    final result = <GeoJSONPoint>[];
    
    for (int i = 0; i < maxLength; i++) {
      if (i < _beginPoints.length && i < _endPoints.length) {
        // Both points exist - interpolate between them
        result.add(_lerpPoint(_beginPoints[i], _endPoints[i], t));
      } else if (i < _beginPoints.length) {
        // Only in begin - fade out
        final opacity = 1.0 - t;
        if (opacity > 0.01) {  // Only include if still visible
          result.add(_beginPoints[i]);
        }
      } else {
        // Only in end - fade in
        final opacity = t;
        if (opacity > 0.01) {  // Only include if becoming visible
          result.add(_endPoints[i]);
        }
      }
    }
    
    return result;
  }
  
  /// Interpolates between two GeoJSONPoint objects
  GeoJSONPoint _lerpPoint(GeoJSONPoint begin, GeoJSONPoint end, double t) {
    final double lng = _lerpDouble(begin.coordinates[0], end.coordinates[0], t);
    final double lat = _lerpDouble(begin.coordinates[1], end.coordinates[1], t);
    return GeoJSONPoint([lng, lat]);
  }
  
  /// Helper method to interpolate between two double values
  double _lerpDouble(double begin, double end, double t) {
    return begin + (end - begin) * t;
  }
  
  /// Checks if two lists of GeoJSONPoint objects are identical
  bool _areListsIdentical(List<GeoJSONPoint> list1, List<GeoJSONPoint> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].coordinates[0] != list2[i].coordinates[0] ||
          list1[i].coordinates[1] != list2[i].coordinates[1]) {
        return false;
      }
    }
    
    return true;
  }
}
