import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_settings.dart';
import '../services/voice_guide.dart';
import '../services/voice_command_service.dart';
import 'widgets/app_footer.dart';
import 'widgets/voice_command_status_banner.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _announced = false;
  bool _isAnnouncing = false;
  late final VoiceCommandService _voiceCommandService;
  bool _isVoiceListening = false;
  String? _recognizedCommand;
  String? _statusMessage;
  Timer? _commandDisplayTimer;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _voiceCommandService = VoiceCommandService();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !_announced && !_isAnnouncing) {
        _isAnnouncing = true;
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        final appSettings = context.read<AppSettings>();
        final vg = VoiceGuideService();
        await vg.setLanguage(appSettings.languageCode);
        await vg.setRate(appSettings.speechRate);
        if (!mounted) return;

        final fullMessage = appSettings.languageCode == 'ur-PK'
            ? 'سیٹنگز اسکرین۔ زبان، وائس گائیڈ، اور دیگر ترتیبات ایڈجسٹ کریں۔'
            : 'Settings screen. Adjust language, voice guide, and preferences.';

        await vg.speakIfEnabled(context, fullMessage);

        if (mounted) {
          setState(() {
            _announced = true;
            _isAnnouncing = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _commandDisplayTimer?.cancel();
    _inactivityTimer?.cancel();
    _voiceCommandService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'بصارت',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
          _section(
            context: context,
            title: 'Language Selection',
            icon: Icons.language,
            child: Row(
              children: [
                _chip(
                  context: context,
                  selected: settings.languageCode == 'en-US',
                  label: 'English',
                  onTap: () {
                    settings.setLanguage('en-US');
                    _speakLanguageChange('en-US');
                  },
                ),
                const SizedBox(width: 8),
                _chip(
                  context: context,
                  selected: settings.languageCode == 'ur-PK',
                  label: 'اردو',
                  onTap: () {
                    settings.setLanguage('ur-PK');
                    _speakLanguageChange('ur-PK');
                  },
                ),
              ],
            ),
          ),
          _section(
            context: context,
            title: 'Voice Guide Settings',
            icon: Icons.volume_up,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tile(
                  context: context,
                  label: 'Voice Guide',
                  trailing: Switch(
                    value: settings.voiceGuideEnabled,
                    activeThumbColor: Colors.blue,
                    onChanged: (value) async {
                      settings.toggleVoiceGuide(value);
                      await _speakVoiceGuideToggle(
                        value,
                        settings.languageCode,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Speech Speed',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _chip(
                      context: context,
                      selected: settings.speechRate == 0.3,
                      label: 'Slow',
                      onTap: () => settings.setSpeechRate(0.3),
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      context: context,
                      selected: settings.speechRate == 0.5,
                      label: 'Normal',
                      onTap: () => settings.setSpeechRate(0.5),
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      context: context,
                      selected: settings.speechRate == 0.8,
                      label: 'Fast',
                      onTap: () => settings.setSpeechRate(0.8),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _section(
            context: context,
            title: 'Theme Mode',
            icon: Icons.color_lens_outlined,
            child: Column(
              children: [
                _tile(
                  context: context,
                  label: 'Dark Mode',
trailing: Switch(
                  value: settings.darkModeEnabled,
                  activeThumbColor: Colors.blue,
                  onChanged: settings.setDarkMode,
                  ),
                ),
                _tile(
                  context: context,
                  label: 'Vibration',
                  trailing: Switch(
                    value: settings.vibrationEnabled,
                    activeThumbColor: Colors.blue,
                    onChanged: settings.setVibration,
                  ),
                ),
              ],
            ),
          ),
          _section(
            context: context,
            title: 'About',
            icon: Icons.info_outline,
            child: Column(
              children: const [
                _InfoRow(label: 'App Version', value: '1.0.0'),
                _InfoRow(label: 'Developer', value: 'Basarat Team'),
              ],
            ),
          ),
          const SizedBox(height: 100),
            ],
          ),
          if (_recognizedCommand != null || _statusMessage != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 90,
              child: VoiceCommandStatusBanner(
                statusMessage: _statusMessage,
                recognizedCommand: _recognizedCommand,
              ),
            ),
        ],
      ),
      bottomNavigationBar: AppFooter(
        onHome: () => Navigator.pop(context),
        onHelp: () => _showHelpDialog(context),
        micButton: GestureDetector(
          onTap: _handleMicPress,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFF0B63CE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isVoiceListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // -------------------- Helpers --------------------

  Future<void> _speakLanguageChange(String code) async {
    final settings = context.read<AppSettings>();
    if (!settings.voiceGuideEnabled) return;

    final vg = VoiceGuideService();
    await vg.setLanguage(code);
    await vg.setRate(settings.speechRate);
    await vg.speak(
      code == 'ur-PK'
          ? 'زبان اردو میں تبدیل کر دی گئی۔'
          : 'Language switched to English.',
    );
  }

  Future<void> _speakVoiceGuideToggle(bool enabled, String code) async {
    if (!enabled) return;
    final vg = VoiceGuideService();
    await vg.setLanguage(code);
    await vg.speak(
      code == 'ur-PK' ? 'وائس گائیڈ فعال ہے۔' : 'Voice guide enabled.',
    );
  }

  void _clearRecognizedCommand() {
    if (!mounted) return;
    setState(() {
      _recognizedCommand = null;
      _statusMessage = null;
    });
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 120), () async {
      if (mounted && _isVoiceListening) {
        await _voiceCommandService.stopListening();
        if (!mounted) return;
        _commandDisplayTimer?.cancel();
        final appSettings = context.read<AppSettings>();
        if (appSettings.voiceGuideEnabled) {
          final vg = VoiceGuideService();
          await vg.speakIfEnabled(
            context,
            appSettings.languageCode == 'ur-PK'
                ? 'غیر فعال ہونے کی وجہ سے وائس کمانڈز بند کردی گئیں۔'
                : 'Voice commands turned off due to inactivity.',
          );
        }
        if (!mounted) return;
        setState(() {
          _isVoiceListening = false;
          _recognizedCommand = null;
          _statusMessage = null;
        });
      }
    });
  }

  void _resetInactivityTimer() {
    if (_isVoiceListening) _startInactivityTimer();
  }

  Future<void> _handleMicPress() async {
    final appSettings = context.read<AppSettings>();
    final vg = VoiceGuideService();

    if (_isVoiceListening) {
      await _voiceCommandService.stopListening();
      _commandDisplayTimer?.cancel();
      _inactivityTimer?.cancel();
      setState(() {
        _isVoiceListening = false;
        _recognizedCommand = null;
        _statusMessage = null;
      });
      return;
    }

    final ok = await _voiceCommandService.requestMicrophonePermission();
    if (!ok) {
      debugPrint('Microphone permission not granted; voice not started.');
      return;
    }
    if (!mounted) return;

    setState(() => _isVoiceListening = true);
    _startInactivityTimer();

    await vg.speakIfEnabled(
      context,
      appSettings.languageCode == 'ur-PK' ? 'سن رہا ہوں۔' : 'Listening',
    );
    if (!mounted) return;

    final started = await _voiceCommandService.startListening(
      context: context,
      onPartialResult: (command) {
        if (mounted) {
          setState(() {
            _recognizedCommand = command;
            _statusMessage = null;
          });
          _commandDisplayTimer?.cancel();
          _resetInactivityTimer();
        }
      },
      onStatus: (status) {
        if (mounted) setState(() => _statusMessage = status);
      },
      onResult: (command) async {
        if (!mounted) return;
        _resetInactivityTimer();
        _commandDisplayTimer?.cancel();
        _commandDisplayTimer = Timer(
          const Duration(seconds: 2),
          _clearRecognizedCommand,
        );
        await _voiceCommandService.handleVoiceCommand(
          command: command,
          context: context,
          appSettings: appSettings,
          onStopListening: () {
            if (mounted) {
              _commandDisplayTimer?.cancel();
              _inactivityTimer?.cancel();
              setState(() {
                _isVoiceListening = false;
                _recognizedCommand = null;
                _statusMessage = null;
              });
            }
          },
        );
      },
    );

    if (!mounted) return;
    if (!started) {
      _inactivityTimer?.cancel();
      setState(() {
        _isVoiceListening = false;
        _recognizedCommand = null;
        _statusMessage = null;
      });
    }
  }

  void _showHelpDialog(BuildContext context) async {
    final appSettings = context.read<AppSettings>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Help'),
        content: const Text(
          'Settings Screen:\n\n'
          '• Change language\n'
          '• Enable/disable voice guide\n'
          '• Adjust speech speed\n'
          '• Toggle dark mode and vibration',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (appSettings.voiceGuideEnabled) {
      final vg = VoiceGuideService();
      await vg.setLanguage(appSettings.languageCode);
      await vg.setRate(appSettings.speechRate);
      await vg.speak(
        appSettings.languageCode == 'ur-PK'
            ? 'سیٹنگز اسکرین ہیلپ۔ زبان، وائس گائیڈ، اور دیگر ترتیبات ایڈجسٹ کریں۔'
            : 'Settings screen help. Adjust language, voice guide, and preferences.',
      );
    }
  }
}

// -------------------- WIDGETS --------------------
Widget _section({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Widget child,
}) {
  final theme = Theme.of(context);
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha:
            theme.brightness == Brightness.light ? 0.06 : 0.2,
          ),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

Widget _chip({
  required BuildContext context,
  required bool selected,
  required String label,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE8F1FF) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? Colors.blue : theme.dividerColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.blue : theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

Widget _tile({
  required BuildContext context,
  required String label,
  required Widget trailing,
}) {
  final theme = Theme.of(context);
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        trailing,
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
