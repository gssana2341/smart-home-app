class SensorData {
  final double temperature;
  final double humidity;
  final int gasLevel;
  final DateTime timestamp;

  SensorData({
    required this.temperature,
    required this.humidity,
    required this.gasLevel,
    required this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      humidity: (json['humidity'] ?? 0.0).toDouble(),
      gasLevel: json['gas_level'] ?? json['gasLevel'] ?? 0,  // รองรับทั้ง snake_case และ camelCase
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'gasLevel': gasLevel,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  SensorData copyWith({
    double? temperature,
    double? humidity,
    int? gasLevel,
    DateTime? timestamp,
  }) {
    return SensorData(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      gasLevel: gasLevel ?? this.gasLevel,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'SensorData(temperature: $temperature, humidity: $humidity, gasLevel: $gasLevel, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SensorData &&
        other.temperature == temperature &&
        other.humidity == humidity &&
        other.gasLevel == gasLevel &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return temperature.hashCode ^
        humidity.hashCode ^
        gasLevel.hashCode ^
        timestamp.hashCode;
  }
}
