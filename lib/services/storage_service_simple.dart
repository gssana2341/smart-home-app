import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  Database? _database;
  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;
  Database? get database => _database;

  // Initialize storage service
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      // Initialize SQLite database
      await _initializeDatabase();
      
      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('StorageService initialization error: $e');
      }
      return false;
    }
  }

  // Initialize SQLite database
  Future<void> _initializeDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, StorageConstants.databaseName);

      _database = await openDatabase(
        path,
        version: StorageConstants.databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      if (kDebugMode) {
        print('Database initialized at: $path');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Database initialization error: $e');
      }
      rethrow;
    }
  }

  // Create database tables
  Future<void> _onCreate(Database db, int version) async {
    try {
      // Chat messages table
      await db.execute('''
        CREATE TABLE ${StorageConstants.chatMessagesTable} (
          id TEXT PRIMARY KEY,
          message TEXT NOT NULL,
          reply TEXT,
          timestamp TEXT NOT NULL,
          isUser INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Sensor data table
      await db.execute('''
        CREATE TABLE ${StorageConstants.sensorDataTable} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          temperature REAL,
          humidity REAL,
          gasLevel INTEGER,
          timestamp TEXT NOT NULL
        )
      ''');

      // Device logs table
      await db.execute('''
        CREATE TABLE ${StorageConstants.deviceLogsTable} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device TEXT NOT NULL,
          action TEXT NOT NULL,
          status TEXT,
          timestamp TEXT NOT NULL
        )
      ''');

      if (kDebugMode) {
        print('Database tables created successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating database tables: $e');
      }
      rethrow;
    }
  }

  // Upgrade database
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here if needed
    if (kDebugMode) {
      print('Database upgraded from version $oldVersion to $newVersion');
    }
  }

  // Simple key-value storage using database
  Future<void> _setString(String key, String value) async {
    if (_database == null) return;
    
    try {
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      
      await _database!.insert(
        'app_settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error setting string: $e');
      }
    }
  }

  Future<String?> _getString(String key) async {
    if (_database == null) return null;
    
    try {
      final result = await _database!.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
      );
      
      if (result.isNotEmpty) {
        return result.first['value'] as String?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting string: $e');
      }
      return null;
    }
  }

  // App settings methods
  String getAppTheme() {
    // Default theme
    return 'system';
  }

  Future<void> setAppTheme(String theme) async {
    await _setString('app_theme', theme);
    notifyListeners();
  }

  bool getNotificationEnabled() {
    // Default to enabled
    return true;
  }

  Future<void> setNotificationEnabled(bool enabled) async {
    await _setString('notification_enabled', enabled.toString());
    notifyListeners();
  }

  String getControlMode() {
    // Default control mode
    return 'api';
  }

  Future<void> setControlMode(String mode) async {
    await _setString('control_mode', mode);
    notifyListeners();
  }

  bool getAutoRefresh() {
    // Default to enabled
    return true;
  }

  Future<void> setAutoRefresh(bool enabled) async {
    await _setString('auto_refresh', enabled.toString());
    notifyListeners();
  }

  int getRefreshInterval() {
    // Default refresh interval
    return AppConstants.defaultRefreshInterval;
  }

  Future<void> setRefreshInterval(int interval) async {
    await _setString('refresh_interval', interval.toString());
    notifyListeners();
  }

  // Chat messages
  Future<void> saveChatMessage(ChatMessage message) async {
    if (_database == null) return;

    try {
      await _database!.insert(
        StorageConstants.chatMessagesTable,
        message.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving chat message: $e');
      }
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

      return maps.map((map) => ChatMessage.fromJson(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting chat messages: $e');
      }
      return [];
    }
  }

  // Sensor data
  Future<void> saveSensorData(SensorData data) async {
    if (_database == null) return;

    try {
      await _database!.insert(
        StorageConstants.sensorDataTable,
        data.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving sensor data: $e');
      }
    }
  }

  Future<List<SensorData>> getSensorData({int? limit}) async {
    if (_database == null) return [];

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        StorageConstants.sensorDataTable,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return maps.map((map) => SensorData.fromJson(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting sensor data: $e');
      }
      return [];
    }
  }

  // Device logs
  Future<void> saveDeviceLog(String device, String action, String? status) async {
    if (_database == null) return;

    try {
      await _database!.insert(
        StorageConstants.deviceLogsTable,
        {
          'device': device,
          'action': action,
          'status': status,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving device log: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getDeviceLogs({int? limit}) async {
    if (_database == null) return [];

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        StorageConstants.deviceLogsTable,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return maps;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting device logs: $e');
      }
      return [];
    }
  }

  // Device status methods
  DeviceStatus? getDeviceStatus() {
    // Return null for now - will be implemented later
    return null;
  }

  Future<void> saveDeviceStatus(DeviceStatus status) async {
    // Save device status to database
    if (_database == null) return;
    
    try {
      await _database!.insert(
        'device_status',
        status.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving device status: $e');
      }
    }
  }

  Future<void> setLastUpdate(DateTime dateTime) async {
    await _setString('last_update', dateTime.toIso8601String());
  }

  // Server settings methods
  String getServerUrl() {
    return ApiConstants.baseUrl; // Default value
  }

  Future<void> setServerUrl(String url) async {
    await _setString('server_url', url);
    notifyListeners();
  }

  String getMqttHost() {
    return MqttConstants.brokerHost; // Default value
  }

  Future<void> setMqttHost(String host) async {
    await _setString('mqtt_host', host);
    notifyListeners();
  }

  int getMqttPort() {
    return MqttConstants.brokerPort; // Default value
  }

  Future<void> setMqttPort(int port) async {
    await _setString('mqtt_port', port.toString());
    notifyListeners();
  }

  // Device logging
  Future<void> logDeviceAction({
    required String deviceType,
    required String action,
    String? status,
  }) async {
    await saveDeviceLog(deviceType, action, status);
  }

  // Automation methods
  Future<List<Map<String, dynamic>>> getAutomationRules() async {
    final rulesJson = await _getString('automation_rules') ?? '[]';
    try {
      final List<dynamic> rules = jsonDecode(rulesJson);
      return rules.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveAutomationRules(List<Map<String, dynamic>> rules) async {
    await _setString('automation_rules', jsonEncode(rules));
  }

  Future<List<Map<String, dynamic>>> getAutomationLogs() async {
    final logsJson = await _getString('automation_logs') ?? '[]';
    try {
      final List<dynamic> logs = jsonDecode(logsJson);
      return logs.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveAutomationLogs(List<Map<String, dynamic>> logs) async {
    await _setString('automation_logs', jsonEncode(logs));
  }

  // Clear all data
  Future<void> clearAllData() async {
    if (_database == null) return;

    try {
      await _database!.delete(StorageConstants.chatMessagesTable);
      await _database!.delete(StorageConstants.sensorDataTable);
      await _database!.delete(StorageConstants.deviceLogsTable);
      await _database!.delete('app_settings');
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing data: $e');
      }
    }
  }

  // Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
    }
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}
