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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('بصارت', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            title: 'Language Selection',
            icon: Icons.language,
            child: Row(
              children: [
                _chip(
                  selected: settings.languageCode == 'en-US',
                  label: 'English',
                  onTap: () => settings.setLanguage('en-US'),
                ),
                const SizedBox(width: 8),
                _chip(
                  selected: settings.languageCode == 'ur-PK',
                  label: 'اردو',
                  onTap: () => settings.setLanguage('ur-PK'),
                ),
              ],
            ),
          ),
          _section(
            title: 'Voice Guide Settings',
            icon: Icons.volume_up,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tile(
                  label: 'Voice Guide',
                  trailing: Switch(
                    value: settings.voiceGuideEnabled,
                    activeColor: Colors.blue,
                    onChanged: settings.toggleVoiceGuide,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Speech Speed', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _chip(
                      selected: settings.speechRate == 0.3,
                      label: 'Slow',
                      onTap: () => settings.setSpeechRate(0.3),
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      selected: settings.speechRate == 0.5,
                      label: 'Normal',
                      onTap: () => settings.setSpeechRate(0.5),
                    ),
                    const SizedBox(width: 8),
                    _chip(
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
            title: 'Theme Mode',
            icon: Icons.color_lens_outlined,
            child: Column(
              children: [
                _tile(
                  label: 'Dark Mode',
                  trailing: Switch(
                    value: false,
                    onChanged: (_) {},
                  ),
                ),
                _tile(
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_announced) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !_announced) {
        final vg = VoiceGuideService();
        await vg.speakIfEnabled(context, 'Settings screen. Adjust language, voice guide, and preferences.');
        _announced = true;
      }
    });
  }

  Widget _section({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _chip({required bool selected, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F1FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.blue : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.blue : Colors.black87, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _tile({required String label, required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          trailing,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
