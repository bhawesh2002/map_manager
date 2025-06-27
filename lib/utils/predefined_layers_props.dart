import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

const Map<String, dynamic> routeLayerProps = {
  'lineWidth': 8.0,
  'lineCap': LineCap.ROUND,
  'lineJoin': LineJoin.ROUND,
  'lineOpacity': 0.9,
  'lineGradientExpression': [
    'interpolate',
    ['linear'],
    ['line-progress'],
    0.0,
    "#0BE3E3",
    0.4,
    "#0B69E3",
    0.6,
    "#0B4CE3",
    1.0,
    "#890BE3",
  ],
  'lineBlur': 0.0,
  'lineZOffset': -1.0
};

const Map<String, dynamic> userLayerProps = {
  'circleRadius': 8,
  'circleColor': 0xFF0078D4,
  'circleStrokeWidth': 4.0,
  'circleStrokeColor': 0xFFFFFFFF,
  'circlePitchAlignment': CirclePitchAlignment.MAP,
};

String personLayerProps(String iconImg) =>
    (_personSymbolLayerPropsMap['iconImage'] = iconImg).toString();

const Map<String, dynamic> _personSymbolLayerPropsMap = {
  'iconSize': 0.45,
  'iconOffset': [0, -64],
};
