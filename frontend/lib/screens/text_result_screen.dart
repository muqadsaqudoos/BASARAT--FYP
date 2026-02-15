import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for clipboard
import 'package:provider/provider.dart';
import '../services/voice_guide.dart';
import '../state/app_settings.dart';

class TextResultScreen extends StatelessWidget {
  final String text;

  const TextResultScreen({super.key, required this.text});

  bool _isRtl(String text) {
    final rtlRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');
    return rtlRegex.hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettings>();
    final vg = VoiceGuideService();

    // detect language type
    final isRtl = _isRtl(text);
    final detectedLang = isRtl ? "Urdu" : "English";

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
          "Text Results",
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.insert_drive_file,
              size: 60,
              color: Color(0xFF0B63CE),
            ),
            const SizedBox(height: 16),
            const Text(
              "Text Read Successfully!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Here is the text I found:",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // 📄 Extracted text card – fixed height, scrollable when text is long
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        text.isNotEmpty ? text : "No text detected",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text("Detected: $detectedLang"),
                        backgroundColor: Colors.blue.shade50,
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0B63CE),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 🔊 Read Aloud Button — FIXED
            ElevatedButton.icon(
              onPressed: () async {
                if (text.isEmpty) return;

                // Set language and rate according to detected language
                await vg.setLanguage(isRtl ? "ur-PK" : "en-US");
                await vg.setRate(appSettings.speechRate);

                // Only speaks if voice guide is enabled
                await vg.speakIfEnabled(context, text);
              },
              icon: const Icon(Icons.volume_up),
              label: const Text("Read Aloud"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B63CE),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),

            // 📋 Copy Text Button
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Text copied to clipboard")),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text("Copy Text"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),

            // 🔄 Retake + 🏠 Home buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // back to camera
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retake"),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(140, 50),
                    side: const BorderSide(color: Colors.grey),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text("Home"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B63CE),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 50),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
