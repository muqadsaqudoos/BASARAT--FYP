import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/voice_guide.dart';
import '../services/voice_command_service.dart';
import '../state/app_settings.dart';
import 'widgets/app_footer.dart';

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  bool _isLoading = true;
  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;
  bool _cameraError = false;
  bool _announced = false;
  bool _isAnnouncing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    // Announce screen once when initialized
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !_announced && !_isAnnouncing) {
        _isAnnouncing = true;
        final vg = VoiceGuideService();
        await vg.speakIfEnabled(
          context,
          'Object Detection screen. Camera preview. Tap capture to detect objects.',
        );
        if (mounted) {
          setState(() {
            _announced = true;
            _isAnnouncing = false;
          });
        }
      }
    });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettings>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
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
                      "Object Detection",
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
              // Capture + Speaker
              Container(
                color: Colors.black.withOpacity(0.5),
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: _captureImage,
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
                              await vg.speak(
                                'Object Detection screen. Camera preview. Tap capture to detect objects.',
                              );
                            },
                            icon: const Icon(
                              Icons.volume_up,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ],
      ),

      // Footer with enabled mic
      bottomNavigationBar: AppFooter(
        onHome: () => Navigator.pop(context),
        onHelp: () {},
        micButton: GestureDetector(
          onTap: () async {
            final voiceCommandService = VoiceCommandService();
            final appSettings = context.read<AppSettings>();

            final permissionGranted = await voiceCommandService
                .requestMicrophonePermission();
            if (!permissionGranted) return;

            await voiceCommandService.startListening(
              context: context,
              onResult: (command) async {
                await voiceCommandService.handleVoiceCommand(
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

  Future<void> _captureImage() async {
    if (_cameraController == null) return;
    try {
      await _initializeCameraFuture;
      final file = await _cameraController!.takePicture();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image captured: ${file.name}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
