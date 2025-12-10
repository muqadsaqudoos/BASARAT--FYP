import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../state/app_settings.dart';

class VoiceGuideService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _hasError = false;
  String? _errorMessage;

  /// NEW: Has the engine been warmed-up already?
  bool _isWarmedUp = false;

  VoiceGuideService();

  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  /// NEW: Warm the engine once (super fast startup)
  Future<void> _warmUp() async {
    if (_isWarmedUp) return;
    _isWarmedUp = true;

    try {
      // Speaking empty string warms up the engine silently
      await _tts.speak("");
      await Future.delayed(const Duration(milliseconds: 20));
    } catch (_) {}
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _isInitialized;
    }

    _isInitializing = true;

    try {
      print('=== INITIALIZING TTS ENGINE ===');

      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // NEW: Make TTS return immediately (non-blocking)
      await _tts.awaitSpeakCompletion(false);

      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 80));
      }

      try {
        final engines = await _tts.getEngines;
        print("TTS engines found: ${engines.length}");
      } catch (_) {}

      _isInitialized = true;
      _hasError = false;
      _errorMessage = null;

      print('=== TTS ENGINE INITIALIZED ===');

      // NEW → Warm engine early for instant speech
      _warmUp();

      return true;
    } catch (e, s) {
      print("ERROR initializing TTS: $e\n$s");
      _hasError = true;
      _errorMessage = e.toString();
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (!_isInitialized) await initialize();
    try {
      await _tts.setLanguage(languageCode);
    } catch (_) {}
  }

  Future<void> setRate(double rate) async {
    if (!_isInitialized) await initialize();
    try {
      await _tts.setSpeechRate(rate);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    try {
      // 🔥 Remove blocking delays → instant response
      _tts.stop();

      // warm-up keeps engine hot
      _warmUp();

      print("=== SPEAKING === $text");

      // non-blocking
      _tts.speak(text);

      _hasError = false;
      _errorMessage = null;
    } catch (e, s) {
      print("ERROR SPEAKING: $e\n$s");
      _hasError = true;
      _errorMessage = e.toString();
    }
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    try {
      await _tts.stop();
    } catch (e) {}
  }

  Future<void> speakIfEnabled(BuildContext context, String text) async {
    final settings = context.read<AppSettings>();
    if (!settings.voiceGuideEnabled) {
      print("Voice guide OFF — skipping speech");
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    await setLanguage(settings.languageCode);
    await setRate(settings.speechRate);

    speak(text);
  }
}
