import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_settings.dart';
import '../services/voice_guide.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _announced = false;
  bool _isAnnouncing = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final card = theme.cardColor;

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

      body: ListView(
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
                  onTap: () => settings.setLanguage('en-US'),
                ),
                const SizedBox(width: 8),
                _chip(
                  context: context,
                  selected: settings.languageCode == 'ur-PK',
                  label: 'اردو',
                  onTap: () => settings.setLanguage('ur-PK'),
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
                    activeColor: Colors.blue,
                    onChanged: settings.toggleVoiceGuide,
                  ),
                ),

                const SizedBox(height: 8),
                Text('Speech Speed',
                    style: TextStyle(fontWeight: FontWeight.w600, color: onSurface)),
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
                    activeColor: Colors.blue,
                    onChanged: settings.setDarkMode,
                  ),
                ),
                _tile(
                  context: context,
                  label: 'Vibration',
                  trailing: Switch(
                    value: settings.vibrationEnabled,
                    activeColor: Colors.blue,
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
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !_announced && !_isAnnouncing) {
        _isAnnouncing = true;
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        final vg = VoiceGuideService();
        final fullMessage =
            'Settings screen. Adjust language, voice guide, and preferences.';
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
}

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
          color: Colors.black.withOpacity(theme.brightness == Brightness.light ? 0.06 : 0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(
        color: theme.dividerColor.withOpacity(0.3),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface)),
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
        color: selected
            ? const Color(0xFFE8F1FF)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? Colors.blue : theme.dividerColor,
        ),
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
      color: theme.colorScheme.surfaceVariant ?? theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
    ),
    child: Row(
      children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ))),
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
        color: theme.colorScheme.surfaceVariant ?? theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                )),
          ),
          Text(value, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
        ],
      ),
    );
  }
}
