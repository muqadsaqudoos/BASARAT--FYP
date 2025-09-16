import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../state/app_settings.dart';

class VoiceGuideService {
  final FlutterTts _tts = FlutterTts();

  VoiceGuideService() {
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.5);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
  }

  Future<void> setLanguage(String languageCode) async {
    await _tts.setLanguage(languageCode);
  }

  Future<void> setRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> speakIfEnabled(BuildContext context, String text) async {
    final settings = context.read<AppSettings>();
    if (!settings.voiceGuideEnabled) return;
    await setLanguage(settings.languageCode);
    await setRate(settings.speechRate);
    await speak(text);
  }
}
