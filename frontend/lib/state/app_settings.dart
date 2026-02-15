import 'package:flutter/widgets.dart';

import '../services/voice_guide.dart';

class AppSettings extends ChangeNotifier {
  bool voiceGuideEnabled = true;
  String languageCode = 'en-US';
  double speechRate = 0.5; // 0.3 slow, 0.5 normal, 0.8 fast
  bool vibrationEnabled = true;
  bool darkModeEnabled = false;

  void toggleVoiceGuide(bool value) {
    voiceGuideEnabled = value;
    notifyListeners();
  }

  void toggleVoiceGuideSwitch() {
    voiceGuideEnabled = !voiceGuideEnabled;
    notifyListeners();
  }

  /// Sets language and immediately updates voice guide if enabled
  void setLanguage(String code, {BuildContext? context}) {
    languageCode = code;
    notifyListeners();

    // Immediately switch voice guide if enabled and context is provided
    if (voiceGuideEnabled && context != null) {
      final vg = VoiceGuideService();
      vg.setLanguage(languageCode);
      vg.setRate(speechRate);
      // Optional: say a short confirmation
      final message = languageCode == 'ur-PK'
          ? 'وائس گائیڈ اب اردو میں ہے۔'
          : 'Voice guide is now in English.';
      vg.speak(message);
    }
  }

  void setSpeechRate(double rate) {
    speechRate = rate;
    notifyListeners();
  }

  void setVibration(bool value) {
    vibrationEnabled = value;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    darkModeEnabled = value;
    notifyListeners();
  }

  void toggleDarkMode() {
    darkModeEnabled = !darkModeEnabled;
    notifyListeners();
  }
}
