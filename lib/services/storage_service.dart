import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_message.dart';
import '../models/sensor_data.dart';
import '../models/device_status.dart';
import '../models/automation_rule.dart';
import '../utils/constants.dart';

class StorageService extends ChangeNotifier {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  
  StorageService._();

  SharedPreferences? _prefs;
  Database? _database;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // Initialize storage
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      
      // Initialize SQLite database (comment out for now to avoid complex issues)
      // await _initializeDatabase();
      
      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Storage initialization error: $e');
      }
      _isInitialized = false;
      return false;
    }
  }

  // Initialize SQLite database
  Future<void> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, StorageConstants.databaseName);

    _database = await openDatabase(
      path,
      version: StorageConstants.databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  // Create database tables
  Future<void> _createDatabase(Database db, int version) async {
    // Chat messages table
    await db.execute('''
      CREATE TABLE ${StorageConstants.chatMessagesTable} (
        id TEXT PRIMARY KEY,
        message TEXT NOT NULL,
        reply TEXT,
        timestamp TEXT NOT NULL,
        isUser INTEGER NOT NULL,
        isTyping INTEGER DEFAULT 0,
        hasError INTEGER DEFAULT 0
      )
    ''');

    // Sensor data table
    await db.execute('''
      CREATE TABLE ${StorageConstants.sensorDataTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        temperature REAL NOT NULL,
        humidity REAL NOT NULL,
        gasLevel INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // Device logs table
    await db.execute('''
      CREATE TABLE ${StorageConstants.deviceLogsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deviceType TEXT NOT NULL,
        action TEXT NOT NULL,
        status TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        data TEXT
      )
    ''');

    // Create indexes for better performance
    await db.execute('''
      CREATE INDEX idx_chat_timestamp 
      ON ${StorageConstants.chatMessagesTable}(timestamp DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_sensor_timestamp 
      ON ${StorageConstants.sensorDataTable}(timestamp DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_device_logs_timestamp 
      ON ${StorageConstants.deviceLogsTable}(timestamp DESC)
    ''');
  }

  // Upgrade database schema
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades
    if (oldVersion < newVersion) {
      // Add migration logic here if needed
      if (kDebugMode) {
        print('Database upgraded from version $oldVersion to $newVersion');
      }
    }
  }

  // SharedPreferences methods
  Future<void> setString(String key, String value) async {
    try {
      await _prefs?.setString(key, value);
    } catch (e) {
      print('setString error: $e');
    }
  }

  String? getString(String key, {String? defaultValue}) {
    try {
      return _prefs?.getString(key) ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  int? getInt(String key, {int? defaultValue}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  bool? getBool(String key, {bool? defaultValue}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  Future<void> setDouble(String key, double value) async {
    await _prefs?.setDouble(key, value);
  }

  double? getDouble(String key, {double? defaultValue}) {
    return _prefs?.getDouble(key) ?? defaultValue;
  }

  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  Future<void> clear() async {
    await _prefs?.clear();
  }

  // App settings methods
  Future<void> setServerUrl(String url) async {
    await setString(StorageConstants.serverUrlKey, url);
  }

  String getServerUrl() {
    try {
      return getString(StorageConstants.serverUrlKey, 
          defaultValue: ApiConstants.baseUrl) ?? ApiConstants.baseUrl;
    } catch (e) {
      return ApiConstants.baseUrl;
    }
  }

  Future<void> setMqttHost(String host) async {
    await setString(StorageConstants.mqttHostKey, host);
  }

  String getMqttHost() {
    return getString(StorageConstants.mqttHostKey, 
        defaultValue: MqttConstants.brokerHost) ?? MqttConstants.brokerHost;
  }

  Future<void> setMqttPort(int port) async {
    await setInt(StorageConstants.mqttPortKey, port);
  }

  int getMqttPort() {
    return getInt(StorageConstants.mqttPortKey, 
        defaultValue: MqttConstants.brokerPort) ?? MqttConstants.brokerPort;
  }

  Future<void> setAppTheme(String theme) async {
    await setString(StorageConstants.appThemeKey, theme);
  }

  String getAppTheme() {
    try {
      if (!_isInitialized || _prefs == null) return 'system';
      return getString(StorageConstants.appThemeKey, defaultValue: 'system') ?? 'system';
    } catch (e) {
      return 'system';
    }
  }

  // Control mode (API or MQTT)
  String getControlMode() {
    try {
      if (!_isInitialized || _prefs == null) return 'api';
      return getString(StorageConstants.controlModeKey, defaultValue: 'api') ?? 'api';
    } catch (e) {
      return 'api';
    }
  }

  Future<void> setControlMode(String mode) async {
    await setString(StorageConstants.controlModeKey, mode);
    notifyListeners();
  }

  Future<void> setNotificationEnabled(bool enabled) async {
    await setBool(StorageConstants.notificationEnabledKey, enabled);
  }

  bool getNotificationEnabled() {
    return getBool(StorageConstants.notificationEnabledKey, defaultValue: true) ?? true;
  }

  Future<void> setAutoRefresh(bool enabled) async {
    await setBool(StorageConstants.autoRefreshKey, enabled);
  }

  bool getAutoRefresh() {
    return getBool(StorageConstants.autoRefreshKey, defaultValue: true) ?? true;
  }

  Future<void> setRefreshInterval(int seconds) async {
    await setInt(StorageConstants.refreshIntervalKey, seconds);
  }

  int getRefreshInterval() {
    return getInt(StorageConstants.refreshIntervalKey, 
        defaultValue: AppConstants.defaultRefreshInterval) ?? AppConstants.defaultRefreshInterval;
  }

  Future<void> setLastUpdate(DateTime dateTime) async {
    await setString(StorageConstants.lastUpdateKey, dateTime.toIso8601String());
  }

  DateTime? getLastUpdate() {
    final dateStr = getString(StorageConstants.lastUpdateKey);
    return dateStr != null ? DateTime.tryParse(dateStr) : null;
  }

  Future<void> saveDeviceStatus(DeviceStatus status) async {
    await setString(StorageConstants.deviceStatusKey, jsonEncode(status.toJson()));
  }

  DeviceStatus? getDeviceStatus() {
    final statusStr = getString(StorageConstants.deviceStatusKey);
    if (statusStr != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(statusStr);
        return DeviceStatus.fromJson(json);
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing device status: $e');
        }
      }
    }
    return null;
  }

  // Chat messages database methods
  Future<void> saveChatMessage(ChatMessage message) async {
    try {
      if (_database == null) {
        print('Database not initialized, saving to memory only');
        return;
      }

      await _database!.insert(
        StorageConstants.chatMessagesTable,
        {
          'id': message.id,
          'message': message.message,
          'response': message.response,
          'timestamp': message.timestamp.toIso8601String(),
          'isUser': message.isUser ? 1 : 0,
          'isError': message.isError ? 1 : 0,
          'errorMessage': message.errorMessage,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Save chat message error: $e');
    }
  }

  Future<List<ChatMessage>> getChatMessages({int? limit}) async {
    if (_database == null) return [];

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        StorageConstants.chatMessagesTable,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return maps.map((map) => ChatMessage.fromJson({
        'id': map['id'],
        'message': map['message'],
        'reply': map['reply'],
        'timestamp': map['timestamp'],
        'isUser': map['isUser'] == 1,
        'isTyping': map['isTyping'] == 1,
        'hasError': map['hasError'] == 1,
      })).toList().reversed.toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting chat messages: $e');
      }
      return [];
    }
  }

  Future<void> deleteChatMessage(String id) async {
    if (_database == null) return;

    await _database!.delete(
      StorageConstants.chatMessagesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearChatMessages() async {
    if (_database == null) return;

    await _database!.delete(StorageConstants.chatMessagesTable);
  }

  // Sensor data database methods
  Future<void> saveSensorData(SensorData data) async {
    if (_database == null) return;

    await _database!.insert(
      StorageConstants.sensorDataTable,
      {
        'temperature': data.temperature,
        'humidity': data.humidity,
        'gasLevel': data.gasLevel,
        'timestamp': data.timestamp.toIso8601String(),
      },
    );

    // Keep only the latest records (limit to maxChartDataPoints)
    await _cleanupOldSensorData();
  }

  Future<List<SensorData>> getSensorData({int? limit}) async {
    if (_database == null) return [];

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        StorageConstants.sensorDataTable,
        orderBy: 'timestamp DESC',
        limit: limit ?? AppConstants.maxChartDataPoints,
      );

      return maps.map((map) => SensorData.fromJson({
        'temperature': map['temperature'],
        'humidity': map['humidity'],
        'gasLevel': map['gasLevel'],
        'timestamp': map['timestamp'],
      })).toList().reversed.toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting sensor data: $e');
      }
      return [];
    }
  }

  Future<void> _cleanupOldSensorData() async {
    if (_database == null) return;

    try {
      final count = Sqflite.firstIntValue(await _database!.rawQuery(
        'SELECT COUNT(*) FROM ${StorageConstants.sensorDataTable}'
      )) ?? 0;

      if (count > AppConstants.maxChartDataPoints) {
        await _database!.rawDelete('''
          DELETE FROM ${StorageConstants.sensorDataTable} 
          WHERE id NOT IN (
            SELECT id FROM ${StorageConstants.sensorDataTable} 
            ORDER BY timestamp DESC 
            LIMIT ${AppConstants.maxChartDataPoints}
          )
        ''');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up sensor data: $e');
      }
    }
  }

  // Device logs methods
  Future<void> logDeviceAction({
    required String deviceType,
    required String action,
    required String status,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (_database == null) {
        print('Device action logged: $deviceType $action $status');
        return;
      }

      await _database!.insert(
        StorageConstants.deviceLogsTable,
        {
          'deviceType': deviceType,
          'action': action,
          'status': status,
          'timestamp': DateTime.now().toIso8601String(),
          'data': data != null ? jsonEncode(data) : null,
        },
      );
    } catch (e) {
      print('Log device action error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDeviceLogs({int? limit}) async {
    if (_database == null) return [];

    try {
      return await _database!.query(
        StorageConstants.deviceLogsTable,
        orderBy: 'timestamp DESC',
        limit: limit ?? 100,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting device logs: $e');
      }
      return [];
    }
  }

  // Cleanup methods
  Future<void> clearAllData() async {
    await clear(); // Clear SharedPreferences
    
    if (_database != null) {
      await _database!.delete(StorageConstants.chatMessagesTable);
      await _database!.delete(StorageConstants.sensorDataTable);
      await _database!.delete(StorageConstants.deviceLogsTable);
    }
  }

  // Automation Rules Storage
  Future<List<Map<String, dynamic>>> getAutomationRules() async {
    try {
      if (_prefs == null) return [];
      
      final rulesJson = _prefs!.getString('automation_rules');
      if (rulesJson == null) return [];
      
      final List<dynamic> rulesList = jsonDecode(rulesJson);
      return rulesList.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting automation rules: $e');
      }
      return [];
    }
  }

  Future<void> saveAutomationRules(List<Map<String, dynamic>> rules) async {
    try {
      if (_prefs == null) return;
      
      final rulesJson = jsonEncode(rules);
      await _prefs!.setString('automation_rules', rulesJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving automation rules: $e');
      }
    }
  }

  // Automation Logs Storage
  Future<List<Map<String, dynamic>>> getAutomationLogs() async {
    try {
      if (_prefs == null) return [];
      
      final logsJson = _prefs!.getString('automation_logs');
      if (logsJson == null) return [];
      
      final List<dynamic> logsList = jsonDecode(logsJson);
      return logsList.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting automation logs: $e');
      }
      return [];
    }
  }

  Future<void> saveAutomationLogs(List<Map<String, dynamic>> logs) async {
    try {
      if (_prefs == null) return;
      
      final logsJson = jsonEncode(logs);
      await _prefs!.setString('automation_logs', logsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving automation logs: $e');
      }
    }
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}
