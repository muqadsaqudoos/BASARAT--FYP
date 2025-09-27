import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/voice_guide.dart';
import '../state/app_settings.dart';
import 'text_result_screen.dart'; // ✅ make sure this exists

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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final CameraDescription camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high, // ✅ good quality like WhatsApp scanner
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettings>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 👇 Fullscreen camera preview
          Positioned.fill(
            child: _isLoading || _cameraError || _cameraController == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<void>(
              future: _initializeCameraFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                return CameraPreview(_cameraController!);
              },
            ),
          ),

          // 👇 Overlay UI
          Column(
            children: [
              // Header
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

              // Capture + Speaker buttons
              Container(
                color: Colors.black.withOpacity(0.5),
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Capture Button
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

                    // Speaker
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
                              await vg.speak(
                                  'Text Reading screen. Tap capture to read text.');
                            },
                            icon: const Icon(Icons.volume_up,
                                color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ],
      ),
    );
  }

  /// Capture + OCR
  Future<void> _captureAndRecognize() async {
    if (_cameraController == null) return;
    try {
      await _initializeCameraFuture;
      final file = await _cameraController!.takePicture();

      // ✅ OCR with ML Kit
      final inputImage = InputImage.fromFilePath(file.path);
      final textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin); // auto works for English/Urdu (Arabic script too!)
      final RecognizedText recognizedText =
      await textRecognizer.processImage(inputImage);

      await textRecognizer.close();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextResultScreen(
            text: recognizedText.text, // ✅ only pass recognized text
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
