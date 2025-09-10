import 'automation_condition.dart';
import 'automation_action.dart';

class AutomationRule {
  final String id;
  final String name;
  final String description;
  final List<AutomationCondition> conditions;
  final List<AutomationAction> actions;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? lastTriggered;
  final int triggerCount;
  final String? category; // temperature, humidity, gas, time, combined

  AutomationRule({
    required this.id,
    required this.name,
    required this.description,
    required this.conditions,
    required this.actions,
    this.isEnabled = true,
    required this.createdAt,
    this.lastTriggered,
    this.triggerCount = 0,
    this.category,
  });

  factory AutomationRule.fromJson(Map<String, dynamic> json) {
    return AutomationRule(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      conditions: (json['conditions'] as List<dynamic>?)
          ?.map((c) => AutomationCondition.fromJson(c))
          .toList() ?? [],
      actions: (json['actions'] as List<dynamic>?)
          ?.map((a) => AutomationAction.fromJson(a))
          .toList() ?? [],
      isEnabled: json['isEnabled'] ?? true,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastTriggered: json['lastTriggered'] != null 
          ? DateTime.parse(json['lastTriggered'])
          : null,
      triggerCount: json['triggerCount'] ?? 0,
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'conditions': conditions.map((c) => c.toJson()).toList(),
      'actions': actions.map((a) => a.toJson()).toList(),
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'lastTriggered': lastTriggered?.toIso8601String(),
      'triggerCount': triggerCount,
      'category': category,
    };
  }

  AutomationRule copyWith({
    String? id,
    String? name,
    String? description,
    List<AutomationCondition>? conditions,
    List<AutomationAction>? actions,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? lastTriggered,
    int? triggerCount,
    String? category,
  }) {
    return AutomationRule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      triggerCount: triggerCount ?? this.triggerCount,
      category: category ?? this.category,
    );
  }

  @override
  String toString() {
    return 'AutomationRule(id: $id, name: $name, enabled: $isEnabled, triggers: $triggerCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AutomationRule &&
        other.id == id &&
        other.name == name &&
        other.isEnabled == isEnabled;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ isEnabled.hashCode;
  }

  // Helper methods
  String getCategoryDisplayName() {
    switch (category) {
      case 'temperature':
        return 'อุณหภูมิ';
      case 'humidity':
        return 'ความชื้น';
      case 'gas':
        return 'ก๊าซ';
      case 'time':
        return 'เวลา';
      case 'combined':
        return 'ผสม';
      default:
        return 'ทั่วไป';
    }
  }

  String getConditionsDisplayText() {
    if (conditions.isEmpty) return 'ไม่มีเงื่อนไข';
    
    if (conditions.length == 1) {
      return conditions.first.getDisplayText();
    }
    
    return '${conditions.length} เงื่อนไข';
  }

  String getActionsDisplayText() {
    if (actions.isEmpty) return 'ไม่มีการกระทำ';
    
    if (actions.length == 1) {
      return actions.first.getDisplayText();
    }
    
    return '${actions.length} การกระทำ';
  }

  String getLastTriggeredDisplayText() {
    if (lastTriggered == null) return 'ยังไม่เคยทำงาน';
    
    final now = DateTime.now();
    final difference = now.difference(lastTriggered!);
    
    if (difference.inMinutes < 1) {
      return 'เมื่อสักครู่';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else {
      return '${difference.inDays} วันที่แล้ว';
    }
  }

  // Check if rule is valid
  bool isValid() {
    if (id.isEmpty || name.isEmpty) return false;
    if (conditions.isEmpty || actions.isEmpty) return false;
    
    // Check if all conditions are valid
    for (final condition in conditions) {
      if (condition.sensorType.isEmpty || condition.operator.isEmpty) {
        return false;
      }
    }
    
    // Check if all actions are valid
    for (final action in actions) {
      if (!action.isValid()) {
        return false;
      }
    }
    
    return true;
  }

  // Get rule priority (higher number = higher priority)
  int getPriority() {
    int priority = 0;
    
    // Gas detection has highest priority
    if (conditions.any((c) => c.sensorType == 'gas')) {
      priority += 100;
    }
    
    // Temperature control has medium priority
    if (conditions.any((c) => c.sensorType == 'temperature')) {
      priority += 50;
    }
    
    // Humidity control has lower priority
    if (conditions.any((c) => c.sensorType == 'humidity')) {
      priority += 25;
    }
    
    // Time-based has lowest priority
    if (conditions.any((c) => c.sensorType == 'time')) {
      priority += 10;
    }
    
    // More conditions = higher priority
    priority += conditions.length * 5;
    
    return priority;
  }

  // Check if rule should be triggered based on current sensor data
  bool shouldTrigger({
    required double temperature,
    required double humidity,
    required int gasLevel,
    required DateTime currentTime,
  }) {
    if (!isEnabled || !isValid()) return false;
    
    // All conditions must be met (AND logic)
    for (final condition in conditions) {
      bool conditionMet = false;
      
      switch (condition.sensorType) {
        case 'temperature':
          conditionMet = condition.evaluateTemperature(temperature);
          break;
        case 'humidity':
          conditionMet = condition.evaluateHumidity(humidity);
          break;
        case 'gas':
          conditionMet = condition.evaluateGas(gasLevel);
          break;
        case 'time':
          conditionMet = condition.evaluateTime(currentTime);
          break;
        default:
          conditionMet = false;
      }
      
      if (!conditionMet) {
        return false;
      }
    }
    
    return true;
  }
}
