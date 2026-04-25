import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/voice_guide.dart';
import '../services/voice_command_service.dart';
import '../state/app_settings.dart';
import 'text_result_screen.dart';
import 'widgets/app_footer.dart';
import 'widgets/voice_command_status_banner.dart';

class TextReaderScreen extends StatefulWidget {
  const TextReaderScreen({super.key});

  @override
  State<TextReaderScreen> createState() => _TextReaderScreenState();
}

class _TextReaderScreenState extends State<TextReaderScreen> {
  bool _isLoading = true;
  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;
  bool _cameraError = false;

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
    _initializeCamera();
    _announceScreen(); // Announce screen on load
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _initializeCameraFuture = controller.initialize();
      await _initializeCameraFuture;

      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _announceScreen() async {
    final appSettings = context.read<AppSettings>();
    if (!appSettings.voiceGuideEnabled) return;

    final vg = VoiceGuideService();
    await vg.setLanguage(appSettings.languageCode);
    await vg.setRate(appSettings.speechRate);

    final message = appSettings.languageCode == 'ur-PK'
        ? 'ٹیکسٹ ریڈنگ اسکرین۔ متن پڑھنے کے لیے کیپچر پر ٹیپ کریں۔'
        : 'Text Reading screen. Tap capture to read text.';
    await vg.speak(message);
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

  Future<void> _handleFooterMic() async {
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
        final appSettings = context.read<AppSettings>();
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

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettings>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _isLoading || _cameraError || _cameraController == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<void>(
                    future: _initializeCameraFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return CameraPreview(_cameraController!);
                    },
                  ),
          ),
          Column(
            children: [
              // HEADER
              Container(
                color: Colors.black.withOpacity(0.5),
                padding: const EdgeInsets.fromLTRB(24, 44, 24, 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Spacer(),
                    const Text(
                      "Text Reading",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const Spacer(),
              // CAPTURE + SPEAKER
              Container(
                color: Colors.black.withOpacity(0.5),
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: _captureAndRecognize,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0B63CE),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () async {
                              if (!appSettings.voiceGuideEnabled) return;
                              final vg = VoiceGuideService();
                              await vg.setLanguage(appSettings.languageCode);
                              await vg.setRate(appSettings.speechRate);
                              final message =
                                  appSettings.languageCode == 'ur-PK'
                                  ? 'ٹیکسٹ ریڈنگ اسکرین۔ متن پڑھنے کے لیے کیپچر پر ٹیپ کریں۔'
                                  : 'Text Reading screen. Tap capture to read text.';
                              await vg.speak(message);
                            },
                            icon: const Icon(
                              Icons.volume_up,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 90),
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
      // FOOTER
      bottomNavigationBar: AppFooter(
        onHome: () => Navigator.pop(context),
        onHelp: () => _showHelpDialog(context),
        micButton: GestureDetector(
          onTap: _handleFooterMic,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.blue,
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

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Help'),
        content: const Text(
          'Text Reading:\n\n'
          '• Point camera at text\n'
          '• Tap capture button\n'
          '• App will read detected text',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndRecognize() async {
    if (_cameraController == null) return;

    try {
      await _initializeCameraFuture;
      final file = await _cameraController!.takePicture();

      final inputImage = InputImage.fromFilePath(file.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;

      // Speak the recognized text in selected language
      final appSettings = context.read<AppSettings>();
      if (appSettings.voiceGuideEnabled && recognizedText.text.isNotEmpty) {
        final vg = VoiceGuideService();
        await vg.setLanguage(appSettings.languageCode);
        await vg.setRate(appSettings.speechRate);
        await vg.speak(recognizedText.text);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextResultScreen(text: recognizedText.text),
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _commandDisplayTimer?.cancel();
    _inactivityTimer?.cancel();
    _cameraController?.dispose();
    _voiceCommandService.dispose();
    super.dispose();
  }
}
