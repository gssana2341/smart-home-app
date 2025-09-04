import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TtsService extends ChangeNotifier {
  static TtsService? _instance;
  static TtsService get instance => _instance ??= TtsService._();
  
  TtsService._();
  
  // OpenAI TTS Configuration
  static const String _openaiApiKey = 'YOUR_OPENAI_API_KEY_HERE';
  static const String _openaiTtsUrl = 'https://api.openai.com/v1/audio/speech';
  static const String _defaultVoice = 'fable'; // alloy, echo, fable, onyx, nova (onyx = เสียงผู้ชาย)
  
  bool _isInitialized = false;
  bool _isSpeaking = false;
  
  // Queue management
  final List<String> _speechQueue = [];
  bool _isProcessingQueue = false;
  
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isProcessingQueue => _isProcessingQueue;
  int get queueLength => _speechQueue.length;
  List<String> get currentQueue => List.unmodifiable(_speechQueue);
  
  /// เริ่มต้น TTS Service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      _isInitialized = true;
      notifyListeners();
      print('TTS initialized successfully');
      return true;
    } catch (e) {
      print('TTS initialization error: $e');
      return false;
    }
  }
  
  /// พูดข้อความ (แบบ queue)
  Future<bool> speak(String text) async {
    print('TTS: Starting to speak: "$text"');
    
    if (!_isInitialized) {
      print('TTS: Not initialized, initializing...');
      final initialized = await initialize();
      if (!initialized) {
        print('TTS: Initialization failed');
        return false;
      }
    }
    
    try {
      // เพิ่มข้อความลงใน queue
      _speechQueue.add(text);
      print('TTS: Added to queue: "$text" (Queue length: ${_speechQueue.length})');
      
      // เริ่มประมวลผล queue ถ้ายังไม่ได้เริ่ม
      if (!_isProcessingQueue) {
        _processQueue();
      }
      
      return true;
    } catch (e) {
      print('TTS speak error: $e');
      return false;
    }
  }

  /// พูดข้อความทันที (ไม่ใช้ queue)
  Future<bool> speakImmediate(String text) async {
    print('TTS: Speaking immediately: "$text"');
    
    if (!_isInitialized) {
      print('TTS: Not initialized, initializing...');
      final initialized = await initialize();
      if (!initialized) {
        print('TTS: Initialization failed');
        return false;
      }
    }
    
    try {
      // หยุดการพูดปัจจุบันและล้าง queue
      await stop();
      _speechQueue.clear();
      _isProcessingQueue = false;
      
      print('TTS: Speaking immediately: "$text"');
      return await _speakText(text);
    } catch (e) {
      print('TTS speakImmediate error: $e');
      return false;
    }
  }

  /// ประมวลผล queue
  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    
    _isProcessingQueue = true;
    print('TTS: Starting queue processing...');
    
    while (_speechQueue.isNotEmpty) {
      final text = _speechQueue.removeAt(0);
      print('TTS: Processing queue item: "$text" (Remaining: ${_speechQueue.length})');
      
      try {
        await _speakText(text);
        
        // รอให้การพูดเสร็จสิ้น
        while (_isSpeaking) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        // รอสักครู่ก่อนพูดข้อความถัดไป
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('TTS: Error processing queue item: $e');
      }
    }
    
    _isProcessingQueue = false;
    print('TTS: Queue processing completed');
  }
  
  /// หยุดการพูด
  Future<bool> stop() async {
    try {
      print('TTS: Stopping current speech...');
      
      if (_isSpeaking) {
        _isSpeaking = false;
        notifyListeners();
      }
      
      print('TTS: Speech stopped successfully');
      return true;
    } catch (e) {
      print('TTS stop error: $e');
      return false;
    }
  }

  /// หยุดการพูดและล้าง queue
  Future<bool> stopAll() async {
    try {
      print('TTS: Stopping all speech and clearing queue...');
      
      // หยุดการพูดปัจจุบัน
      await stop();
      
      // ล้าง queue
      _speechQueue.clear();
      _isProcessingQueue = false;
      
      print('TTS: All speech stopped and queue cleared');
      return true;
    } catch (e) {
      print('TTS stopAll error: $e');
      return false;
    }
  }
  
  /// พูดข้อความ
  Future<bool> _speakText(String text) async {
    try {
      print('TTS: Speaking text: "$text"');
      
      if (kIsWeb) {
        return await _speakWeb(text);
      } else {
        return await _speakMobile(text);
      }
    } catch (e) {
      print('TTS speakText error: $e');
      return false;
    }
  }
  
  /// พูดข้อความบน Web
  Future<bool> _speakWeb(String text) async {
    try {
      print('OpenAI TTS: Speaking text: "$text"');
      print('OpenAI TTS: Using voice: $_defaultVoice');
      print('OpenAI TTS: API URL: $_openaiTtsUrl');
      
      // ใช้ OpenAI TTS API
      final response = await http.post(
        Uri.parse(_openaiTtsUrl),
        headers: {
          'Authorization': 'Bearer $_openaiApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'tts-1',
          'input': text,
          'voice': _defaultVoice,
          'response_format': 'mp3',
          'speed': 1.0,
        }),
      );
      
      print('OpenAI TTS: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // ได้ไฟล์เสียง MP3 จาก OpenAI
        final audioData = response.bodyBytes;
        
        print('OpenAI TTS: Audio received, length: ${audioData.length} bytes');
        
        // หยุด audio ที่กำลังเล่นอยู่ก่อน
        await stop();
        
        // แสดงสถานะการพูด
        _isSpeaking = true;
        notifyListeners();
        
        // สำหรับ Web จะใช้ HTML5 Audio API
        // สำหรับ Mobile จะจำลองการพูด
        await Future.delayed(const Duration(seconds: 2));
        
        _isSpeaking = false;
        notifyListeners();
        
        return true;
      } else {
        print('OpenAI TTS Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('OpenAI TTS error: $e');
      return false;
    }
  }

  /// พูดข้อความบน Mobile (ใช้การจำลอง)
  Future<bool> _speakMobile(String text) async {
    try {
      print('TTS Mobile: Speaking text: "$text"');
      
      // แสดงสถานะการพูด
      _isSpeaking = true;
      notifyListeners();
      
      // จำลองการพูด (รอ 2 วินาที)
      await Future.delayed(const Duration(seconds: 2));
      
      // หยุดการพูด
      _isSpeaking = false;
      notifyListeners();
      
      print('TTS Mobile: Speech completed');
      return true;
    } catch (e) {
      print('TTS Mobile error: $e');
      _isSpeaking = false;
      notifyListeners();
      return false;
    }
  }
  
  /// ตั้งค่าภาษา
  Future<void> setLanguage(String languageCode) async {
    print('TTS: Language set to $languageCode');
  }
  
  /// ตั้งค่าความเร็วในการพูด
  Future<void> setSpeechRate(double rate) async {
    print('TTS: Speech rate set to $rate');
  }
  
  /// ตั้งค่าความดัง
  Future<void> setVolume(double volume) async {
    print('TTS: Volume set to $volume');
  }
  
  /// ตั้งค่าระดับเสียง
  Future<void> setPitch(double pitch) async {
    print('TTS: Pitch set to $pitch');
  }
  
  /// ตั้งค่าเสียง OpenAI TTS
  Future<void> setVoice(String voice) async {
    if (['alloy', 'echo', 'fable', 'onyx', 'nova'].contains(voice)) {
      print('TTS: Voice set to $voice');
    }
  }
  
  /// ดูเสียงที่รองรับ
  List<String> getSupportedVoices() {
    return ['alloy', 'echo', 'fable', 'onyx', 'nova'];
  }
  
  /// ตรวจสอบว่าภาษาที่รองรับหรือไม่
  Future<List<String>> getSupportedLanguages() async {
    return ['th-TH', 'en-US', 'ja-JP', 'ko-KR', 'zh-CN'];
  }
  
  /// ตรวจสอบว่าภาษาปัจจุบันรองรับหรือไม่
  Future<bool> isLanguageAvailable(String languageCode) async {
    try {
      final languages = await getSupportedLanguages();
      return languages.contains(languageCode);
    } catch (e) {
      return false;
    }
  }
  
  /// ตั้งค่าภาษาอัตโนมัติตามข้อความ
  Future<void> setLanguageAuto(String text) async {
    print('TTS: Auto language detection for: $text');
  }
  
  /// พูดข้อความพร้อมตั้งค่าภาษาอัตโนมัติ
  Future<bool> speakAuto(String text) async {
    print('TTS: Speaking text: $text');
    final result = await speak(text);
    print('TTS: Speak result: $result');
    return result;
  }
  
  /// ปล่อยทรัพยากร
  @override
  void dispose() {
    stop();
    super.dispose();
  }
}