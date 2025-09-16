// inside home_screen.dart
import 'package:flutter/material.dart';
import 'text_reader_screen.dart'; 
import 'object_detection_screen.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import '../services/voice_guide.dart';
import '../state/app_settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    final appSettings = context.watch<AppSettings>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const SizedBox(), // Remove default back button
        title: Row(
          children: [
            // App Logo
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.visibility,
                color: Colors.white,
                size: 24,
              ),
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
          // Settings Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
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
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Welcome Message
            const Text(
              "Welcome",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0), // Dark blue
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Choose a feature to explore the world around you",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),

            // Feature Cards
            Expanded(
              child: Column(
                children: [
                  // Object Detection Card
                  _buildFeatureCard(
                    icon: Icons.visibility,
                    title: "Object Detection",
                    description: "Identify objects using your camera",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ObjectDetectionScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Text Reading Card
                  _buildFeatureCard(
                    icon: Icons.document_scanner,
                    title: "Text Reading",
                    description: "Scan and read text from images",
                    onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TextReaderScreen(),
                  ),
                );
              },
                  ),
                  const SizedBox(height: 32),

                  // Screen Description Hint
                  Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xFF9C27B0), // Light purple
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
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
          ],
        ),
      ),
      // Floating Action Button
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () async {
            if (!appSettings.voiceGuideEnabled) {
              appSettings.toggleVoiceGuide(true);
            }
            final vg = VoiceGuideService();
            await vg.setLanguage(appSettings.languageCode);
            await vg.setRate(appSettings.speechRate);
            await vg.speak('Home screen. Choose a feature: Object Detection or Text Reading.');
          },
          icon: const Icon(
            Icons.volume_up,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      // Bottom Navigation Bar
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
              // Home Icon
              IconButton(
                onPressed: () {
                  // Already on home screen
                },
                icon: const Icon(
                  Icons.home_outlined,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              // Microphone Icon (Active)
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    // TODO: Implement microphone functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Microphone - Coming Soon!")),
                    );
                  },
                  icon: const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              // Help Icon
              IconButton(
                onPressed: () {
                  // TODO: Navigate to help
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Help - Coming Soon!")),
                  );
                },
                icon: const Icon(
                  Icons.help_outline,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto announce when entering Home
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = Provider.of<AppSettings>(context, listen: false);
      if (!settings.voiceGuideEnabled) return;
      final vg = VoiceGuideService();
      await vg.speakIfEnabled(context, 'Home screen. Choose a feature: Object Detection or Text Reading.');
    });
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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
