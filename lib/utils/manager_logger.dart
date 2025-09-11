import 'package:flutter/foundation.dart';

class ManagerLogger {
  final String name;

  ManagerLogger(this.name);

  void log(Object message, {Severity level = Severity.info}) {
    if (kDebugMode) {
      print("${level.name}:${DateTime.now().toIso8601String()}:$name:$message");
    }
  }

  void info(Object message) => log(message, level: Severity.info);
  void warning(Object message) => log(message, level: Severity.warning);
  void severe(Object message) => log(message, level: Severity.severe);
}

enum Severity { info, warning, severe }
