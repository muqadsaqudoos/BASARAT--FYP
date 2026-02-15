import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;

import '../api/detection_api.dart';
import '../services/voice_guide.dart';
import '../state/app_settings.dart';
import 'detection_result_screen.dart';

/// Max dimension for resize before upload (960 or 1280).
const int kMaxImageDimension = 1280;
/// JPEG quality 75–80.
const int kJpegQuality = 77;

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

  /// True while capture → compress → upload → waiting for response.
  bool _isDetecting = false;
  /// Non-null when last request failed: show error UI with Retry / Back.
  String? _detectionError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !_announced && !_isAnnouncing) {
        _isAnnouncing = true;
        final vg = VoiceGuideService();
        await vg.speakIfEnabled(
          context,
          'Object Detection. Tap Capture and Detect to take a photo and detect objects.',
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
        _detectionError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = true;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  /// Compress and resize image; save to temp file. Returns the file.
  Future<File> _compressAndSave(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return File(sourcePath);

    final w = decoded.width;
    final h = decoded.height;
    final max = w > h ? w : h;
    if (max > kMaxImageDimension) {
      final scale = kMaxImageDimension / max;
      decoded = img.copyResize(
        decoded,
        width: (w * scale).round(),
        height: (h * scale).round(),
      );
    }

    final jpeg = img.encodeJpg(decoded, quality: kJpegQuality);
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/detect_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(jpeg);
    return file;
  }

  Future<void> _captureAndDetect() async {
    if (_cameraController == null || _isDetecting) return;

    setState(() {
      _isDetecting = true;
      _detectionError = null;
    });

    File? tempFile;
    try {
      await _initializeCameraFuture;
      final xFile = await _cameraController!.takePicture();
      if (!mounted) return;
      tempFile = await _compressAndSave(xFile.path);
      if (!mounted) return;

      final response = await postDetect(tempFile);
      if (!mounted) return;

      final list = postProcessDetections(response.detections);
      if (!mounted) return;

      setState(() {
        _isDetecting = false;
        _detectionError = null;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetectionResultScreen(detections: list),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDetecting = false;
        _detectionError = 'Detection failed. Check internet or server.';
      });
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }
  }

  void _clearErrorAndRetry() {
    setState(() => _detectionError = null);
    _captureAndDetect();
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettings>();

    if (_detectionError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Object Detection', style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 64, color: Colors.white54),
                const SizedBox(height: 24),
                Text(
                  _detectionError!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: _clearErrorAndRetry,
                      child: const Text('Retry'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _isLoading || _cameraError || _cameraController == null
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : FutureBuilder<void>(
                    future: _initializeCameraFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      }
                      return CameraPreview(_cameraController!);
                    },
                  ),
          ),

          if (_isDetecting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Detecting…', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ),
            ),

          Column(
            children: [
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
              Container(
                color: Colors.black.withOpacity(0.5),
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: _isDetecting ? null : _captureAndDetect,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isDetecting ? Colors.grey : Colors.white,
                            width: 3,
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isDetecting ? Colors.grey : Colors.white,
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
                                'Object Detection. Tap the white button to capture and detect objects.',
                              );
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
