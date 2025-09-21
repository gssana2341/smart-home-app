import 'package:flutter/foundation.dart';

class LogManager {
  static final LogManager _instance = LogManager._internal();
  factory LogManager() => _instance;
  LogManager._internal();

  // เก็บ logs ที่ซ้ำกัน
  final Map<String, int> _logCounts = {};
  final Map<String, DateTime> _lastLogTime = {};
  
  // ตั้งค่าการ deduplication
  static const Duration _deduplicationWindow = Duration(seconds: 1); // ลดจาก 2 เป็น 1 วินาที
  static const int _maxLogCount = 30; // ลดจาก 50 เป็น 30
  static const int _maxDuplicateCount = 100; // ลดจาก 1000 เป็น 100

  /// Log message พร้อม deduplication
  void log(String message, {String? category, LogLevel level = LogLevel.info}) {
    if (!kDebugMode) return;

    // กรอง logs ที่ไม่ต้องการ
    if (_shouldFilterLog(message)) return;

    final key = _generateLogKey(message, category);
    final now = DateTime.now();
    
    // ตรวจสอบว่าเป็น log เดิมหรือไม่
    if (_logCounts.containsKey(key)) {
      final lastTime = _lastLogTime[key]!;
      final timeDiff = now.difference(lastTime);
      
      if (timeDiff < _deduplicationWindow) {
        // เพิ่มจำนวนครั้ง
        _logCounts[key] = (_logCounts[key] ?? 0) + 1;
        _lastLogTime[key] = now;
        
        // แสดง log พร้อมจำนวนครั้ง (เฉพาะครั้งแรกและทุกๆ 3 ครั้ง)
        final count = _logCounts[key]!;
        if (count == 1 || count % 3 == 0) {
          _printLog(message, category, level, count);
        }
        
        // หยุดแสดง logs ที่ซ้ำกันมากเกินไป
        if (count >= _maxDuplicateCount) {
          return;
        }
        return;
      }
    }
    
    // Log ใหม่
    _logCounts[key] = 1;
    _lastLogTime[key] = now;
    _printLog(message, category, level, 1);
    
    // ทำความสะอาด logs เก่า
    _cleanupOldLogs();
  }

  /// Log error message
  void error(String message, {String? category, Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    
    final fullMessage = error != null ? '$message: $error' : message;
    log(fullMessage, category: category, level: LogLevel.error);
    
    if (stackTrace != null && kDebugMode) {
      print('StackTrace: $stackTrace');
    }
  }

  /// Log warning message
  void warning(String message, {String? category}) {
    log(message, category: category, level: LogLevel.warning);
  }

  /// Log info message
  void info(String message, {String? category}) {
    log(message, category: category, level: LogLevel.info);
  }

  /// Log debug message
  void debug(String message, {String? category}) {
    log(message, category: category, level: LogLevel.debug);
  }

  /// แสดง log พร้อม formatting
  void _printLog(String message, String? category, LogLevel level, int count) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final levelStr = level.name.toUpperCase().padRight(7);
    final categoryStr = category != null ? '[$category] ' : '';
    final countStr = count > 1 ? ' (x$count)' : '';
    
    final formattedMessage = '[$timestamp] $levelStr $categoryStr$message$countStr';
    
    // ใช้สีตาม level
    switch (level) {
      case LogLevel.error:
        print('\x1B[31m$formattedMessage\x1B[0m'); // แดง
        break;
      case LogLevel.warning:
        print('\x1B[33m$formattedMessage\x1B[0m'); // เหลือง
        break;
      case LogLevel.info:
        print('\x1B[36m$formattedMessage\x1B[0m'); // ฟ้า
        break;
      case LogLevel.debug:
        print('\x1B[37m$formattedMessage\x1B[0m'); // ขาว
        break;
    }
  }

  /// สร้าง key สำหรับ deduplication
  String _generateLogKey(String message, String? category) {
    return '${category ?? 'general'}:$message';
  }

  /// ทำความสะอาด logs เก่า
  void _cleanupOldLogs() {
    if (_logCounts.length > _maxLogCount) {
      final sortedKeys = _lastLogTime.entries
          .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
      
      final keysToRemove = sortedKeys
          .take(_logCounts.length - _maxLogCount)
          .map((e) => e.key)
          .toList();
      
      for (final key in keysToRemove) {
        _logCounts.remove(key);
        _lastLogTime.remove(key);
      }
    }
  }

  /// ล้าง logs ทั้งหมด
  void clear() {
    _logCounts.clear();
    _lastLogTime.clear();
  }

  /// ดูสถิติ logs
  Map<String, int> get logStats => Map.unmodifiable(_logCounts);
  
  /// ดูจำนวน logs ทั้งหมด
  int get totalLogs => _logCounts.length;

  /// กรอง logs ที่ไม่ต้องการ
  bool _shouldFilterLog(String message) {
    // กรอง logs ที่ซ้ำๆ จาก Flutter framework
    if (message.contains('DebugService: Error serving requests') ||
        message.contains('Cannot send Null') ||
        message.contains('Error serving requests') ||
        message.contains('DebugService:') ||
        message.contains('Unsupported operation')) {
      return true;
    }
    return false;
  }
}

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Global logger instance
final logger = LogManager();
