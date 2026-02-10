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

  /// Error status
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  /// Initialize TTS
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isInitialized;
    }

    _isInitializing = true;

    try {
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _isInitialized = true;
      _hasError = false;
      _errorMessage = null;
      return true;
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Set language with Urdu fallback
  Future<void> setLanguage(String languageCode) async {
    if (!_isInitialized) await initialize();

    try {
      await _tts.stop();

      var result = await _tts.setLanguage(languageCode);

      if (result != 1 && languageCode == 'ur-PK') {
        await _tts.setLanguage('ur-IN');
      }
    } catch (e) {
      debugPrint('Language error: $e');
    }
  }

  /// Set speech rate
  Future<void> setRate(double rate) async {
    if (!_isInitialized) await initialize();
    await _tts.setSpeechRate(rate);
  }

  /// Speak text
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    if (!_isInitialized && !await initialize()) return;

    try {
      await _tts.stop();
      await Future.delayed(const Duration(milliseconds: 50));
      await _tts.speak(text);
      _hasError = false;
      _errorMessage = null;
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    if (_isInitialized) {
      await _tts.stop();
    }
  }

  /// 🔹 NEW: Localized content (English → Urdu)
  String _getLocalizedText(BuildContext context, String englishText) {
    final settings = context.read<AppSettings>();

    if (settings.languageCode != 'ur-PK') {
      return englishText;
    }

    const Map<String, String> urduTexts = {
      'Home screen. Choose a feature: Object Detection or Text Reading.':
          'ہوم اسکرین۔ فیچر منتخب کریں: آبجیکٹ ڈیٹیکشن یا ٹیکسٹ ریڈنگ۔',

      'Listening': 'سن رہا ہوں',

      'Voice commands turned off due to inactivity.':
          'غیر فعالیت کی وجہ سے وائس کمانڈ بند کر دی گئی ہے۔',

      'Settings screen. Adjust language, voice guide, and preferences.':
          'سیٹنگز اسکرین۔ زبان، وائس گائیڈ اور ترجیحات تبدیل کریں۔',

      'Object Detection screen. Camera preview. Tap capture to detect objects.':
          'آبجیکٹ ڈیٹیکشن اسکرین۔ کیمرہ پری ویو۔ تصویر لینے کے لیے بٹن دبائیں۔',

      'Text Reading screen. Capture or select an image to read text.':
          'ٹیکسٹ ریڈنگ اسکرین۔ تصویر لیں یا منتخب کریں تاکہ متن پڑھا جا سکے۔',
    };

    return urduTexts[englishText] ?? englishText;
  }

  /// Speak only if enabled (WITH proper Urdu support)
  Future<void> speakIfEnabled(BuildContext context, String text) async {
    final settings = context.read<AppSettings>();
    if (!settings.voiceGuideEnabled) return;

    if (!_isInitialized) await initialize();

    final localizedText = _getLocalizedText(context, text);

    await setLanguage(settings.languageCode);
    await setRate(settings.speechRate);
    await speak(localizedText);
  }
}
