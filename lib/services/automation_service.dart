import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/automation_rule.dart';
import '../models/automation_condition.dart';
import '../models/automation_action.dart';
import '../models/device_status.dart';
import '../models/sensor_data.dart';
import 'storage_service.dart';
import 'mqtt_service.dart';
import 'api_service.dart';
import '../utils/log_manager.dart';

class AutomationService extends ChangeNotifier {
  final StorageService _storageService = StorageService.instance;
  final List<AutomationRule> _rules = [];
  final List<AutomationLog> _logs = [];
  
  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  DeviceStatus? _lastDeviceStatus;
  SensorData? _lastSensorData;
  
  // Stream controllers
  final StreamController<AutomationRule> _ruleTriggeredController = 
      StreamController<AutomationRule>.broadcast();
  final StreamController<AutomationLog> _logController = 
      StreamController<AutomationLog>.broadcast();

  // Getters
  List<AutomationRule> get rules => List.unmodifiable(_rules);
  List<AutomationLog> get logs => List.unmodifiable(_logs);
  bool get isMonitoring => _isMonitoring;
  
  // Streams
  Stream<AutomationRule> get ruleTriggeredStream => _ruleTriggeredController.stream;
  Stream<AutomationLog> get logStream => _logController.stream;

  AutomationService() {
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _loadRules();
      await _loadLogs();
      logger.info('AutomationService initialized with ${_rules.length} rules', category: 'AUTOMATION');
    } catch (e) {
      logger.error('Failed to initialize AutomationService', error: e, category: 'AUTOMATION');
    }
  }

  // Rule Management
  Future<void> _loadRules() async {
    try {
      final rulesJson = await _storageService.getAutomationRules();
      _rules.clear();
      _rules.addAll(rulesJson.map((json) => AutomationRule.fromJson(json)));
      notifyListeners();
    } catch (e) {
      logger.error('Failed to load automation rules', error: e, category: 'AUTOMATION');
    }
  }

  Future<void> _saveRules() async {
    try {
      final rulesJson = _rules.map((rule) => rule.toJson()).toList();
      await _storageService.saveAutomationRules(rulesJson);
    } catch (e) {
      logger.error('Failed to save automation rules', error: e, category: 'AUTOMATION');
    }
  }

  Future<void> addRule(AutomationRule rule) async {
    try {
      if (!rule.isValid()) {
        throw Exception('Invalid automation rule');
      }
      
      _rules.add(rule);
      await _saveRules();
      notifyListeners();
      
      logger.info('Added automation rule: ${rule.name}', category: 'AUTOMATION');
    } catch (e) {
      logger.error('Failed to add automation rule', error: e, category: 'AUTOMATION');
      rethrow;
    }
  }

  Future<void> updateRule(AutomationRule rule) async {
    try {
      if (!rule.isValid()) {
        throw Exception('Invalid automation rule');
      }
      
      final index = _rules.indexWhere((r) => r.id == rule.id);
      if (index == -1) {
        throw Exception('Rule not found');
      }
      
      _rules[index] = rule;
      await _saveRules();
      notifyListeners();
      
      logger.info('Updated automation rule: ${rule.name}', category: 'AUTOMATION');
    } catch (e) {
      logger.error('Failed to update automation rule', error: e, category: 'AUTOMATION');
      rethrow;
    }
  }

  Future<void> deleteRule(String ruleId) async {
    try {
      _rules.removeWhere((rule) => rule.id == ruleId);
      await _saveRules();
      notifyListeners();
      
      logger.info('Deleted automation rule: $ruleId', category: 'AUTOMATION');
    } catch (e) {
      logger.error('Failed to delete automation rule', error: e, category: 'AUTOMATION');
      rethrow;
    }
  }

  Future<void> toggleRule(String ruleId) async {
    try {
      final index = _rules.indexWhere((rule) => rule.id == ruleId);
      if (index == -1) {
        throw Exception('Rule not found');
      }
      
      final rule = _rules[index];
      _rules[index] = rule.copyWith(isEnabled: !rule.isEnabled);
      await _saveRules();
      notifyListeners();
      
      logger.info('Toggled automation rule: ${rule.name} (${!rule.isEnabled ? 'enabled' : 'disabled'})', category: 'AUTOMATION');
    } catch (e) {
      logger.error('Failed to toggle automation rule', error: e, category: 'AUTOMATION');
      rethrow;
    }
  }

  // Log Management
  Future<void> _loadLogs() async {
    try {
      final logsJson = await _storageService.getAutomationLogs();
      _logs.clear();
      _logs.addAll(logsJson.map((json) => AutomationLog.fromJson(json)));
      notifyListeners();
    } catch (e) {
      logger.error('Failed to load automation logs', error: e, category: 'AUTOMATION');
    }
  }

  Future<void> _saveLogs() async {
    try {
      final logsJson = _logs.map((log) => log.toJson()).toList();
      await _storageService.saveAutomationLogs(logsJson);
    } catch (e) {
      logger.error('Failed to save automation logs', error: e, category: 'AUTOMATION');
    }
  }

  Future<void> _addLog(AutomationLog log) async {
    try {
      _logs.insert(0, log); // Add to beginning
      
      // Keep only last 100 logs
      if (_logs.length > 100) {
        _logs.removeRange(100, _logs.length);
      }
      
      await _saveLogs();
      _logController.add(log);
      notifyListeners();
    } catch (e) {
      logger.error('Failed to add automation log', error: e, category: 'AUTOMATION');
    }
  }

  // Monitoring
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkRules();
    });
    
    logger.info('Started automation monitoring', category: 'AUTOMATION');
    notifyListeners();
  }

  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    
    logger.info('Stopped automation monitoring', category: 'AUTOMATION');
    notifyListeners();
  }

  void updateSensorData(DeviceStatus deviceStatus, SensorData? sensorData, {BuildContext? context}) {
    _lastDeviceStatus = deviceStatus;
    _lastSensorData = sensorData;
    
    // Check rules immediately when new data arrives
    if (_isMonitoring) {
      _checkRules(context: context);
    }
  }

  Future<void> _checkRules({BuildContext? context}) async {
    if (_lastDeviceStatus == null) return;
    
    final currentTime = DateTime.now();
    final temperature = _lastDeviceStatus!.temperature;
    final humidity = _lastDeviceStatus!.humidity;
    final gasLevel = _lastDeviceStatus!.gasLevel;
    
    // Group rules by device type to handle conflicts
    final rulesByDevice = <String, List<AutomationRule>>{};
    
    for (final rule in _rules) {
      if (!rule.isEnabled) continue;
      
      // Check if rule should trigger
      if (rule.shouldTrigger(
        temperature: temperature,
        humidity: humidity,
        gasLevel: gasLevel,
        currentTime: currentTime,
      )) {
        // Get device type from first action
        final deviceType = rule.actions.isNotEmpty ? rule.actions.first.deviceType : 'unknown';
        
        if (!rulesByDevice.containsKey(deviceType)) {
          rulesByDevice[deviceType] = [];
        }
        rulesByDevice[deviceType]!.add(rule);
      }
    }
    
    // Execute only the highest priority rule for each device
    for (final deviceType in rulesByDevice.keys) {
      final deviceRules = rulesByDevice[deviceType]!;
      
      if (deviceRules.length > 1) {
        logger.info('Found ${deviceRules.length} conflicting rules for $deviceType, using priority system', category: 'AUTOMATION');
      }
      
      // Sort by priority (highest first)
      deviceRules.sort((a, b) => b.getPriority().compareTo(a.getPriority()));
      
      // Execute only the highest priority rule
      final ruleToExecute = deviceRules.first;
      try {
        await _executeRule(ruleToExecute, currentTime, context: context);
        
        // Log skipped rules
        for (int i = 1; i < deviceRules.length; i++) {
          final skippedRule = deviceRules[i];
          logger.info('Skipped rule: ${skippedRule.name} (lower priority than ${ruleToExecute.name})', category: 'AUTOMATION');
          
          // Add log for skipped rule
          _addLog(AutomationLog(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            ruleId: skippedRule.id,
            ruleName: skippedRule.name,
            triggeredAt: currentTime,
            conditionsMet: skippedRule.conditions.map((c) => c.getDisplayText()).toList(),
            actionsExecuted: [],
            actionsFailed: [],
            success: false,
            errorMessage: 'Skipped due to higher priority rule: ${ruleToExecute.name}',
          ));
        }
      } catch (e) {
        logger.error('Error executing rule: ${ruleToExecute.name}', error: e, category: 'AUTOMATION');
      }
    }
  }

  Future<void> _executeRule(AutomationRule rule, DateTime triggeredAt, {BuildContext? context}) async {
    try {
      logger.info('Executing automation rule: ${rule.name}', category: 'AUTOMATION');
      
      // Update rule trigger count and last triggered time
      final updatedRule = rule.copyWith(
        lastTriggered: triggeredAt,
        triggerCount: rule.triggerCount + 1,
      );
      
      final index = _rules.indexWhere((r) => r.id == rule.id);
      if (index != -1) {
        _rules[index] = updatedRule;
        await _saveRules();
      }
      
      // Execute actions with delays
      final executedActions = <AutomationAction>[];
      final failedActions = <AutomationAction>[];
      
      for (final action in rule.actions) {
        try {
          if (action.delay > 0) {
            await Future.delayed(Duration(seconds: action.delay));
          }
          
          final success = await _executeAction(action, context: context);
          if (success) {
            executedActions.add(action);
          } else {
            failedActions.add(action);
          }
        } catch (e) {
          logger.error('Failed to execute action: ${action.getDisplayText()}', error: e, category: 'AUTOMATION');
          failedActions.add(action);
        }
      }
      
      // Create log entry
      final log = AutomationLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ruleId: rule.id,
        ruleName: rule.name,
        triggeredAt: triggeredAt,
        conditionsMet: rule.conditions.map((c) => c.getDisplayText()).toList(),
        actionsExecuted: executedActions.map((a) => a.getDisplayText()).toList(),
        actionsFailed: failedActions.map((a) => a.getDisplayText()).toList(),
        success: failedActions.isEmpty,
        errorMessage: failedActions.isNotEmpty ? 'Some actions failed' : null,
      );
      
      await _addLog(log);
      _ruleTriggeredController.add(updatedRule);
      
      logger.info('Automation rule executed: ${rule.name} (${executedActions.length}/${rule.actions.length} actions successful)', category: 'AUTOMATION');
      
    } catch (e) {
      logger.error('Failed to execute automation rule: ${rule.name}', error: e, category: 'AUTOMATION');
      
      // Create error log
      final log = AutomationLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ruleId: rule.id,
        ruleName: rule.name,
        triggeredAt: triggeredAt,
        conditionsMet: rule.conditions.map((c) => c.getDisplayText()).toList(),
        actionsExecuted: [],
        actionsFailed: rule.actions.map((a) => a.getDisplayText()).toList(),
        success: false,
        errorMessage: e.toString(),
      );
      
      await _addLog(log);
    }
  }

  Future<bool> _executeAction(AutomationAction action, {BuildContext? context}) async {
    try {
      if (action.deviceType == 'notification') {
        return await _sendNotification(action);
      }
      
      // Get command for device control
      final command = action.getCommand();
      if (command == null) {
        logger.error('Invalid command for action: ${action.getDisplayText()}', category: 'AUTOMATION');
        return false;
      }
      
      // Try MQTT first, then API
      if (context != null) {
        final mqttService = Provider.of<MqttService>(context, listen: false);
        if (mqttService.isConnected) {
          final success = await mqttService.publishCommand(command);
          if (success) {
            logger.info('Action executed via MQTT: ${action.getDisplayText()}', category: 'AUTOMATION');
            return true;
          }
        }
        
        // Fallback to API
        final apiService = Provider.of<ApiService>(context, listen: false);
        if (apiService.isConnected) {
          // Execute via API based on device type
          bool success = false;
          final isTurnOn = action.action == 'turn_on';
          
          switch (action.deviceType) {
            case 'light':
              success = await apiService.controlLight(isTurnOn);
              break;
            case 'fan':
              success = await apiService.controlFan(isTurnOn);
              break;
            case 'air_conditioner':
              success = await apiService.controlAirConditioner(isTurnOn);
              break;
            case 'water_pump':
              success = await apiService.controlWaterPump(isTurnOn);
              break;
            case 'heater':
              success = await apiService.controlHeater(isTurnOn);
              break;
            case 'extra_device':
              success = await apiService.controlExtraDevice(isTurnOn);
              break;
          }
          
          if (success) {
            logger.info('Action executed via API: ${action.getDisplayText()}', category: 'AUTOMATION');
            return true;
          }
        }
      }
      
      logger.error('Failed to execute action: ${action.getDisplayText()}', category: 'AUTOMATION');
      return false;
      
    } catch (e) {
      logger.error('Error executing action: ${action.getDisplayText()}', error: e, category: 'AUTOMATION');
      return false;
    }
  }

  Future<bool> _sendNotification(AutomationAction action) async {
    try {
      final message = action.parameters?['message'] ?? 'Automation notification';
      
      // This would integrate with your notification system
      logger.info('Notification sent: $message', category: 'AUTOMATION');
      
      return true;
    } catch (e) {
      logger.error('Failed to send notification', error: e, category: 'AUTOMATION');
      return false;
    }
  }

  // Utility methods
  List<AutomationRule> getRulesByCategory(String category) {
    return _rules.where((rule) => rule.category == category).toList();
  }

  List<AutomationRule> getEnabledRules() {
    return _rules.where((rule) => rule.isEnabled).toList();
  }

  List<AutomationRule> getDisabledRules() {
    return _rules.where((rule) => !rule.isEnabled).toList();
  }

  void enableAllRules() {
    for (final rule in _rules) {
      if (!rule.isEnabled) {
        toggleRule(rule.id);
      }
    }
  }

  void disableAllRules() {
    for (final rule in _rules) {
      if (rule.isEnabled) {
        toggleRule(rule.id);
      }
    }
  }

  void deleteAllRules() {
    _rules.clear();
    _saveRules();
    notifyListeners();
  }

  List<AutomationLog> getLogsByRule(String ruleId) {
    return _logs.where((log) => log.ruleId == ruleId).toList();
  }

  void clearLogs() {
    _logs.clear();
    _saveLogs();
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    _ruleTriggeredController.close();
    _logController.close();
    super.dispose();
  }
}

// Automation Log Model
class AutomationLog {
  final String id;
  final String ruleId;
  final String ruleName;
  final DateTime triggeredAt;
  final List<String> conditionsMet;
  final List<String> actionsExecuted;
  final List<String> actionsFailed;
  final bool success;
  final String? errorMessage;

  AutomationLog({
    required this.id,
    required this.ruleId,
    required this.ruleName,
    required this.triggeredAt,
    required this.conditionsMet,
    required this.actionsExecuted,
    required this.actionsFailed,
    required this.success,
    this.errorMessage,
  });

  factory AutomationLog.fromJson(Map<String, dynamic> json) {
    return AutomationLog(
      id: json['id'] ?? '',
      ruleId: json['ruleId'] ?? '',
      ruleName: json['ruleName'] ?? '',
      triggeredAt: DateTime.parse(json['triggeredAt']),
      conditionsMet: List<String>.from(json['conditionsMet'] ?? []),
      actionsExecuted: List<String>.from(json['actionsExecuted'] ?? []),
      actionsFailed: List<String>.from(json['actionsFailed'] ?? []),
      success: json['success'] ?? false,
      errorMessage: json['errorMessage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ruleId': ruleId,
      'ruleName': ruleName,
      'triggeredAt': triggeredAt.toIso8601String(),
      'conditionsMet': conditionsMet,
      'actionsExecuted': actionsExecuted,
      'actionsFailed': actionsFailed,
      'success': success,
      'errorMessage': errorMessage,
    };
  }
}
