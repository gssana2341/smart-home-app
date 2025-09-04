import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/device_status.dart';
import '../models/sensor_data.dart';
import '../utils/constants.dart';
import '../utils/log_manager.dart';

class MqttService extends ChangeNotifier {
  MqttServerClient? _client;
  bool _isConnected = false;
  String? _lastError;
  
  // Stream controllers for different message types
  final StreamController<DeviceStatus> _deviceStatusController = 
      StreamController<DeviceStatus>.broadcast();
  final StreamController<SensorData> _sensorDataController = 
      StreamController<SensorData>.broadcast();
  final StreamController<Map<String, dynamic>> _heartbeatController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  
  // Streams
  Stream<DeviceStatus> get deviceStatusStream => _deviceStatusController.stream;
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;
  Stream<Map<String, dynamic>> get heartbeatStream => _heartbeatController.stream;

  MqttService() {
    try {
      _initializeMqttClient();
      // Auto-connect เมื่อ initialize
      Future.delayed(const Duration(seconds: 1), () {
        connect();
      });
    } catch (e) {
      logger.error('MqttService initialization error', error: e, category: 'MQTT');
      _isConnected = false;
      _lastError = e.toString();
    }
  }

  void _initializeMqttClient() {
    // Use MqttServerClient for all platforms
    // Note: Web browsers may not support MQTT directly
    _client = MqttServerClient.withPort(
      MqttConstants.brokerHost,
      MqttConstants.clientId,
      MqttConstants.brokerPort,
    );

    if (kIsWeb) {
      logger.info('Using MQTT client for web platform (may not work)', category: 'MQTT');
      print('MQTT: Using MQTT client for web platform (may not work)');
    } else {
      logger.info('Using MQTT TCP client for mobile platform', category: 'MQTT');
      print('MQTT: Using TCP client for mobile platform');
    }

    _client!.logging(on: kDebugMode);
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onUnsubscribed = _onUnsubscribed;
    _client!.onSubscribed = _onSubscribed;
    _client!.onSubscribeFail = _onSubscribeFail;
    _client!.pongCallback = _onPong;
    _client!.keepAlivePeriod = MqttConstants.keepAlivePeriod.inSeconds;
    _client!.connectTimeoutPeriod = MqttConstants.connectionTimeout.inMilliseconds;
  }

  // Connect to MQTT broker
  Future<bool> connect() async {
    try {
      if (_client == null) {
        _initializeMqttClient();
      }

      if (_isConnected) {
        logger.info('Already connected to MQTT broker', category: 'MQTT');
        return true;
      }

      logger.info('Connecting to ${MqttConstants.brokerHost}:${MqttConstants.brokerPort}', category: 'MQTT');
      print('MQTT: Connecting to ${MqttConstants.brokerHost}:${MqttConstants.brokerPort}');
      logger.info('Client ID: ${MqttConstants.clientId}', category: 'MQTT');
      print('MQTT: Client ID: ${MqttConstants.clientId}');

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(MqttConstants.clientId)
          .withWillTopic('${MqttConstants.clientId}/will')
          .withWillMessage('Client disconnected unexpectedly')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMessage;

      logger.info('Attempting MQTT connection...', category: 'MQTT');
      final status = await _client!.connect();
      
      if (status!.state == MqttConnectionState.connected) {
        _isConnected = true;
        _lastError = null;
        
        logger.info('✅ MQTT Connection successful!', category: 'MQTT');
        print('MQTT: Connection successful!');
        
        // Subscribe to topics
        await _subscribeToTopics();
        
        // Setup message listener
        _client!.updates!.listen(_onMessage);
        
        notifyListeners();
        return true;
      } else {
        _lastError = 'Connection failed: ${status.state}';
        _isConnected = false;
        logger.error('❌ MQTT Connection failed: ${status.state}', category: 'MQTT');
        print('MQTT: Connection failed: ${status.state}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Connection error: $e';
      _isConnected = false;
      logger.error('❌ MQTT Connection error: $e', category: 'MQTT');
      print('MQTT: Connection error: $e');
      notifyListeners();
      return false;
    }
  }

  // Disconnect from MQTT broker
  Future<void> disconnect() async {
    try {
      if (_client != null && _isConnected) {
        _client!.disconnect();
      }
    } catch (e) {
      logger.error('MQTT disconnect error', error: e, category: 'MQTT');
    }
  }

  // Subscribe to all necessary topics
  Future<void> _subscribeToTopics() async {
    if (_client == null || !_isConnected) {
      logger.warning('Cannot subscribe: client is null or not connected', category: 'MQTT');
      return;
    }

    try {
      logger.info('Subscribing to MQTT topics...', category: 'MQTT');
      print('MQTT: Subscribing to topics...');
      
      _client!.subscribe(MqttConstants.sensorTopic, MqttQos.atLeastOnce);
      _client!.subscribe(MqttConstants.statusTopic, MqttQos.atLeastOnce);
      _client!.subscribe(MqttConstants.heartbeatTopic, MqttQos.atLeastOnce);
      
      logger.info('✅ Subscribed to topics: ${MqttConstants.sensorTopic}, ${MqttConstants.statusTopic}, ${MqttConstants.heartbeatTopic}', category: 'MQTT');
      print('MQTT: Subscribed to topics successfully');
    } catch (e) {
      logger.error('❌ MQTT subscription error: $e', error: e, category: 'MQTT');
      print('MQTT: Subscription error: $e');
    }
  }

  // Publish command to device with retry mechanism
  Future<bool> publishCommand(
    String command, {
    Map<String, dynamic>? data,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    Exception? lastException;
    
    while (attempts < maxRetries) {
      attempts++;
      
      try {
        logger.debug('Attempt $attempts/$maxRetries for command: $command', category: 'MQTT');
        
        // Check connection first
        if (_client == null || !_isConnected) {
          logger.warning('Not connected, attempting to reconnect...', category: 'MQTT');
          
          // Try to reconnect
          final reconnected = await connect();
          if (!reconnected) {
            throw Exception('Failed to connect to MQTT broker');
          }
        }

        final message = {
          'command': command,
          'timestamp': DateTime.now().toIso8601String(),
          'client_id': MqttConstants.clientId,
          'attempt': attempts,
          ...?data,
        };

        final builder = MqttClientPayloadBuilder();
        builder.addString(jsonEncode(message));

        // Publish with acknowledgment
        final messageId = _client!.publishMessage(
          MqttConstants.commandTopic,
          MqttQos.atLeastOnce,
          builder.payload!,
        );

        logger.info('📤 Published MQTT command: $command (msgId: $messageId)', category: 'MQTT');
        print('MQTT: Published command: $command');

        // Wait a bit to ensure message was sent
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Check if still connected after publishing
        if (_isConnected) {
          _lastError = null;
          notifyListeners();
          return true;
        } else {
          throw Exception('Connection lost after publishing');
        }
        
      } catch (e) {
        lastException = Exception(e.toString());
        logger.error('❌ MQTT Publish attempt $attempts failed: $e', error: e, category: 'MQTT');
        print('MQTT: Publish attempt $attempts failed: $e');
        
        _lastError = 'Publish attempt $attempts failed: $e';
        notifyListeners();
        
        // Wait before retrying (except on last attempt)
        if (attempts < maxRetries) {
          logger.debug('Waiting ${retryDelay.inSeconds}s before retry...', category: 'MQTT');
          await Future.delayed(retryDelay);
          
          // Try to reconnect before next attempt
          if (!_isConnected) {
            await connect();
          }
        }
      }
    }
    
    // All attempts failed
    _lastError = 'All $maxRetries MQTT publish attempts failed. Last error: ${lastException?.toString() ?? "Unknown error"}';
    notifyListeners();
    
    logger.error('❌ All $maxRetries MQTT attempts failed for command: $command', category: 'MQTT');
    print('MQTT: All $maxRetries attempts failed for command: $command');
    
    return false;
  }

  // Device control methods
  Future<bool> controlLight(bool turnOn) async {
    return await publishCommand(
      turnOn ? Commands.turnOnLight : Commands.turnOffLight,
      data: {'device': 'relay1', 'state': turnOn},
    );
  }

  Future<bool> controlFan(bool turnOn) async {
    return await publishCommand(
      turnOn ? Commands.turnOnFan : Commands.turnOffFan,
      data: {'device': 'relay2', 'state': turnOn},
    );
  }

  Future<bool> controlAirConditioner(bool turnOn) async {
    return await publishCommand(
      turnOn ? Commands.turnOnAirConditioner : Commands.turnOffAirConditioner,
      data: {'device': 'relay3', 'state': turnOn},
    );
  }

  Future<bool> controlWaterPump(bool turnOn) async {
    return await publishCommand(
      turnOn ? Commands.turnOnWaterPump : Commands.turnOffWaterPump,
      data: {'device': 'relay4', 'state': turnOn},
    );
  }

  Future<bool> controlHeater(bool turnOn) async {
    return await publishCommand(
      turnOn ? Commands.turnOnHeater : Commands.turnOffHeater,
      data: {'device': 'relay5', 'state': turnOn},
    );
  }

  Future<bool> controlExtraDevice(bool turnOn) async {
    return await publishCommand(
      turnOn ? Commands.turnOnExtraDevice : Commands.turnOffExtraDevice,
      data: {'device': 'relay6', 'state': turnOn},
    );
  }

  Future<bool> requestStatus() async {
    return await publishCommand(Commands.getStatus);
  }

  Future<bool> requestSensors() async {
    return await publishCommand(Commands.getSensors);
  }

  Future<bool> resetDevice() async {
    return await publishCommand(Commands.reset);
  }

  // Message handling
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final topic = message.topic;
      final payload = message.payload as MqttPublishMessage;
      final messageText = MqttPublishPayload.bytesToStringAsString(payload.payload.message);

      logger.info('📨 Received MQTT message on topic: $topic', category: 'MQTT');
      logger.debug('Message content: $messageText', category: 'MQTT');
      print('MQTT: Received message on topic: $topic');

      try {
        final Map<String, dynamic> data = jsonDecode(messageText);
        _handleMessage(topic, data);
      } catch (e) {
        logger.error('❌ Failed to parse MQTT message: $e', error: e, category: 'MQTT');
        print('MQTT: Failed to parse message: $e');
      }
    }
  }

  void _handleMessage(String topic, Map<String, dynamic> data) {
    switch (topic) {
      case MqttConstants.statusTopic:
        _handleStatusMessage(data);
        break;
      case MqttConstants.sensorTopic:
        _handleSensorMessage(data);
        break;
      case MqttConstants.heartbeatTopic:
        _handleHeartbeatMessage(data);
        break;
      default:
        logger.warning('Unknown topic: $topic', category: 'MQTT');
    }
  }

  void _handleStatusMessage(Map<String, dynamic> data) {
    try {
      final deviceStatus = DeviceStatus.fromJson(data);
      _deviceStatusController.add(deviceStatus);
      logger.info('✅ Processed device status from MQTT', category: 'MQTT');
      print('MQTT: Processed device status');
    } catch (e) {
      logger.error('❌ Failed to parse device status from MQTT: $e', error: e, category: 'MQTT');
      print('MQTT: Failed to parse device status: $e');
    }
  }

  void _handleSensorMessage(Map<String, dynamic> data) {
    try {
      final sensorData = SensorData.fromJson(data);
      _sensorDataController.add(sensorData);
      logger.info('✅ Processed sensor data from MQTT', category: 'MQTT');
      print('MQTT: Processed sensor data');
    } catch (e) {
      logger.error('❌ Failed to parse sensor data from MQTT: $e', error: e, category: 'MQTT');
      print('MQTT: Failed to parse sensor data: $e');
    }
  }

  void _handleHeartbeatMessage(Map<String, dynamic> data) {
    _heartbeatController.add(data);
  }

  // Connection callbacks
  void _onConnected() {
    _isConnected = true;
    _lastError = null;
    notifyListeners();
    logger.info('✅ MQTT Connected to broker successfully', category: 'MQTT');
    print('MQTT: Connected to broker successfully');
  }

  void _onDisconnected() {
    _isConnected = false;
    notifyListeners();
    logger.info('❌ MQTT Disconnected from broker', category: 'MQTT');
    print('MQTT: Disconnected from broker');
  }

  void _onSubscribed(String topic) {
    logger.info('✅ Subscribed to topic: $topic', category: 'MQTT');
    print('MQTT: Subscribed to topic: $topic');
  }

  void _onSubscribeFail(String topic) {
    logger.error('❌ Failed to subscribe to topic: $topic', category: 'MQTT');
    print('MQTT: Failed to subscribe to topic: $topic');
  }

  void _onUnsubscribed(String? topic) {
    logger.info('Unsubscribed from topic: $topic', category: 'MQTT');
  }

  void _onPong() {
    logger.debug('Ping response received', category: 'MQTT');
  }

  // Update connection settings
  void updateConnectionSettings({
    String? host,
    int? port,
    String? clientId,
  }) {
    if (host != null || port != null || clientId != null) {
      disconnect();
      _initializeMqttClient();
    }
  }

  // Cleanup
  @override
  void dispose() {
    disconnect();
    _deviceStatusController.close();
    _sensorDataController.close();
    _heartbeatController.close();
    super.dispose();
  }
}
