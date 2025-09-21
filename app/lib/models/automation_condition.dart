class AutomationCondition {
  final String sensorType; // temperature, humidity, gas, time
  final String operator; // >, <, ==, >=, <=, between
  final double value;
  final Duration? timeWindow;
  final String? timeCondition; // "between", "after", "before"
  final String? description;

  AutomationCondition({
    required this.sensorType,
    required this.operator,
    required this.value,
    this.timeWindow,
    this.timeCondition,
    this.description,
  });

  factory AutomationCondition.fromJson(Map<String, dynamic> json) {
    return AutomationCondition(
      sensorType: json['sensorType'] ?? '',
      operator: json['operator'] ?? '',
      value: (json['value'] ?? 0.0).toDouble(),
      timeWindow: json['timeWindow'] != null 
          ? Duration(seconds: json['timeWindow'])
          : null,
      timeCondition: json['timeCondition'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sensorType': sensorType,
      'operator': operator,
      'value': value,
      'timeWindow': timeWindow?.inSeconds,
      'timeCondition': timeCondition,
      'description': description,
    };
  }

  AutomationCondition copyWith({
    String? sensorType,
    String? operator,
    double? value,
    Duration? timeWindow,
    String? timeCondition,
    String? description,
  }) {
    return AutomationCondition(
      sensorType: sensorType ?? this.sensorType,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      timeWindow: timeWindow ?? this.timeWindow,
      timeCondition: timeCondition ?? this.timeCondition,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return 'AutomationCondition(sensorType: $sensorType, operator: $operator, value: $value, timeCondition: $timeCondition)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AutomationCondition &&
        other.sensorType == sensorType &&
        other.operator == operator &&
        other.value == value &&
        other.timeCondition == timeCondition;
  }

  @override
  int get hashCode {
    return sensorType.hashCode ^
        operator.hashCode ^
        value.hashCode ^
        timeCondition.hashCode;
  }

  // Helper methods for condition evaluation
  bool evaluateTemperature(double currentTemp) {
    switch (operator) {
      case '>':
        return currentTemp > value;
      case '<':
        return currentTemp < value;
      case '>=':
        return currentTemp >= value;
      case '<=':
        return currentTemp <= value;
      case '==':
        return (currentTemp - value).abs() < 0.1;
      default:
        return false;
    }
  }

  bool evaluateHumidity(double currentHumidity) {
    switch (operator) {
      case '>':
        return currentHumidity > value;
      case '<':
        return currentHumidity < value;
      case '>=':
        return currentHumidity >= value;
      case '<=':
        return currentHumidity <= value;
      case '==':
        return (currentHumidity - value).abs() < 0.1;
      default:
        return false;
    }
  }

  bool evaluateGas(int currentGas) {
    switch (operator) {
      case '>':
        return currentGas > value;
      case '<':
        return currentGas < value;
      case '>=':
        return currentGas >= value;
      case '<=':
        return currentGas <= value;
      case '==':
        return (currentGas - value).abs() < 1;
      default:
        return false;
    }
  }

  bool evaluateTime(DateTime currentTime) {
    if (timeCondition == null) return false;
    
    final hour = currentTime.hour;
    final minute = currentTime.minute;
    final currentTimeInMinutes = hour * 60 + minute;
    
    switch (timeCondition) {
      case 'between':
        // Format: "08:00-18:00"
        if (description != null && description!.contains('-')) {
          final parts = description!.split('-');
          if (parts.length == 2) {
            final startTime = _parseTime(parts[0].trim());
            final endTime = _parseTime(parts[1].trim());
            return currentTimeInMinutes >= startTime && currentTimeInMinutes <= endTime;
          }
        }
        return false;
      case 'after':
        final targetTime = _parseTime(description ?? '00:00');
        return currentTimeInMinutes >= targetTime;
      case 'before':
        final targetTime = _parseTime(description ?? '23:59');
        return currentTimeInMinutes <= targetTime;
      default:
        return false;
    }
  }

  int _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return hour * 60 + minute;
    }
    return 0;
  }

  String getDisplayText() {
    switch (sensorType) {
      case 'temperature':
        return 'อุณหภูมิ $operator ${value.toStringAsFixed(1)}°C';
      case 'humidity':
        return 'ความชื้น $operator ${value.toStringAsFixed(1)}%';
      case 'gas':
        return 'ระดับก๊าซ $operator ${value.toInt()}';
      case 'time':
        if (timeCondition == 'between' && description != null) {
          return 'เวลา $description';
        } else if (timeCondition == 'after' && description != null) {
          return 'หลังเวลา $description';
        } else if (timeCondition == 'before' && description != null) {
          return 'ก่อนเวลา $description';
        }
        return 'เวลา $operator ${value.toStringAsFixed(1)}';
      default:
        return '$sensorType $operator $value';
    }
  }
}
