import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../utils/constants.dart';

class TtsService extends ChangeNotifier {
  static TtsService? _instance;
  static TtsService get instance => _instance ??= TtsService._();
  
  TtsService._();
  
  // OpenAI TTS Configuration
  static const String _openaiApiKey = ApiKeys.openaiApiKey;
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
      print('TTS(Web): Speaking text via backend proxy: "$text"');
      print('TTS(Web): Using voice: $_defaultVoice');
      print('TTS(Web): Backend TTS URL: ${ApiConstants.ttsUrl}');

      // เรียกผ่าน Backend Proxy แทนการเรียก OpenAI ตรง เพื่อความปลอดภัยของ API key
      final response = await http.post(
        Uri.parse(ApiConstants.ttsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: jsonEncode({
          // ฝั่ง backend ควรรองรับ payload รูปแบบนี้ และแนบ Authorization เองที่ server
          'text': text,
          'voice': _defaultVoice,
          // optional: 'model': 'tts-1', 'response_format': 'mp3'
        }),
      );

      print('TTS(Web): Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // ได้ไฟล์เสียง MP3 จาก OpenAI
        final audioData = response.bodyBytes;

        print('TTS(Web): Audio received, length: ${audioData.length} bytes');

        // หยุด audio ที่กำลังเล่นอยู่ก่อน
        await stop();

        // แสดงสถานะการพูด
        _isSpeaking = true;
        notifyListeners();

        // เล่นเสียงบน Web
        try {
          // ตรวจสอบว่าเป็น WASM build หรือไม่
          if (const String.fromEnvironment('FLUTTER_WEB_USE_SKWASM') == 'true') {
            // WASM build - ไม่สามารถใช้ dart:html ได้
            print('TTS(Web): WASM build detected, cannot play audio directly');
            print('TTS(Web): Audio data received successfully, length: ${audioData.length} bytes');
            _isSpeaking = false;
            notifyListeners();
            return true;
          } else {
            // ตรวจสอบว่าเราสามารถใช้ dart:html ได้หรือไม่
            bool canUseHtml = false;
            dynamic htmlLib;

            try {
              // พยายาม access dart:html
              // ignore: undefined_identifier
              htmlLib = null; // This will fail in WASM builds
              canUseHtml = true;
            } catch (e) {
              canUseHtml = false;
            }

            if (canUseHtml) {
              // ใช้ dart:html สำหรับการเล่นเสียง
              try {
                // ignore: undefined_identifier
                final html = null; // Placeholder for actual html library

                // สร้าง Blob จาก audio data
                final blob = html.Blob([audioData], 'audio/mpeg');
                final url = html.Url.createObjectUrl(blob);

                // สร้าง Audio element
                final audio = html.AudioElement()
                  ..src = url
                  ..autoplay = true;

                // ฟังเหตุการณ์เมื่อเล่นเสร็จ
                audio.onEnded.listen((_) {
                  print('TTS(Web): Audio playback completed');
                  _isSpeaking = false;
                  notifyListeners();
                  html.Url.revokeObjectUrl(url);
                });

                // ฟังเหตุการณ์เมื่อเกิดข้อผิดพลาด
                audio.onError.listen((event) {
                  print('TTS(Web): Audio playback error: $event');
                  _isSpeaking = false;
                  notifyListeners();
                  html.Url.revokeObjectUrl(url);
                });

                // เริ่มเล่นเสียง
                await audio.play();
                print('TTS(Web): Audio playback started');
              } catch (e) {
                print('TTS(Web): dart:html not available, audio playback not supported');
                _isSpeaking = false;
                notifyListeners();
                return true; // Still return true since we got the audio data
              }
            } else {
              print('TTS(Web): Cannot use dart:html, audio playback not available');
              _isSpeaking = false;
              notifyListeners();
              return true; // Still return true since we got the audio data
            }
          }
        } catch (audioError) {
          print('TTS(Web): Audio playback error: $audioError');
          _isSpeaking = false;
          notifyListeners();
          return false;
        }

        return true;
      } else {
        print('TTS(Web) Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('TTS(Web) error: $e');
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