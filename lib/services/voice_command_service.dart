import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/voice_command.dart';
import '../models/device_status.dart';
import 'ai_service.dart';
import 'api_service.dart';
import 'mqtt_service.dart';
import 'storage_service_simple.dart';
import 'tts_service.dart';

class VoiceCommandService extends ChangeNotifier {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final SpeechToText _speechToText = SpeechToText();
  final AiService _aiService = AiService();
  final TtsService _ttsService = TtsService.instance;
  
  bool _isListening = false;
  bool _isInitialized = false;
  bool _isProcessingCommand = false;
  bool _hasPermission = false; // from speech_to_text
  bool _isAvailable = false;   // from speech_to_text
  String? _lastError;          // last error from onError
  
  // Stream controllers
  final StreamController<bool> _listeningController = StreamController<bool>.broadcast();
  final StreamController<String> _transcriptionController = StreamController<String>.broadcast();
  final StreamController<VoiceCommand> _commandResultController = StreamController<VoiceCommand>.broadcast();
  final StreamController<DeviceStatus> _deviceStatusUpdateController = StreamController<DeviceStatus>.broadcast();

  String _lastRecognizedWords = '';
  DateTime? _lastActivity;
  Timer? _inactivityTimer;

  // Getters
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get hasMicPermission => _hasPermission;
  bool get isSpeechAvailable => _isAvailable;
  String? get lastError => _lastError;
  Stream<bool> get listeningStream => _listeningController.stream;
  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<VoiceCommand> get commandResultStream => _commandResultController.stream;
  Stream<DeviceStatus> get deviceStatusUpdateStream => _deviceStatusUpdateController.stream;

  /// Initializes the speech recognition system.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission first (skip on web; browser handles via prompt)
      if (!kIsWeb) {
        final micPermission = await Permission.microphone.request();
        if (micPermission != PermissionStatus.granted) {
          print('Microphone permission not granted');
          return false;
        }
      } else {
        print('Web platform detected: skipping Permission.microphone.request().');
      }

      // Initialize speech recognition
      final available = await _speechToText.initialize(
        onStatus: _onStatusChanged,
        onError: _onError,
        debugLogging: true,
      );
      
      _isInitialized = available;
      _isAvailable = available;
      _hasPermission = await _speechToText.hasPermission;
      if (available) {
        print('Speech recognition initialized successfully.');
        print('SpeechToText hasPermission: '+ _hasPermission.toString());
        try {
          final locales = await _speechToText.locales();
          print('SpeechToText available locales ('+locales.length.toString()+'): '+locales.map((l) => l.localeId).take(10).join(', ')+ (locales.length > 10 ? ', ...' : ''));
        } catch (e) {
          print('Error fetching locales: $e');
        }
        try {
          final sysLocale = await _speechToText.systemLocale();
          print('System locale: ${sysLocale?.localeId}');
        } catch (e) {
          print('Error fetching system locale: $e');
        }
      } else {
        print('Speech recognition not available.');
        return false;
      }
      return true;
    } catch (e) {
      print('Error initializing speech recognition: $e');
      return false;
    }
  }

  /// Starts listening for voice commands.
  Future<bool> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isListening) return true;

    try {
      // Resolve a supported locale: prefer th-TH, else system, else en-US
      String? resolvedLocaleId;
      try {
        final locales = await _speechToText.locales();
        final thLocales = locales.where((l) => l.localeId.toLowerCase() == 'th-th');
        if (thLocales.isNotEmpty) {
          resolvedLocaleId = thLocales.first.localeId;
        } else {
          final sys = await _speechToText.systemLocale();
          resolvedLocaleId = sys?.localeId ?? (locales.isNotEmpty ? locales.first.localeId : null);
        }
      } catch (e) {
        print('Locale resolution error: $e');
      }
      resolvedLocaleId ??= 'en-US';

      final success = await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 20), // Listen longer
        pauseFor: const Duration(seconds: 5), // More pause time
        localeId: resolvedLocaleId,
      );
      if (success) {
        _isListening = true;
        _listeningController.add(true);
        notifyListeners();
      }
      if (!success) {
        _hasPermission = await _speechToText.hasPermission;
        _isAvailable = await _speechToText.isAvailable;
        print('SpeechToText.listen returned false | hasPermission: '+_hasPermission.toString()+', isAvailable: '+_isAvailable.toString()+', lastError: '+(_lastError ?? 'none'));
      }
      return success;
    } catch (e) {
      print('Error starting speech recognition: $e');
      return false;
    }
  }

  /// Stops listening for voice commands.
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      _isListening = false;
      _listeningController.add(false);
      notifyListeners();
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }
  }

  void _onStatusChanged(String status) {
    print('Speech status changed: $status');
    if (status == 'done' || status == 'notListening') {
      if (_isListening) {
        _isListening = false;
        _listeningController.add(false);
        notifyListeners();
      }
    }
  }

  void _onError(dynamic error) {
    _lastError = error?.toString();
    print('Speech recognition error: $error');
    if (_isListening) {
      _isListening = false;
      _listeningController.add(false);
      notifyListeners();
    }
  }

  /// Callback for speech recognition results.
  void _onSpeechResult(dynamic result) {
    _lastRecognizedWords = result.recognizedWords;
    _transcriptionController.add(_lastRecognizedWords);
    
    if (result.finalResult) {
      print('Final result: $_lastRecognizedWords');
      _processVoiceCommand(_lastRecognizedWords);
    }
  }

  /// Processes the recognized voice command.
  Future<void> _processVoiceCommand(String voiceInput) async {
    // ป้องกันการประมวลผลซ้ำ
    if (_isProcessingCommand) {
      print('Voice Command: Already processing a command, skipping: "$voiceInput"');
      return;
    }

    _isProcessingCommand = true;
    print('Voice Command: Processing: "$voiceInput"');

    try {
      // หยุดฟัง
      await stopListening();

      // ประมวลผลด้วย AI
      final deviceStatus = StorageService.instance.getDeviceStatus();
      final voiceCommand = await _aiService.processVoiceCommand(voiceInput, deviceStatus);

      // ส่งผลลัพธ์
      _commandResultController.add(voiceCommand);

      // เล่นเสียงตอบกลับก่อนเสมอ
      await _playVoiceResponse(voiceCommand);
      
      // ถ้าเป็นคำสั่งควบคุม ให้ทำการควบคุมอุปกรณ์หลังจากเล่นเสียงแล้ว
      if (voiceCommand.isSuccess && _aiService.isControlCommand(voiceInput)) {
        await _executeControlCommand(voiceInput, voiceCommand);
      }

      // บันทึกคำสั่ง
      await _saveVoiceCommand(voiceCommand);

    } catch (e) {
      print('Error processing voice command: $e');
      final errorCommand = VoiceCommand(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        command: voiceInput,
        result: 'เกิดข้อผิดพลาดในการประมวลผล: $e',
        timestamp: DateTime.now(),
        isSuccess: false,
        errorMessage: e.toString(),
      );
      _commandResultController.add(errorCommand);
    } finally {
      _isProcessingCommand = false;
      print('Voice Command: Processing completed for: "$voiceInput"');
    }
  }

  /// ทำการควบคุมอุปกรณ์ตามคำสั่งเสียง
  Future<void> _executeControlCommand(String voiceInput, VoiceCommand command) async {
    try {
      final input = voiceInput.toLowerCase();
      
      // ควบคุมไฟ
      if (input.contains('ไฟ')) {
        if (input.contains('เปิด')) {
          await _controlLight(true);
        } else if (input.contains('ปิด')) {
          await _controlLight(false);
        }
      }
      
      // ควบคุมพัดลม
      if (input.contains('พัดลม')) {
        if (input.contains('เปิด')) {
          await _controlFan(true);
        } else if (input.contains('ปิด')) {
          await _controlFan(false);
        }
      }
      
      // ควบคุมแอร์
      if (input.contains('แอร์') || input.contains('แอร์คอนดิชั่น')) {
        if (input.contains('เปิด')) {
          await _controlAirConditioner(true);
        } else if (input.contains('ปิด')) {
          await _controlAirConditioner(false);
        }
      }
      
      // ควบคุมปั๊มน้ำ
      if (input.contains('ปั๊มน้ำ') || input.contains('ปั๊ม')) {
        if (input.contains('เปิด')) {
          await _controlWaterPump(true);
        } else if (input.contains('ปิด')) {
          await _controlWaterPump(false);
        }
      }
      
      // ควบคุมฮีทเตอร์
      if (input.contains('ฮีทเตอร์') || input.contains('เครื่องทำความร้อน')) {
        if (input.contains('เปิด')) {
          await _controlHeater(true);
        } else if (input.contains('ปิด')) {
          await _controlHeater(false);
        }
      }
      
      // ควบคุมอุปกรณ์เพิ่มเติม
      if (input.contains('อุปกรณ์เพิ่มเติม') || input.contains('อุปกรณ์พิเศษ')) {
        if (input.contains('เปิด')) {
          await _controlExtraDevice(true);
        } else if (input.contains('ปิด')) {
          await _controlExtraDevice(false);
        }
      }
      
      // ควบคุมทั้งหมด
      if (input.contains('ทั้งหมด') || input.contains('ทุกอย่าง')) {
        if (input.contains('เปิด')) {
          await _controlAllDevices(true);
        } else if (input.contains('ปิด')) {
          await _controlAllDevices(false);
        }
      }

    } catch (e) {
      print('Error executing control command: $e');
    }
  }

  /// ควบคุมไฟ
  Future<bool> _controlLight(bool turnOn) async {
    try {
      final storage = StorageService.instance;
      final controlMode = storage.getControlMode();
      
      // ใช้ตามการตั้งค่า
      switch (controlMode) {
        case 'api':
          return await _controlLightViaApi(turnOn);
        case 'mqtt':
          return await _controlLightViaMqtt(turnOn);
        case 'auto':
        default:
          return await _controlLightAuto(turnOn);
      }
    } catch (e) {
      print('Error controlling light: $e');
      return false;
    }
  }

  /// ควบคุมไฟผ่าน API
  Future<bool> _controlLightViaApi(bool turnOn) async {
    final apiService = ApiService();
    final success = await apiService.controlLight(turnOn);
    
    if (success) {
      print('Light control via API: ${turnOn ? "ON" : "OFF"}');
      _updateDeviceStatusImmediately('relay1', turnOn);
      return true;
    }
    
    return false;
  }

  /// ควบคุมไฟผ่าน MQTT
  Future<bool> _controlLightViaMqtt(bool turnOn) async {
    final mqttService = MqttService();
    if (mqttService.isConnected) {
      final success = await mqttService.controlLight(turnOn);
      if (success) {
        print('Light control via MQTT: ${turnOn ? "ON" : "OFF"}');
        _updateDeviceStatusImmediately('relay1', turnOn);
        return true;
      }
    }
    
    return false;
  }

  /// ควบคุมไฟแบบอัตโนมัติ (API แล้ว MQTT)
  Future<bool> _controlLightAuto(bool turnOn) async {
    // ลอง API ก่อน
    final apiSuccess = await _controlLightViaApi(turnOn);
    if (apiSuccess) return true;
    
    // ถ้า API ไม่สำเร็จ ใช้ MQTT
    return await _controlLightViaMqtt(turnOn);
  }

  /// ควบคุมพัดลม
  Future<bool> _controlFan(bool turnOn) async {
    try {
      final storage = StorageService.instance;
      final controlMode = storage.getControlMode();
      
      // ใช้ตามการตั้งค่า
      switch (controlMode) {
        case 'api':
          return await _controlFanViaApi(turnOn);
        case 'mqtt':
          return await _controlFanViaMqtt(turnOn);
        case 'auto':
        default:
          return await _controlFanAuto(turnOn);
      }
    } catch (e) {
      print('Error controlling fan: $e');
      return false;
    }
  }

  /// ควบคุมพัดลมผ่าน API
  Future<bool> _controlFanViaApi(bool turnOn) async {
    final apiService = ApiService();
    final success = await apiService.controlFan(turnOn);
    
    if (success) {
      print('Fan control via API: ${turnOn ? "ON" : "OFF"}');
      _updateDeviceStatusImmediately('relay2', turnOn);
      return true;
    }
    
    return false;
  }

  /// ควบคุมพัดลมผ่าน MQTT
  Future<bool> _controlFanViaMqtt(bool turnOn) async {
    final mqttService = MqttService();
    if (mqttService.isConnected) {
      final success = await mqttService.controlFan(turnOn);
      if (success) {
        print('Fan control via MQTT: ${turnOn ? "ON" : "OFF"}');
        _updateDeviceStatusImmediately('relay2', turnOn);
        return true;
      }
    }
    
    return false;
  }

  /// ควบคุมพัดลมแบบอัตโนมัติ (API แล้ว MQTT)
  Future<bool> _controlFanAuto(bool turnOn) async {
    // ลอง API ก่อน
    final apiSuccess = await _controlFanViaApi(turnOn);
    if (apiSuccess) return true;
    
    // ถ้า API ไม่สำเร็จ ใช้ MQTT
    return await _controlFanViaMqtt(turnOn);
  }

  /// ควบคุมแอร์
  Future<bool> _controlAirConditioner(bool turnOn) async {
    try {
      // ใช้ API Service
      final apiService = ApiService();
      final success = await apiService.controlAirConditioner(turnOn);
      
      if (success) {
        print('Air Conditioner control via voice: ${turnOn ? "ON" : "OFF"}');
        _updateDeviceStatusImmediately('relay3', turnOn);
        return true;
      }
      
      // ถ้า API ไม่สำเร็จ ใช้ MQTT
      final mqttService = MqttService();
      if (mqttService.isConnected) {
        final mqttSuccess = await mqttService.controlAirConditioner(turnOn);
        if (mqttSuccess) {
          print('Air Conditioner control via MQTT: ${turnOn ? "ON" : "OFF"}');
          _updateDeviceStatusImmediately('relay3', turnOn);
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error controlling air conditioner: $e');
      return false;
    }
  }

  /// ควบคุมปั๊มน้ำ
  Future<bool> _controlWaterPump(bool turnOn) async {
    try {
      // ใช้ API Service
      final apiService = ApiService();
      final success = await apiService.controlWaterPump(turnOn);
      
      if (success) {
        print('Water Pump control via voice: ${turnOn ? "ON" : "OFF"}');
        _updateDeviceStatusImmediately('relay4', turnOn);
        return true;
      }
      
      // ถ้า API ไม่สำเร็จ ใช้ MQTT
      final mqttService = MqttService();
      if (mqttService.isConnected) {
        final mqttSuccess = await mqttService.controlWaterPump(turnOn);
        if (mqttSuccess) {
          print('Water Pump control via MQTT: ${turnOn ? "ON" : "OFF"}');
          _updateDeviceStatusImmediately('relay4', turnOn);
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error controlling water pump: $e');
      return false;
    }
  }

  /// ควบคุมฮีทเตอร์
  Future<bool> _controlHeater(bool turnOn) async {
    try {
      // ใช้ API Service
      final apiService = ApiService();
      final success = await apiService.controlHeater(turnOn);
      
      if (success) {
        print('Heater control via voice: ${turnOn ? "ON" : "OFF"}');
        _updateDeviceStatusImmediately('relay5', turnOn);
        return true;
      }
      
      // ถ้า API ไม่สำเร็จ ใช้ MQTT
      final mqttService = MqttService();
      if (mqttService.isConnected) {
        final mqttSuccess = await mqttService.controlHeater(turnOn);
        if (mqttSuccess) {
          print('Heater control via MQTT: ${turnOn ? "ON" : "OFF"}');
          _updateDeviceStatusImmediately('relay5', turnOn);
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error controlling heater: $e');
      return false;
    }
  }

  /// ควบคุมอุปกรณ์เพิ่มเติม
  Future<bool> _controlExtraDevice(bool turnOn) async {
    try {
      // ใช้ API Service
      final apiService = ApiService();
      final success = await apiService.controlExtraDevice(turnOn);
      
      if (success) {
        print('Extra Device control via voice: ${turnOn ? "ON" : "OFF"}');
        _updateDeviceStatusImmediately('relay6', turnOn);
        return true;
      }
      
      // ถ้า API ไม่สำเร็จ ใช้ MQTT
      final mqttService = MqttService();
      if (mqttService.isConnected) {
        final mqttSuccess = await mqttService.controlExtraDevice(turnOn);
        if (mqttSuccess) {
          print('Extra Device control via MQTT: ${turnOn ? "ON" : "OFF"}');
          _updateDeviceStatusImmediately('relay6', turnOn);
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error controlling extra device: $e');
      return false;
    }
  }

  /// ควบคุมอุปกรณ์ทั้งหมด
  Future<bool> _controlAllDevices(bool turnOn) async {
    try {
      final lightSuccess = await _controlLight(turnOn);
      final fanSuccess = await _controlFan(turnOn);
      final acSuccess = await _controlAirConditioner(turnOn);
      final pumpSuccess = await _controlWaterPump(turnOn);
      final heaterSuccess = await _controlHeater(turnOn);
      final extraSuccess = await _controlExtraDevice(turnOn);
      
      return lightSuccess || fanSuccess || acSuccess || pumpSuccess || heaterSuccess || extraSuccess;
    } catch (e) {
      print('Error controlling all devices: $e');
      return false;
    }
  }

  /// อัปเดตสถานะอุปกรณ์ทันทีหลังจากควบคุมสำเร็จ
  void _updateDeviceStatusImmediately(String relayName, bool newState) {
    try {
      // ดึงสถานะปัจจุบันจาก storage
      final currentStatus = StorageService.instance.getDeviceStatus();
      if (currentStatus == null) return;

      // สร้างสถานะใหม่
      DeviceStatus updatedStatus;
      switch (relayName) {
        case 'relay1':
          updatedStatus = currentStatus.copyWith(relay1: newState);
          break;
        case 'relay2':
          updatedStatus = currentStatus.copyWith(relay2: newState);
          break;
        case 'relay3':
          updatedStatus = currentStatus.copyWith(relay3: newState);
          break;
        case 'relay4':
          updatedStatus = currentStatus.copyWith(relay4: newState);
          break;
        case 'relay5':
          updatedStatus = currentStatus.copyWith(relay5: newState);
          break;
        case 'relay6':
          updatedStatus = currentStatus.copyWith(relay6: newState);
          break;
        default:
          return;
      }

      // บันทึกสถานะใหม่
      StorageService.instance.saveDeviceStatus(updatedStatus);

      // ส่งสัญญาณไปยัง UI ให้อัปเดตทันที
      _deviceStatusUpdateController.add(updatedStatus);
      
      print('Voice Command: Updated $relayName to ${newState ? "ON" : "OFF"}');
    } catch (e) {
      print('Error updating device status immediately: $e');
    }
  }

  /// บันทึกคำสั่งเสียง
  Future<void> _saveVoiceCommand(VoiceCommand command) async {
    try {
      // TODO: Implement saving to storage
      print('Voice command saved: ${command.command}');
    } catch (e) {
      print('Error saving voice command: $e');
    }
  }

  /// ตรวจสอบสถานะการฟัง
  bool get isAvailable => false;

  /// เล่นเสียงตอบกลับคำสั่งเสียง
  Future<void> _playVoiceResponse(VoiceCommand command) async {
    try {
      if (!_ttsService.isInitialized) {
        await _ttsService.initialize();
      }
      
      String responseText = '';
      
      if (command.isSuccess) {
        if (_aiService.isControlCommand(command.command)) {
          // คำสั่งควบคุม
          if (command.command.toLowerCase().contains('เปิด')) {
            responseText = 'ได้ครับ เปิดอุปกรณ์ให้แล้วครับ';
          } else if (command.command.toLowerCase().contains('ปิด')) {
            responseText = 'ได้ครับ ปิดอุปกรณ์ให้แล้วครับ';
          } else {
            responseText = 'ดำเนินการตามคำสั่งแล้วครับ';
          }
        } else {
          // คำสั่งทั่วไป - ใช้ผลลัพธ์จาก AI ที่ปรับปรุงแล้ว
          responseText = command.result;
        }
      } else {
        // ข้อผิดพลาด
        responseText = 'ขออภัยครับ ไม่สามารถดำเนินการได้: ${command.errorMessage ?? 'เกิดข้อผิดพลาด'}';
      }
      
      if (responseText.isNotEmpty) {
        // ใช้ speakImmediate เพื่อพูดทันทีและรอให้เสร็จ
        await _ttsService.speak(responseText);
        print('Voice response played: $responseText');
        
        // รอให้การพูดเสร็จสิ้น
        while (_ttsService.isSpeaking) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        // รอสักครู่เพื่อให้เสียงชัดเจน
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print('Error playing voice response: $e');
    }
  }

  // Public method สำหรับส่ง log จากภายนอก
  void addLogMessage(String title, String message) {
    final logCommand = VoiceCommand(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      command: title,
      result: message,
      timestamp: DateTime.now(),
      isSuccess: true,
    );
    _commandResultController.add(logCommand);
  }

  @override
  void dispose() {
    // no-op when speech plugin is disabled
    _listeningController.close();
    _transcriptionController.close();
    _commandResultController.close();
    _deviceStatusUpdateController.close();
    super.dispose();
  }
}
