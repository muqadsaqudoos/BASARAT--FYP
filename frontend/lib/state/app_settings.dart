import 'package:flutter/foundation.dart';

class AppSettings extends ChangeNotifier {
  bool voiceGuideEnabled = true;
  String languageCode = 'en-US';
  double speechRate = 0.5; // 0.3 slow, 0.5 normal, 0.8 fast
  bool vibrationEnabled = true;

  void toggleVoiceGuide(bool value) {
    voiceGuideEnabled = value;
    notifyListeners();
  }

  void toggleVoiceGuideSwitch() {
    voiceGuideEnabled = !voiceGuideEnabled;
    notifyListeners();
  }

  void setLanguage(String code) {
    languageCode = code;
    notifyListeners();
  }

  void setSpeechRate(double rate) {
    speechRate = rate;
    notifyListeners();
  }

  void setVibration(bool value) {
    vibrationEnabled = value;
    notifyListeners();
  }
}
