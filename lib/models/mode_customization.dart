class TrackingModeCustomization {
  /// Local asset path for the user icon (e.g. 'assets/user.png')
  final String? userIconPath;

  /// Local asset path for the person icon
  final String? personIconPath;

  /// Mapbox style properties for user layer (SymbolLayer, ModelLayer, etc)
  final Map<String, dynamic>? userLayerProperties;

  /// Mapbox style properties for person layer
  final Map<String, dynamic>? personLayerProperties;

  /// Mapbox style properties for route layer (LineLayer)
  final Map<String, dynamic>? routeLayerProperties;

  const TrackingModeCustomization({
    this.userIconPath,
    this.personIconPath,
    this.userLayerProperties,
    this.personLayerProperties,
    this.routeLayerProperties,
  });
}
