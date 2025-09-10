import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import '../models/voice_command.dart';
import '../models/device_status.dart';
import 'ai_service.dart';
import 'tts_service.dart';
import 'storage_service.dart';
import 'api_service.dart';

class VoiceCommandService extends ChangeNotifier {
  // Web Speech API
  js.JsObject? _recognition;
  bool _isSupported = false;
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isProcessingCommand = false;
  String _currentText = '';
  String _lastError = '';

  // Services
  final AiService _aiService = AiService();
  TtsService? _ttsService;
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();

  // Stream Controllers
  final StreamController<bool> _listeningController = StreamController<bool>.broadcast();
  final StreamController<String> _transcriptionController = StreamController<String>.broadcast();
  final StreamController<VoiceCommand> _commandResultController = StreamController<VoiceCommand>.broadcast();
  final StreamController<DeviceStatus> _deviceStatusUpdateController = StreamController<DeviceStatus>.broadcast();

  // Getters
  bool get isSupported => _isSupported;
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isProcessingCommand => _isProcessingCommand;
  String get currentText => _currentText;
  String get lastError => _lastError;

  // Streams
  Stream<bool> get listeningStream => _listeningController.stream;
  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<VoiceCommand> get commandResultStream => _commandResultController.stream;
  Stream<DeviceStatus> get deviceStatusUpdateStream => _deviceStatusUpdateController.stream;

  // Initialize
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // ตรวจสอบการรองรับ Web Speech API
      if (html.window.speechRecognition == null && html.window.webkitSpeechRecognition == null) {
        _lastError = 'Web Speech API is not supported in this browser';
        _isSupported = false;
        return false;
      }

      _isSupported = true;

      // สร้าง recognition object
      if (html.window.speechRecognition != null) {
        _recognition = js.JsObject(html.window.speechRecognition!);
      } else if (html.window.webkitSpeechRecognition != null) {
        _recognition = js.JsObject(html.window.webkitSpeechRecognition!);
      }

      // ขอสิทธิ์ไมค์
      try {
        await _requestMicrophonePermission();
      } catch (e) {
        // Silent fail
      }

      if (_recognition != null) {
        // ตั้งค่าภาษาเป็นไทย
        _recognition!['lang'] = 'th-TH';
        _recognition!['continuous'] = false;  // หยุดฟังเมื่อได้ผลลัพธ์
        _recognition!['interimResults'] = true;  // รับผลลัพธ์ชั่วคราว
        _recognition!['maxAlternatives'] = 1;

        // ตั้งค่า event handlers
        _recognition!['onstart'] = _onSpeechStart;
        _recognition!['onresult'] = _onSpeechResult;
        _recognition!['onerror'] = _onSpeechError;
        _recognition!['onend'] = _onSpeechEnd;
      } else {
        _lastError = 'Failed to create recognition object';
        _isSupported = false;
      }
    } catch (e) {
      _lastError = 'Failed to setup speech recognition: $e';
      _isSupported = false;
      notifyListeners();
    }

    _isInitialized = _isSupported;
    notifyListeners();
    return _isInitialized;
  }

  // Request microphone permission
  Future<void> _requestMicrophonePermission() async {
    try {
      final mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': true,
      });
      // ไม่ต้องทำอะไรกับ stream แค่ขอสิทธิ์
      mediaStream.getTracks().forEach((track) => track.stop());
    } catch (e) {
      throw Exception('Microphone permission denied: $e');
    }
  }

  // Set TTS Service
  void setTtsService(TtsService ttsService) {
    _ttsService = ttsService;
  }

  // Event Handlers
  void _onSpeechStart(js.JsObject event) {
    _isListening = true;
    _listeningController.add(true);
    notifyListeners();
  }

  void _onSpeechResult(js.JsObject event) {
    try {
      final results = event['results'];
      
      if (results != null && results['length'] > 0) {
        final result = results[0];
        final transcript = result[0]['transcript'] as String?;
        final isFinal = result[0]['isFinal'] as bool? ?? false;
        
        if (transcript != null && transcript.isNotEmpty) {
          _currentText = transcript;
          _transcriptionController.add(transcript);
          
          // ประมวลผลเฉพาะผลลัพธ์สุดท้าย
          if (isFinal) {
            // หยุดฟังทันทีเมื่อได้ผลลัพธ์สุดท้าย
            _recognition?.callMethod('stop');
            // ประมวลผลคำสั่ง
            _processVoiceCommand(transcript);
          }
        }
      }
    } catch (e) {
      print('Voice Command: Error processing speech result: $e');
    }
  }

  void _onSpeechError(js.JsObject event) {
    try {
      final error = event['error'] as String?;
      _lastError = error ?? 'Unknown speech recognition error';
    } catch (e) {
      _lastError = 'Speech recognition error occurred';
    }
    _isListening = false;
    _listeningController.add(false);
    notifyListeners();
  }

  void _onSpeechEnd(js.JsObject event) {
    _isListening = false;
    _listeningController.add(false);
    notifyListeners();
  }

  // Start listening
  Future<bool> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return false;
      }
    }

    if (_isListening) {
      return true;
    }

    try {
      if (_recognition == null) {
        _lastError = 'Recognition object is null';
        return false;
      }
      
      _recognition?.callMethod('start');
      return true;
    } catch (e) {
      _lastError = 'Failed to start speech recognition: $e';
      notifyListeners();
      return false;
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      _recognition?.callMethod('stop');
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }
  }

  // Process voice command
  Future<void> _processVoiceCommand(String voiceInput) async {
    // ป้องกันการประมวลผลซ้ำ
    if (_isProcessingCommand) {
      return;
    }

    _isProcessingCommand = true;

    try {
      print('Voice Command: Processing command: "$voiceInput"');
      
      // ประมวลผลด้วย AI
      final deviceStatus = _storageService.getDeviceStatus();
      final voiceCommand = await _aiService.processVoiceCommand(voiceInput, deviceStatus);

      print('Voice Command: AI result: "${voiceCommand.result}"');
      print('Voice Command: Success: ${voiceCommand.isSuccess}');

      // ส่งผลลัพธ์
      _commandResultController.add(voiceCommand);

      // เล่นเสียงตอบกลับก่อนเสมอ
      await _playVoiceResponse(voiceCommand);
      
      // ถ้าเป็นคำสั่งควบคุม ให้ทำการควบคุมอุปกรณ์หลังจากเล่นเสียงแล้ว
      if (voiceCommand.isSuccess && _aiService.isControlCommand(voiceInput)) {
        print('Voice Command: Executing control command');
        await _executeControlCommand(voiceInput, voiceCommand);
      }

      // บันทึกคำสั่ง
      await _saveVoiceCommand(voiceCommand);

    } catch (e) {
      print('Voice Command: Error processing command: $e');
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
    }
  }

  // Play voice response
  Future<void> _playVoiceResponse(VoiceCommand command) async {
    try {
      final ttsService = _ttsService;
      if (ttsService != null && command.result.isNotEmpty) {
        await ttsService.speak(command.result);
      }
    } catch (e) {
      print('Error playing voice response: $e');
    }
  }

  // Execute control command
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

    } catch (e) {
      print('Error executing control command: $e');
    }
  }

  // Control methods
  Future<bool> _controlLight(bool turnOn) async {
    try {
      final success = await _apiService.controlLight(turnOn);
      if (success) {
        print('Light control via voice: ${turnOn ? "ON" : "OFF"}');
        _updateDeviceStatusImmediately('relay1', turnOn);
        return true;
      }
      return false;
    } catch (e) {
      print('Error controlling light: $e');
      return false;
    }
  }

  Future<bool> _controlFan(bool turnOn) async {
    try {
      final success = await _apiService.controlFan(turnOn);
      if (success) {
        print('Fan control via voice: ${turnOn ? "ON" : "OFF"}');
        _updateDeviceStatusImmediately('relay2', turnOn);
        return true;
      }
      return false;
    } catch (e) {
      print('Error controlling fan: $e');
      return false;
    }
  }

  Future<bool> _controlAirConditioner(bool turnOn) async {
    try {
      final success = await _apiService.controlAirConditioner(turnOn);
      if (success) {
        print('Air conditioner control via voice: ${turnOn ? "ON" : "OFF"}');
        _updateDeviceStatusImmediately('relay3', turnOn);
        return true;
      }
      return false;
    } catch (e) {
      print('Error controlling air conditioner: $e');
      return false;
    }
  }

  // Update device status immediately
  void _updateDeviceStatusImmediately(String relayName, bool newState) {
    try {
      final currentStatus = _storageService.getDeviceStatus();
      if (currentStatus == null) return;

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
        default:
          return;
      }

      _storageService.saveDeviceStatus(updatedStatus);
      _deviceStatusUpdateController.add(updatedStatus);
    } catch (e) {
      // Silent fail
    }
  }

  // Save voice command
  Future<void> _saveVoiceCommand(VoiceCommand command) async {
    try {
      await _storageService.saveVoiceCommand(command);
    } catch (e) {
      // Silent fail
    }
  }

  // Dispose
  @override
  void dispose() {
    _listeningController.close();
    _transcriptionController.close();
    _commandResultController.close();
    _deviceStatusUpdateController.close();
    super.dispose();
  }
}
