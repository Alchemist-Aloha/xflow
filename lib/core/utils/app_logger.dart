import 'package:flutter/foundation.dart';

class AppLogger {
  static final List<String> _logs = [];
  static const int _maxLogs = 1000;

  static List<String> get logs => List.unmodifiable(_logs);

  static void log(String message) {
    final timestamp = DateTime.now().toString().split('.').first;
    final logEntry = '[$timestamp] $message';
    
    _logs.add(logEntry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    
    debugPrint(logEntry);
  }

  static void clear() {
    _logs.clear();
  }
}
