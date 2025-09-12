import 'package:map_manager/map_manager.dart';

class MapModeException implements Exception {
  final String message;
  final MapMode currentMode;
  final MapMode expectedMode;

  MapModeException({
    required this.message,
    required this.currentMode,
    required this.expectedMode,
  });

  @override
  String toString() {
    return 'MapModeException: $message\nCurrent Mode: $currentMode\nExpected Mode: $expectedMode';
  }
}
