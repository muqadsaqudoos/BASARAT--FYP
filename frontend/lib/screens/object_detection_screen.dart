import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/voice_guide.dart';
import '../state/app_settings.dart';

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
        ResolutionPreset.medium,
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
          Column(
            children: [
              // Header
              Container(
                color: Colors.black,
                padding: const EdgeInsets.fromLTRB(24, 44, 24, 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "Object Detection",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // Main content area
              Expanded(
                child: Container(
                  color: const Color.fromARGB(255, 10, 44, 78),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 16, color: const Color.fromARGB(255, 10, 44, 78)),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 16, color: const Color.fromARGB(255, 10, 44, 78)),
                      ),
                      Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: MediaQuery.of(context).size.height * 0.35,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 10, 44, 78),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color.fromARGB(255, 141, 142, 143),
                              width: 3,
                            ),
                          ),
                          child: _buildCameraArea(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action area
              Container(
                color: Colors.black,
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Capture button
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
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                      ),
                    ),

                    // Speaker to the right
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(color: Color(0xFF0B63CE), shape: BoxShape.circle),
                          child: IconButton(
                            onPressed: () async {
                              if (!appSettings.voiceGuideEnabled) return;
                              final vg = VoiceGuideService();
                              await vg.setLanguage(appSettings.languageCode);
                              await vg.setRate(appSettings.speechRate);
                              await vg.speak('Object Detection screen. Camera preview. Tap capture to detect objects.');
                            },
                            icon: const Icon(Icons.volume_up, color: Colors.white, size: 24),
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

          // Bottom nav (full width)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: EdgeInsets.zero,
              height: 70,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.home_outlined, color: Color(0xFF0B63CE), size: 24),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: Color(0xFF0B63CE), shape: BoxShape.circle),
                    child: IconButton(
                      onPressed: _handleMicrophone,
                      icon: const Icon(Icons.mic, color: Colors.white, size: 24),
                    ),
                  ),
                  IconButton(
                    onPressed: _showHelp,
                    icon: const Icon(Icons.help_outline, color: Color(0xFF0B63CE), size: 24),
                  ),
                ],
              ),
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
        await vg.speakIfEnabled(context, 'Object Detection screen. Camera preview. Tap capture to detect objects.');
        _announced = true;
      }
    });
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.camera_alt, color: Colors.grey, size: 60),
        SizedBox(height: 16),
        Text("Camera loading...", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildCameraHint() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.center_focus_strong, color: Colors.grey, size: 60),
        SizedBox(height: 16),
        Text(
          "Point your camera at the object and tap capture",
          style: TextStyle(color: Colors.grey, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCameraArea() {
    if (_isLoading) return _buildLoadingState();
    if (_cameraError || _cameraController == null) return _buildCameraHint();
    return FutureBuilder<void>(
      future: _initializeCameraFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingState();
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _cameraController!.value.previewSize?.height ?? 300,
              height: _cameraController!.value.previewSize?.width ?? 300,
              child: CameraPreview(_cameraController!),
            ),
          ),
        );
      },
    );
  }

  void _captureImage() {
    if (_cameraController == null) return;
    () async {
      try {
        await _initializeCameraFuture;
        final file = await _cameraController!.takePicture();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image captured: ${file.name}')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    }();
  }

  void _toggleSpeaker() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Speaker toggled"),
      backgroundColor: Color(0xFF0B63CE),
    ));
  }

  void _handleMicrophone() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Microphone activated"),
      backgroundColor: Color(0xFF0B63CE),
    ));
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Object Detection Help"),
        content: const Text(
          "1. Point your camera at the object you want to detect\n"
          "2. Tap the capture button\n"
          "3. The app will detect and announce the object",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Got it")),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
