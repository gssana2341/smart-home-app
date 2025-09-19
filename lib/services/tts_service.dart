import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import 'dart:html' as html;

/// A robust Text-to-Speech service for web, designed to handle the strict
/// autoplay policies of modern mobile browsers.
///
/// It uses an "audio unlock" pattern: on the first user interaction, a silent
/// audio clip is played to gain permission for future, non-user-initiated
/// audio playback. This is essential for scenarios where audio needs to play
/// after an asynchronous delay (e.g., waiting for an API response).
class TtsService extends ChangeNotifier {
  static TtsService? _instance;
  static TtsService get instance => _instance ??= TtsService._();

  TtsService._();

  html.AudioElement? _audioElement;
  bool _isSpeaking = false;
  bool _isUnlocked = false; // Tracks if the audio context has been unlocked
  bool _isInitialized = false; // Tracks if service is initialized

  // Simple speech queue to satisfy callers that show queue size
  final List<String> _queue = <String>[];

  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;
  int get queueLength => _queue.length;

  /// Prepares the service by creating an audio element and setting up a
  /// one-time event listener to unlock audio playback on the first user gesture.
  Future<bool> initialize() async {
    if (_isInitialized && _audioElement != null) return true;

    _audioElement = html.AudioElement();
    _isInitialized = true;
    print('TTS Service Initialized for Web');

    // Listen for the very first user interaction anywhere on the window.
    // Using window-level listeners avoids relying on document.body which can
    // be unavailable in some compilation targets.
    try {
      unawaited(html.window.onClick.first.then((_) => _unlockAudio()));
    } catch (_) {}
    try {
      // Touch events on desktop may not exist; wrap in try to be safe.
      unawaited(html.window.onTouchStart.first.then((_) => _unlockAudio()));
    } catch (_) {}

    return true;
  }

  /// The "unlock" function. Plays a tiny, silent MP3 data URI.
  /// This is called only once upon the first user gesture.
  void _unlockAudio() {
    if (_isUnlocked || _audioElement == null) return;

    print('TTS: Attempting to unlock audio context...');
    // A silent, 1-second MP3 file encoded in Base64.
    const silentAudio = 'data:audio/mpeg;base64,SUQzBAAAAAABEVRYWFgAAAAtAAADY29tbWVudABCaWcgTW9uZXkgT3ducyBJbmMuTERDLiBXYWxsYWNlIFN0cmVldC4gQ29weXJpZ2h0IChDKSAyMDAxAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/80DEAAAAA0gAAAAATEFNRTMuMTAwVVVVVVVVVVVVVUxBTUUzLjEwMFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVf/zQsRbAAADSAAAAABVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVf/zQMSkAAADSAAAAABVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV';
    _audioElement!.src = silentAudio;
    _audioElement!.play().then((_) {
      _isUnlocked = true;
      print('TTS: Audio context unlocked successfully.');
    }).catchError((e) {
      print('TTS: Audio unlock failed. Playback may not work. Error: $e');
    });
  }

  Future<void> speak(String text) async {
    if (_audioElement == null) {
      print('TTS Error: Service not initialized.');
      return;
    }
    if (!_isUnlocked) {
      print('TTS Warning: Audio not unlocked. Sound may be blocked by browser.');
    }
    if (text.trim().isEmpty) return;

    await stop(); // Stop any previous speech

    _isSpeaking = true;
    notifyListeners();

    try {
      final audioBytes = await _fetchOpenAIAudio(text);
      if (audioBytes != null) {
        await _playAudioBytes(audioBytes);
      } else {
        print('TTS Fallback: Using Web Speech API.');
        await _speakWithWebSpeechAPI(text);
      }
    } catch (e) {
      print('TTS speak error: $e');
    } finally {
      if (_isSpeaking) {
        _isSpeaking = false;
        notifyListeners();
      }
    }
  }

  /// Convenience method used by callers expecting a boolean result.
  /// Adds text to an internal queue for visibility and plays immediately.
  Future<bool> speakAuto(String text) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      if (text.trim().isEmpty) return false;
      _queue.add(text);
      notifyListeners();
      await speak(text);
      if (_queue.isNotEmpty) {
        _queue.removeAt(0);
        notifyListeners();
      }
      return true;
    } catch (e) {
      print('TTS speakAuto error: $e');
      return false;
    }
  }

  Future<void> stop() async {
    if (_audioElement != null && !_audioElement!.paused) {
      _audioElement!.pause();
      _audioElement!.src = '';
    }
    html.window.speechSynthesis?.cancel();
    if (_isSpeaking) {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> _fetchOpenAIAudio(String text) async {
    // On web, calling OpenAI from the browser can fail due to CORS and exposes the API key.
    // Skip network TTS on web and fallback to Web Speech API.
    if (kIsWeb) return null;
    if (ApiKeys.openaiApiKey.isEmpty) return null;
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer ${ApiKeys.openaiApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'model': 'tts-1','input': text,'voice': 'alloy'}),
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        // Log and fallback silently
        print('TTS OpenAI HTTP ${response.statusCode}. Falling back to Web Speech API.');
        return null;
      }
    } catch (e) {
      print('TTS OpenAI network error: $e');
      return null;
    }
  }

  Future<void> _playAudioBytes(Uint8List audioBytes) async {
    if (_audioElement == null) return;
    final completer = Completer<void>();
    try {
      final blob = html.Blob([audioBytes], 'audio/mpeg');
      final url = html.Url.createObjectUrlFromBlob(blob);
      _audioElement!.src = url;

      StreamSubscription? endedSubscription, errorSubscription;
      
      var cleanup = () {
        html.Url.revokeObjectUrl(url);
        endedSubscription?.cancel();
        errorSubscription?.cancel();
        if (!completer.isCompleted) completer.complete();
      };

      endedSubscription = _audioElement!.onEnded.listen((_) => cleanup());
      errorSubscription = _audioElement!.onError.listen((_) {
        if (!completer.isCompleted) completer.completeError('Audio playback error');
      });

      _audioElement!.play();
      await completer.future;
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }
  }

  Future<void> _speakWithWebSpeechAPI(String text) async {
    final completer = Completer<void>();
    try {
      final speechSynthesis = html.window.speechSynthesis;
      if (speechSynthesis == null) {
        if(!completer.isCompleted) completer.complete();
        return;
      }
      // Try to select a Thai voice if available
      List<html.SpeechSynthesisVoice> voices = speechSynthesis.getVoices() ?? <html.SpeechSynthesisVoice>[];
      if (voices.isEmpty) {
        // Some browsers load voices asynchronously; wait briefly
        await Future.delayed(const Duration(milliseconds: 200));
        voices = speechSynthesis.getVoices() ?? <html.SpeechSynthesisVoice>[];
      }

      html.SpeechSynthesisVoice? thaiVoice;
      if (voices.isNotEmpty) {
        thaiVoice = voices.firstWhere(
          (v) => (v.lang?.toLowerCase().startsWith('th') ?? false) || (v.name?.toLowerCase().contains('thai') ?? false),
          orElse: () => voices.first,
        );
      }

      final utterance = html.SpeechSynthesisUtterance(text)
        ..lang = thaiVoice?.lang ?? 'th-TH'
        ..voice = thaiVoice
        ..rate = 0.9;
      utterance.onEnd.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      utterance.onError.listen((_) {
        if (!completer.isCompleted) completer.completeError('Web Speech API error');
      });
      speechSynthesis.speak(utterance);
      await completer.future;
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }
  }

  @override
  void dispose() {
    stop();
    _audioElement = null;
    _isInitialized = false;
    super.dispose();
  }
}