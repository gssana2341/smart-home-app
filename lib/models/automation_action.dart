class AutomationAction {
  final String deviceType; // light, fan, air_conditioner, water_pump, heater, extra_device, notification
  final String action; // turn_on, turn_off, send_notification
  final Map<String, dynamic>? parameters;
  final int delay; // delay in seconds before executing
  final String? description;

  AutomationAction({
    required this.deviceType,
    required this.action,
    this.parameters,
    this.delay = 0,
    this.description,
  });

  factory AutomationAction.fromJson(Map<String, dynamic> json) {
    return AutomationAction(
      deviceType: json['deviceType'] ?? '',
      action: json['action'] ?? '',
      parameters: json['parameters'] != null 
          ? Map<String, dynamic>.from(json['parameters'])
          : null,
      delay: json['delay'] ?? 0,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceType': deviceType,
      'action': action,
      'parameters': parameters,
      'delay': delay,
      'description': description,
    };
  }

  AutomationAction copyWith({
    String? deviceType,
    String? action,
    Map<String, dynamic>? parameters,
    int? delay,
    String? description,
  }) {
    return AutomationAction(
      deviceType: deviceType ?? this.deviceType,
      action: action ?? this.action,
      parameters: parameters ?? this.parameters,
      delay: delay ?? this.delay,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return 'AutomationAction(deviceType: $deviceType, action: $action, delay: $delay)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AutomationAction &&
        other.deviceType == deviceType &&
        other.action == action &&
        other.delay == delay;
  }

  @override
  int get hashCode {
    return deviceType.hashCode ^
        action.hashCode ^
        delay.hashCode;
  }

  String getDisplayText() {
    final deviceName = _getDeviceDisplayName();
    final actionName = _getActionDisplayName();
    
    if (delay > 0) {
      return '$actionName $deviceName (รอ ${delay}วินาที)';
    }
    return '$actionName $deviceName';
  }

  String _getDeviceDisplayName() {
    switch (deviceType) {
      case 'light':
        return 'ไฟ';
      case 'fan':
        return 'พัดลม';
      case 'air_conditioner':
        return 'แอร์';
      case 'water_pump':
        return 'ปั๊มน้ำ';
      case 'heater':
        return 'ฮีทเตอร์';
      case 'extra_device':
        return 'อุปกรณ์เพิ่มเติม';
      case 'notification':
        return 'การแจ้งเตือน';
      default:
        return deviceType;
    }
  }

  String _getActionDisplayName() {
    switch (action) {
      case 'turn_on':
        return 'เปิด';
      case 'turn_off':
        return 'ปิด';
      case 'send_notification':
        return 'ส่ง';
      default:
        return action;
    }
  }

  // Helper method to get device relay name for MQTT/API control
  String? getRelayName() {
    switch (deviceType) {
      case 'light':
        return 'relay1';
      case 'fan':
        return 'relay2';
      case 'air_conditioner':
        return 'relay3';
      case 'water_pump':
        return 'relay4';
      case 'heater':
        return 'relay5';
      case 'extra_device':
        return 'relay6';
      default:
        return null;
    }
  }

  // Helper method to get command for MQTT/API
  String? getCommand() {
    if (deviceType == 'notification') {
      return action; // send_notification
    }
    
    final relayName = getRelayName();
    if (relayName == null) return null;
    
    switch (action) {
      case 'turn_on':
        switch (deviceType) {
          case 'light':
            return 'LIGHT_ON';
          case 'fan':
            return 'FAN_ON';
          case 'air_conditioner':
            return 'AC_ON';
          case 'water_pump':
            return 'PUMP_ON';
          case 'heater':
            return 'HEATER_ON';
          case 'extra_device':
            return 'EXTRA_ON';
        }
        break;
      case 'turn_off':
        switch (deviceType) {
          case 'light':
            return 'LIGHT_OFF';
          case 'fan':
            return 'FAN_OFF';
          case 'air_conditioner':
            return 'AC_OFF';
          case 'water_pump':
            return 'PUMP_OFF';
          case 'heater':
            return 'HEATER_OFF';
          case 'extra_device':
            return 'EXTRA_OFF';
        }
        break;
    }
    return null;
  }

  // Check if this action is valid
  bool isValid() {
    if (deviceType.isEmpty || action.isEmpty) return false;
    
    // Check if device type is supported
    final supportedDevices = [
      'light', 'fan', 'air_conditioner', 'water_pump', 
      'heater', 'extra_device', 'notification'
    ];
    
    if (!supportedDevices.contains(deviceType)) return false;
    
    // Check if action is supported for this device type
    if (deviceType == 'notification') {
      return action == 'send_notification';
    } else {
      return action == 'turn_on' || action == 'turn_off';
    }
  }
}
