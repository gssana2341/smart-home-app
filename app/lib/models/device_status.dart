class DeviceStatus {
  final double temperature;
  final double humidity;
  final int gasLevel;
  final bool relay1; // ไฟ
  final bool relay2; // พัดลม
  final bool relay3; // แอร์
  final bool relay4; // ปั๊มน้ำ
  final bool relay5; // ฮีทเตอร์
  final bool relay6; // อุปกรณ์เพิ่มเติม
  final bool online;
  final DateTime lastSeen;

  DeviceStatus({
    required this.temperature,
    required this.humidity,
    required this.gasLevel,
    required this.relay1,
    required this.relay2,
    required this.relay3,
    required this.relay4,
    required this.relay5,
    required this.relay6,
    required this.online,
    required this.lastSeen,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      humidity: (json['humidity'] ?? 0.0).toDouble(),
      gasLevel: json['gas_level'] ?? json['gasLevel'] ?? 0,  // รองรับทั้ง snake_case และ camelCase
      relay1: json['relay1'] ?? false,
      relay2: json['relay2'] ?? false,
      relay3: json['relay3'] ?? false,
      relay4: json['relay4'] ?? false,
      relay5: json['relay5'] ?? false,
      relay6: json['relay6'] ?? false,
      online: json['online'] ?? false,
      lastSeen: json['last_seen'] != null 
          ? DateTime.parse(json['last_seen'])
          : (json['lastSeen'] != null 
              ? DateTime.parse(json['lastSeen'])
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'gasLevel': gasLevel,
      'relay1': relay1,
      'relay2': relay2,
      'relay3': relay3,
      'relay4': relay4,
      'relay5': relay5,
      'relay6': relay6,
      'online': online,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  DeviceStatus copyWith({
    double? temperature,
    double? humidity,
    int? gasLevel,
    bool? relay1,
    bool? relay2,
    bool? relay3,
    bool? relay4,
    bool? relay5,
    bool? relay6,
    bool? online,
    DateTime? lastSeen,
  }) {
    return DeviceStatus(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      gasLevel: gasLevel ?? this.gasLevel,
      relay1: relay1 ?? this.relay1,
      relay2: relay2 ?? this.relay2,
      relay3: relay3 ?? this.relay3,
      relay4: relay4 ?? this.relay4,
      relay5: relay5 ?? this.relay5,
      relay6: relay6 ?? this.relay6,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  String toString() {
    return 'DeviceStatus(temperature: $temperature, humidity: $humidity, gasLevel: $gasLevel, relay1: $relay1, relay2: $relay2, relay3: $relay3, relay4: $relay4, relay5: $relay5, relay6: $relay6, online: $online, lastSeen: $lastSeen)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceStatus &&
        other.temperature == temperature &&
        other.humidity == humidity &&
        other.gasLevel == gasLevel &&
        other.relay1 == relay1 &&
        other.relay2 == relay2 &&
        other.relay3 == relay3 &&
        other.relay4 == relay4 &&
        other.relay5 == relay5 &&
        other.relay6 == relay6 &&
        other.online == online &&
        other.lastSeen == lastSeen;
  }

  @override
  int get hashCode {
    return temperature.hashCode ^
        humidity.hashCode ^
        gasLevel.hashCode ^
        relay1.hashCode ^
        relay2.hashCode ^
        relay3.hashCode ^
        relay4.hashCode ^
        relay5.hashCode ^
        relay6.hashCode ^
        online.hashCode ^
        lastSeen.hashCode;
  }
}
