import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/voice_guide.dart';
import '../services/voice_command_service.dart';
import '../state/app_settings.dart';
import 'text_result_screen.dart';
import 'widgets/app_footer.dart';

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
        ],
      ),
      // FOOTER
      bottomNavigationBar: AppFooter(
        onHome: () => Navigator.pop(context),
        onHelp: () => _showHelpDialog(context),
        micButton: GestureDetector(
          onTap: () async {
            final permissionGranted = await _voiceCommandService
                .requestMicrophonePermission();
            if (!permissionGranted) return;

            if (_voiceCommandService.isListening) {
              await _voiceCommandService.stopListening();
              return;
            }

            await _voiceCommandService.startListening(
              context: context,
              onResult: (command) async {
                final appSettings = context.read<AppSettings>();
                await _voiceCommandService.handleVoiceCommand(
                  command: command,
                  context: context,
                  appSettings: appSettings,
                );
              },
              onError: (error) {
                print('Voice command error: $error');
              },
              onStatus: (status) {
                print('Voice command status: $status');
              },
              onPartialResult: (partial) {
                print('Partial result: $partial');
              },
            );
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: Colors.white),
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
    _cameraController?.dispose();
    _voiceCommandService.dispose();
    super.dispose();
  }
}
