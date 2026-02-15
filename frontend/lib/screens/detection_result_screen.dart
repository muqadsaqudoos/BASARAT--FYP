import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/detection.dart';
import '../services/voice_guide.dart';
import '../state/app_settings.dart';

/// Minimum confidence to show (configurable). Dedupe by label, keep max score, top 5.
const double kMinConfidence = 0.30;
const int kMaxTopLabels = 5;

/// Words-only result screen: no image, no bounding boxes. Summary + chips with confidence.
class DetectionResultScreen extends StatefulWidget {
  /// Already post-processed: deduped by label, sorted by score desc, top 5, >= kMinConfidence
  final List<DetectionModel> detections;

  const DetectionResultScreen({super.key, required this.detections});

  @override
  State<DetectionResultScreen> createState() => _DetectionResultScreenState();
}

class _DetectionResultScreenState extends State<DetectionResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final appSettings = context.read<AppSettings>();
      if (!appSettings.voiceGuideEnabled) return;
      final vg = VoiceGuideService();
      await vg.setLanguage(appSettings.languageCode);
      await vg.setRate(appSettings.speechRate);
      final summary = widget.detections.isEmpty
          ? 'No objects detected.'
          : 'Detected: ${widget.detections.map((d) => d.label).join(', ')}.';
      await vg.speak(summary);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettings>();
    final vg = VoiceGuideService();
    final detections = widget.detections;

    final bool hasDetections = detections.isNotEmpty;
    final String summaryText = hasDetections
        ? detections.map((d) => d.label).join(', ')
        : 'No objects detected.';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Detected Objects",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              summaryText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (hasDetections)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: detections
                    .map((d) => Chip(
                          label: Text('${d.label} (${(d.score * 100).toStringAsFixed(0)}%)'),
                          backgroundColor: Colors.blue.shade50,
                          side: BorderSide(color: Colors.blue.shade200),
                        ))
                    .toList(),
              )
            else
              const Icon(Icons.visibility_off, size: 48, color: Colors.grey),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Detect Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B63CE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (appSettings.voiceGuideEnabled)
              TextButton.icon(
                onPressed: () async {
                  await vg.setLanguage(appSettings.languageCode);
                  await vg.setRate(appSettings.speechRate);
                  await vg.speak(
                    hasDetections
                        ? 'Detected: $summaryText'
                        : 'No objects detected.',
                  );
                },
                icon: const Icon(Icons.volume_up, size: 20),
                label: const Text('Read aloud'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dedupe by label (keep highest score), sort by score desc, top 5, min confidence.
List<DetectionModel> postProcessDetections(List<DetectionModel> raw, {
  double minConfidence = kMinConfidence,
  int topK = kMaxTopLabels,
}) {
  final byLabel = <String, DetectionModel>{};
  for (final d in raw) {
    if (d.score < minConfidence) continue;
    final existing = byLabel[d.label];
    if (existing == null || d.score > existing.score) {
      byLabel[d.label] = d;
    }
  }
  final list = byLabel.values.toList()..sort((a, b) => b.score.compareTo(a.score));
  return list.take(topK).toList();
}
