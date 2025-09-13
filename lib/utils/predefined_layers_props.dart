Map<String, dynamic> routeLayerProps = {
  'line-width': 6.0,
  'line-opacity': 1,
  'line-cap': "round",
  'line-join': "round",
  'line-gradient': [
    'interpolate',
    ['linear'],
    ['line-progress'],
    0.0,
    "#0BE3E3",
    0.6,
    "#0B4CE3",
    1.0,
    "#890BE3",
  ],
  'line-blur': 0.0,
  'line-z-offset': -1.0,
};

Map<String, dynamic> userLayerProps = {
  'circle-radius': 8,
  'circle-color': "#0078D4",
  'circle-stroke-width': 4.0,
  'circle-stroke-color': "#FFFFFF",
  'circle-pitch-alignment': "map",
};

Map<String, dynamic> personLayerProps(String iconImg) {
  _personSymbolLayerPropsMap['icon-image'] = iconImg;
  return _personSymbolLayerPropsMap;
}

Map<String, dynamic> _personSymbolLayerPropsMap = {
  'icon-size': 0.45,
  'icon-offset': [0, -64],
};
