import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppHelpers {
  // Date and time formatting
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  static String formatDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  static String formatDateTimeShort(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'เมื่อสักครู่';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} วันที่แล้ว';
    } else {
      return formatDate(dateTime);
    }
  }

  // Number formatting
  static String formatTemperature(double temperature) {
    return '${temperature.toStringAsFixed(1)}°C';
  }

  static String formatHumidity(double humidity) {
    return '${humidity.toStringAsFixed(1)}%';
  }

  static String formatGasLevel(int gasLevel) {
    return '$gasLevel ppm';
  }

  static String formatNumber(double number, {int decimals = 1}) {
    return number.toStringAsFixed(decimals);
  }

  // Color helpers
  static Color getTemperatureColor(double temperature) {
    if (temperature < 20) {
      return Colors.blue;
    } else if (temperature < 30) {
      return Colors.green;
    } else if (temperature < 40) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  static Color getHumidityColor(double humidity) {
    if (humidity < 30) {
      return Colors.orange;
    } else if (humidity < 70) {
      return Colors.green;
    } else {
      return Colors.blue;
    }
  }

  static Color getGasLevelColor(int gasLevel) {
    if (gasLevel < 100) {
      return Colors.green;
    } else if (gasLevel < 300) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  static Color getStatusColor(bool isOnline) {
    return isOnline ? Colors.green : Colors.red;
  }

  // Status helpers
  static String getConnectionStatus(bool isOnline) {
    return isOnline ? 'เชื่อมต่อ' : 'ไม่เชื่อมต่อ';
  }

  static String getDeviceStatus(bool isOn) {
    return isOn ? 'เปิด' : 'ปิด';
  }

  static String getTemperatureStatus(double temperature) {
    if (temperature < 20) {
      return 'เย็น';
    } else if (temperature < 30) {
      return 'ปกติ';
    } else if (temperature < 40) {
      return 'ร้อน';
    } else {
      return 'ร้อนมาก';
    }
  }

  static String getHumidityStatus(double humidity) {
    if (humidity < 30) {
      return 'แห้ง';
    } else if (humidity < 70) {
      return 'ปกติ';
    } else {
      return 'ชื้น';
    }
  }

  static String getGasLevelStatus(int gasLevel) {
    if (gasLevel < 100) {
      return 'ปกติ';
    } else if (gasLevel < 300) {
      return 'ระวัง';
    } else {
      return 'อันตราย';
    }
  }

  // Validation helpers
  static bool isValidTemperature(double temperature) {
    return temperature >= -50 && temperature <= 100;
  }

  static bool isValidHumidity(double humidity) {
    return humidity >= 0 && humidity <= 100;
  }

  static bool isValidGasLevel(int gasLevel) {
    return gasLevel >= 0 && gasLevel <= 1000;
  }

  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  static bool isValidPort(int port) {
    return port > 0 && port <= 65535;
  }

  // Message helpers
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? theme.colorScheme.error : theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static void showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showConfirmDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  // Loading overlay
  static void showLoadingOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  static void hideLoadingOverlay(BuildContext context) {
    Navigator.of(context).pop();
  }

  // Animation helpers
  static Animation<double> createFadeAnimation(
    AnimationController controller, {
    double begin = 0.0,
    double end = 1.0,
    Curve curve = Curves.easeInOut,
  }) {
    return Tween<double>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: curve,
    ));
  }

  static Animation<Offset> createSlideAnimation(
    AnimationController controller, {
    Offset begin = const Offset(0.0, 1.0),
    Offset end = Offset.zero,
    Curve curve = Curves.easeInOut,
  }) {
    return Tween<Offset>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: curve,
    ));
  }

  // Network helpers
  static Map<String, String> getDefaultHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // Chart helpers
  static List<Color> getChartColors() {
    return [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFFF44336), // Red
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF00BCD4), // Cyan
    ];
  }

  // Device icon helpers
  static IconData getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'light':
        return Icons.lightbulb;
      case 'fan':
        return Icons.air;
      case 'air_conditioner':
      case 'ac':
        return Icons.ac_unit;
      case 'water_pump':
      case 'pump':
        return Icons.water;
      case 'heater':
        return Icons.local_fire_department;
      case 'extra_device':
        return Icons.device_hub;
      case 'temperature':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'gas':
        return Icons.sensors;
      default:
        return Icons.device_unknown;
    }
  }

  // Storage helpers
  static String encodeJson(Map<String, dynamic> data) {
    return data.toString();
  }

  static Map<String, dynamic>? decodeJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      // Simple JSON parsing - in real app use dart:convert
      return <String, dynamic>{};
    } catch (e) {
      return null;
    }
  }
}
