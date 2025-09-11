# Map Manager

**Alpha Release v0.0.1**

A powerful Flutter package that provides an intuitive abstraction layer over mapbox_maps_flutter, offering a mode-based approach to handling different map functionalities with smooth animations and real-time tracking capabilities.

## 🌟 Features

### Core Functionality

- **Mode-Based Architecture**: Clean separation of map behaviors through different operational modes
- **Real-Time Location Tracking**: Smooth, animated location updates with intelligent route management
- **Advanced Route Handling**: Dynamic route calculation and visualization with traversal tracking
- **High-Performance Animations**: Optimized coordinate manipulation for smooth, lag-free animations
- **Comprehensive Logging**: Built-in logging system for debugging and monitoring

### Supported Map Modes

#### 1. **Basic Mode**

- Simple map display with optional user location tracking
- Clean foundation for custom map implementations

#### 2. **Location Selection Mode**

- Interactive point selection on the map
- Configurable maximum selections
- Pre-selection support
- Touch-based coordinate picking

#### 3. **Route Mode**

- Static route visualization
- Support for LineString and GeoJSON route formats
- Customizable route styling with gradients
- Waypoint management

#### 4. **Tracking Mode** ⭐ **(Flagship Feature)**

- Real-time GPS tracking with smooth animations
- Intelligent route shrinking as user progresses
- Dynamic off-route handling (adds detour segments)
- Queue-based location processing for consistent performance
- Animated marker movement with customizable tweening
- Live route traversal visualization

### Advanced Capabilities

- **Smart Route Calculation**: Efficient coordinate manipulation without expensive recalculations
- **Animation System**: Frame-based updates with configurable curves and timing
- **Error Handling**: Robust fallback mechanisms for edge cases
- **Performance Optimization**: Direct coordinate manipulation for 60fps animations
- **Flexible API**: Pattern matching and type-safe mode handling

## 🚀 Getting Started

### Prerequisites

- Flutter SDK >=3.5.4
- Mapbox account with valid access token
- Basic knowledge of Flutter and mapping concepts
- Add MAPBOX_API_KEY to env/debug.json and run the command

```cmd
flutter run --dart-define-from-file=.env/debug.json
```

### Installation

Add this to your package's `pubspec.yaml`:

```yaml
dependencies:
  map_manager_mapbox: ^0.0.1
  mapbox_maps_flutter: ^2.8.0
```

### Basic Setup

```dart
import 'package:map_manager_mapbox/map_manager_mapbox.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MyMapWidget extends StatefulWidget {
  @override
  _MyMapWidgetState createState() => _MyMapWidgetState();
}

class _MyMapWidgetState extends State<MyMapWidget>
    with TickerProviderStateMixin {
  MapManager? _mapManager;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey("mapWidget"),
      resourceOptions: ResourceOptions(
        accessToken: "YOUR_MAPBOX_ACCESS_TOKEN",
      ),
      onMapCreated: _onMapCreated,
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapManager = await MapManager.init(
      mapboxMap,
      _animationController,
      mode: MapMode.basic(),
    );
  }
}
```

## 📖 Usage Examples

### Location Selection Mode

```dart
// Switch to location selection mode
await _mapManager?.changeMode(
  MapMode.locationSel(
    maxSelections: 3,
    preSelectedLocs: [Point(coordinates: Position(-74.0060, 40.7128))],
  ),
);

// Access selected locations
_mapManager?.whenLocationMode((locMode) {
  print('Selected points: ${locMode.selectedPoints}');
});
```

### Route Visualization

```dart
// Display a static route
await _mapManager?.changeMode(
  MapMode.route(
    geojson: {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": [[-74.0060, 40.7128], [-73.9352, 40.7306]]
      }
    },
  ),
);
```

### Real-Time Tracking (Advanced)

```dart
// Start real-time tracking with route
await _mapManager?.changeMode(
  MapMode.tracking(
    geojson: routeGeoJson,
    waypoints: waypoints,
  ),
);

// Begin location tracking
_mapManager?.whenTrackingMode((trackingMode) async {
  await trackingMode.startTracking(locationUpdateNotifier);
});

// Use with location simulator for testing
final simulator = LocationSimulator(
  route: route,
  updateInterval: Duration(milliseconds: 500),
);
simulator.start();
```

### Pattern Matching API

```dart
// Handle different modes elegantly
_mapManager?.matchModeHandler(
  basic: (basicMode) => print('Basic mode active'),
  location: (locMode) => handleLocationSelection(locMode),
  route: (routeMode) => displayRouteInfo(routeMode),
  tracking: (trackingMode) => updateTrackingUI(trackingMode),
  orElse: () => print('Unknown mode'),
);
```

## 🏗️ Architecture

### Mode-Based Design

The package uses a clean mode-based architecture where each mode encapsulates specific map behaviors:

- **MapManager**: Central coordinator managing mode transitions
- **ModeHandler**: Abstract interface for mode-specific implementations
- **MapMode**: Sealed union type defining available modes
- **Animation System**: Centralized animation management with shared controllers

### Performance Optimizations

- **Direct Coordinate Manipulation**: Bypasses expensive route recalculations
- **Frame-Rate Control**: Configurable animation frame rates (default: every 3rd frame)
- **Queue-Based Processing**: Smooth handling of rapid location updates
- **Memory Efficient**: Minimal object allocation during animations

## 🔧 API Reference

### Core Classes

#### MapManager

- `changeMode(MapMode mode)`: Switch between operational modes
- `whenBasicMode()`, `whenLocationMode()`, `whenRouteMode()`, `whenTrackingMode()`: Type-safe mode access
- `matchModeHandler()`: Pattern matching for mode handling

#### MapMode (Sealed Union)

- `MapMode.basic()`: Basic map functionality
- `MapMode.locationSel()`: Interactive location selection
- `MapMode.route()`: Static route display
- `MapMode.tracking()`: Real-time tracking with animations

#### Utility Classes

- `LocationSimulator`: GPS simulation for testing and development
- `LocationUpdate`: Standardized location data structure
- `RouteUtils`: Advanced route calculation and manipulation functions

## 🧪 Testing & Development

The package includes comprehensive testing utilities:

```dart
// Use LocationSimulator for development
final simulator = LocationSimulator(
  route: testRoute,
  updateInterval: Duration(milliseconds: 100),
  speedVariation: 0.2, // 20% speed variation for realism
);

// Simulate realistic GPS tracking
simulator.start();
```

## 🗺️ Roadmap

### Upcoming Features

- **Custom Markers**: Advanced marker customization system
- **Multi User Tracking**: Tracking multiple locations

### Known Limitations (Alpha)

- Single route tracking (multi-route support planned)
- Limited customization options (expanding in beta)
- Basic error recovery (enhanced error handling in development)

## 🤝 Contributing

This is an alpha release. We welcome contributions, bug reports, and feature requests!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For questions, issues, or feature requests:

- Create an issue on GitHub
- Check the `/example` folder for comprehensive usage examples
- Review the API documentation

---

**Note**: This is an alpha release (v0.0.1). APIs may change in future versions. Use in production at your own discretion.
