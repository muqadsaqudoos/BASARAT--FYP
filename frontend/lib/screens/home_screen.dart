// inside home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'text_reader_screen.dart';
import 'object_detection_screen.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import '../services/voice_guide.dart';
import '../services/voice_command_service.dart';
import '../state/app_settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final VoiceCommandService _voiceCommandService = VoiceCommandService();
  bool _isListening = false;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  String? _recognizedCommand;
  String? _statusMessage;

  Timer? _commandDisplayTimer;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    // ZERO-LATENCY ANNOUNCEMENT — respects voice guide setting
    Future.microtask(() {
      if (!mounted) return;
      final settings = Provider.of<AppSettings>(context, listen: false);
      if (!settings.voiceGuideEnabled) return;

      VoiceGuideService().speakIfEnabled(
        context,
        "Home screen. Choose a feature: Object Detection or Text Reading.",
      );
    });
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _voiceCommandService.dispose();
    _commandDisplayTimer?.cancel();
    _inactivityTimer?.cancel();
    super.dispose();
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
      if (!mounted || !_isListening) return;

      await _voiceCommandService.stopListening();
      _rippleController.stop();
      _commandDisplayTimer?.cancel();

      final appSettings = context.read<AppSettings>();
      if (appSettings.voiceGuideEnabled) {
        final vg = VoiceGuideService();
        await vg.setLanguage(appSettings.languageCode);
        await vg.setRate(appSettings.speechRate);
        await vg.speak('Voice commands turned off due to inactivity.');
      }

      if (mounted) {
        setState(() {
          _isListening = false;
          _recognizedCommand = null;
          _statusMessage = null;
        });
      }
    });
  }

  void _resetInactivityTimer() {
    if (_isListening) _startInactivityTimer();
  }

  Future<void> _handleMicrophoneClick() async {
    final appSettings = context.read<AppSettings>();

    if (_isListening) {
      await _voiceCommandService.stopListening();
      _rippleController.stop();
      _commandDisplayTimer?.cancel();
      _inactivityTimer?.cancel();

      setState(() {
        _isListening = false;
        _recognizedCommand = null;
        _statusMessage = null;
      });
      return;
    }

    final hasPermission =
        await _voiceCommandService.requestMicrophonePermission();

    if (!hasPermission) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Microphone Permission Denied'),
          content: const Text(
              'Microphone access was denied. To enable voice commands:\n\n'
              '1. Click the lock/info icon in your browser address bar\n'
              '2. Find “Microphone” and change it to “Allow”\n'
              '3. Refresh this page and try again'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isListening = true);
    _rippleController.repeat();
    _startInactivityTimer();

    final vg = VoiceGuideService();
    await vg.setLanguage(appSettings.languageCode);
    await vg.setRate(appSettings.speechRate);
    await vg.speak("Listening");

    await _voiceCommandService.startListening(
      onPartialResult: (command) {
        if (!mounted) return;
        setState(() {
          _recognizedCommand = command;
          _statusMessage = null;
        });
        _commandDisplayTimer?.cancel();
        _resetInactivityTimer();
      },
      onStatus: (status) {
        if (!mounted) return;
        setState(() => _statusMessage = status);
      },
      onResult: (command) async {
        if (!mounted) return;

        _resetInactivityTimer();

        _commandDisplayTimer?.cancel();
        _commandDisplayTimer = Timer(const Duration(seconds: 2), () {
          _clearRecognizedCommand();
        });

        await _voiceCommandService.handleVoiceCommand(
          command: command,
          context: context,
          appSettings: appSettings,
          onStopListening: () {
            if (!mounted) return;

            _rippleController.stop();
            _commandDisplayTimer?.cancel();
            _inactivityTimer?.cancel();

            setState(() {
              _isListening = false;
              _recognizedCommand = null;
              _statusMessage = null;
            });
          },
        );
      },
      onError: (error) {
        if (!mounted) return;

        _rippleController.stop();
        _inactivityTimer?.cancel();

        setState(() => _isListening = false);

        if (error.contains("permission")) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Microphone Permission Required"),
              content: const Text("Enable microphone in browser settings."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Voice command error: $error")),
          );
        }
      },
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettings>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const SizedBox(),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.visibility, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              "بصارت",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.settings, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Welcome",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Choose a feature to explore the world around you",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 40),

                        _buildFeatureCard(
                          icon: Icons.visibility,
                          title: "Object Detection",
                          description: "Identify objects using your camera",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ObjectDetectionScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        _buildFeatureCard(
                          icon: Icons.document_scanner,
                          title: "Text Reading",
                          description: "Scan and read text from images",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TextReaderScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                Row(
                  children: const [
                    Icon(Icons.chat_bubble_outline,
                        color: Color(0xFF9C27B0), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Tap the blue mic button to hear screen descriptions",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_recognizedCommand != null || _statusMessage != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 90,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _statusMessage != null
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _statusMessage != null
                        ? Colors.orange.shade200
                        : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusMessage != null
                          ? Icons.hourglass_empty
                          : Icons.mic,
                      color: _statusMessage != null
                          ? Colors.orange.shade700
                          : Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage ?? 'Detected: "$_recognizedCommand"',
                        style: TextStyle(
                          color: _statusMessage != null
                              ? Colors.orange.shade900
                              : Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),

      // ===================== FIXED FAB =====================
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () async {
            final vg = VoiceGuideService();
            await vg.speakIfEnabled(
              context,
              'Home screen. Choose a feature: Object Detection or Text Reading.',
            );
          },
          icon: const Icon(Icons.volume_up, color: Colors.white, size: 24),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.home_outlined,
                    color: Colors.blue, size: 24),
              ),
              _buildMicrophoneButton(),
              IconButton(
                onPressed: () => _showHelpDialog(context),
                icon: const Icon(Icons.help_outline,
                    color: Colors.blue, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text("Help & Guide"),
          ],
        ),
        content: const Text("Help info here"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it"),
          )
        ],
      ),
    );
  }

  Widget _buildMicrophoneButton() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isListening)
            AnimatedBuilder(
              animation: _rippleAnimation,
              builder: (_, __) => Container(
                width: 56 + (_rippleAnimation.value * 15),
                height: 56 + (_rippleAnimation.value * 15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.withOpacity(1.0 - _rippleAnimation.value),
                    width: 2,
                  ),
                ),
              ),
            ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _isListening ? Colors.red : Colors.blue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _handleMicrophoneClick,
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0))),
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
