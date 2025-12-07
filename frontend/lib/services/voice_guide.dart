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
  
  VoiceGuideService() {
    // Constructor doesn't initialize - use initialize() method instead
  }

  /// Get error status
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  /// Initialize TTS engine - must be called before first use
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    if (_isInitializing) {
      // Wait for ongoing initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isInitialized;
    }

    _isInitializing = true;
    try {
      print('=== INITIALIZING TTS ENGINE ===');
      
      // Initialize TTS
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // On web, ensure the engine is ready
      if (kIsWeb) {
        // Wait a bit for web TTS to be ready
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Test if TTS is available by getting engines
      try {
        final engines = await _tts.getEngines;
        print('TTS engines available: ${engines.length}');
        if (engines.isEmpty) {
          print('WARNING: No TTS engines found!');
        }
      } catch (e) {
        print('Could not get TTS engines: $e');
      }

      _isInitialized = true;
      _hasError = false;
      _errorMessage = null;
      print('=== TTS ENGINE INITIALIZED SUCCESSFULLY ===');
      return true;
    } catch (e, stackTrace) {
      print('=== ERROR INITIALIZING TTS ENGINE ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      _isInitialized = false;
      _hasError = true;
      _errorMessage = e.toString();
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (!_isInitialized) {
      await initialize();
    }
    try {
      await _tts.setLanguage(languageCode);
    } catch (e) {
      print('Error setting language: $e');
    }
  }

  Future<void> setRate(double rate) async {
    if (!_isInitialized) {
      await initialize();
    }
    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      print('Error setting speech rate: $e');
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    
    // Ensure TTS is initialized before speaking
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        print('ERROR: Cannot speak - TTS not initialized');
        return;
      }
    }

    try {
      // Stop any ongoing speech first
      await _tts.stop();
      // Wait a tiny bit to ensure stop is processed
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Speak the full text
      print('=== SPEAKING FULL TEXT ===');
      print('Text: "$text"');
      final result = await _tts.speak(text);
      print('TTS speak result: $result');
      
      _hasError = false;
      _errorMessage = null;
    } catch (e, stackTrace) {
      print('=== ERROR SPEAKING TEXT ===');
      print('Text: "$text"');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      _hasError = true;
      _errorMessage = e.toString();
      
      // On web, TTS might require user interaction first
      if (kIsWeb) {
        print('TTS error on web - may require user interaction first');
      }
    }
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    try {
      await _tts.stop();
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }

  Future<void> speakIfEnabled(BuildContext context, String text) async {
    final settings = context.read<AppSettings>();
    if (!settings.voiceGuideEnabled) {
      print('Voice guide is disabled in settings');
      return;
    }
    
    // Ensure initialized
    if (!_isInitialized) {
      await initialize();
    }
    
    await setLanguage(settings.languageCode);
    await setRate(settings.speechRate);
    await speak(text);
  }
}
