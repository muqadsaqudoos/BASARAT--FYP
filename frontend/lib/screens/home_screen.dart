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
  bool _announced = false;
  bool _isAnnouncing = false;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;
  String? _recognizedCommand; // Store recognized command for display
  String? _statusMessage; // Store status message (restarting, connecting, etc.)
  Timer? _commandDisplayTimer; // Timer to clear command display
  Timer? _inactivityTimer; // Timer to auto-stop after inactivity

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
    // Announce only once when screen is first created
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !_announced && !_isAnnouncing) {
        _isAnnouncing = true;
        // Wait a bit to ensure screen is fully loaded and no conflicts
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        
        final settings = Provider.of<AppSettings>(context, listen: false);
        if (settings.voiceGuideEnabled && mounted) {
          final vg = VoiceGuideService();
          // Ensure the full message is spoken completely
          final fullMessage = 'Home screen. Choose a feature: Object Detection or Text Reading.';
          print('Home screen: About to speak: "$fullMessage"');
          await vg.speakIfEnabled(context, fullMessage);
          print('Home screen: Finished speaking');
        }
        if (mounted) {
          setState(() {
            _announced = true;
            _isAnnouncing = false;
          });
        }
      }
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
    if (mounted) {
      setState(() {
        _recognizedCommand = null;
        _statusMessage = null;
      });
    }
  }
  
  void _startInactivityTimer() {
    // Cancel any existing inactivity timer
    _inactivityTimer?.cancel();
    
    // Start new timer - auto-stop after 2 minutes (120 seconds) of no input
    _inactivityTimer = Timer(const Duration(seconds: 120), () async {
      if (mounted && _isListening) {
        print('=== INACTIVITY TIMEOUT - AUTO-STOPPING VOICE COMMANDS ===');
        
        // Stop listening
        await _voiceCommandService.stopListening();
        _rippleController.stop();
        _commandDisplayTimer?.cancel();
        
        // Announce that voice commands have been turned off
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
      }
    });
  }
  
  void _resetInactivityTimer() {
    // Reset the inactivity timer whenever speech is detected
    if (_isListening) {
      _startInactivityTimer();
    }
  }

  Future<void> _handleMicrophoneClick() async {
    final appSettings = context.read<AppSettings>();
    
    if (_isListening) {
      // Stop listening
      await _voiceCommandService.stopListening();
      _rippleController.stop();
      _commandDisplayTimer?.cancel();
      _inactivityTimer?.cancel(); // Cancel inactivity timer when manually stopping
      setState(() {
        _isListening = false;
        _recognizedCommand = null; // Clear command display when stopping
        _statusMessage = null; // Clear status when stopping
      });
      return;
    }

    // CRITICAL: Request microphone permission FIRST, directly from user gesture
    // This MUST happen in the button click handler for browser to show prompt
    final hasPermission = await _voiceCommandService.requestMicrophonePermission();
    
    if (!hasPermission) {
      // Permission was denied - show instructions
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Microphone Permission Denied'),
            content: const Text(
              'Microphone access was denied. To enable voice commands:\n\n'
              '1. Click the lock/info icon in your browser address bar\n'
              '2. Find "Microphone" and change it to "Allow"\n'
              '3. Refresh this page and try again\n\n'
              'Or go to browser settings and allow microphone for localhost.',
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
      return;
    }

    // Permission granted! Now start listening
    print('Permission granted, starting voice recognition...');
    setState(() {
      _isListening = true;
    });
    _rippleController.repeat(); // Start ripple animation

    // Start inactivity timer
    _startInactivityTimer();

    // Just say "listening" and start immediately
    final vg = VoiceGuideService();
    await vg.setLanguage(appSettings.languageCode);
    await vg.setRate(appSettings.speechRate);
    await vg.speak('Listening');
    print('Voice guide said "Listening", now starting speech recognition...');

    print('About to start listening...');
    await _voiceCommandService.startListening(
      onPartialResult: (command) {
        // Update recognized command in real-time for display - show ALL detected text
        if (mounted) {
          setState(() {
            _recognizedCommand = command;
            _statusMessage = null; // Clear status when we get new text
          });
          // Cancel any existing timer
          _commandDisplayTimer?.cancel();
          // Reset inactivity timer whenever we detect speech
          _resetInactivityTimer();
        }
      },
      onStatus: (status) {
        // Show status updates (restarting, connecting, etc.)
        if (mounted) {
          setState(() {
            _statusMessage = status;
          });
        }
      },
      onResult: (command) async {
        if (!mounted) return;
        
        // Debug: print what was recognized
        print('=== RECOGNIZED COMMAND: $command ===');
        
        // Reset inactivity timer since we received a command
        _resetInactivityTimer();
        
        // Clear command display after a delay
        _commandDisplayTimer?.cancel();
        _commandDisplayTimer = Timer(const Duration(seconds: 2), () {
          _clearRecognizedCommand();
        });
        
        // Process the command but keep listening
        if (mounted) {
          await _voiceCommandService.handleVoiceCommand(
            command: command,
            context: context,
            appSettings: appSettings,
            onStopListening: () {
              // Callback to stop listening and update UI when voice_command_off is executed
              if (mounted) {
                _rippleController.stop();
                _commandDisplayTimer?.cancel();
                _inactivityTimer?.cancel();
                setState(() {
                  _isListening = false;
                  _recognizedCommand = null;
                  _statusMessage = null;
                });
              }
            },
          );
          // After processing, continue listening if still mounted
          if (mounted && _isListening) {
            // Continue listening - don't stop
          }
        }
      },
      onError: (error) {
        print('=== ERROR IN VOICE COMMAND: $error ===');
        if (!mounted) return;
        _rippleController.stop();
        _inactivityTimer?.cancel(); // Cancel inactivity timer on error
        setState(() {
          _isListening = false;
        });
        if (mounted) {
          // Show a dialog with instructions if it's a permission error
          if (error.contains('permission') || error.contains('Microphone')) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Microphone Permission Required'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('To use voice commands, please allow microphone access:'),
                    const SizedBox(height: 16),
                    const Text('1. Look for a microphone icon in your browser address bar'),
                    const Text('2. Click on it and select "Allow"'),
                    const Text('3. Refresh the page and try again'),
                    const SizedBox(height: 16),
                    const Text(
                      'If you don\'t see the icon, check your browser settings:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('• Chrome: Settings > Privacy > Site Settings > Microphone'),
                    const Text('• Edge: Settings > Cookies and site permissions > Microphone'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Voice command error: $error'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Welcome Message - Centered
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
                            color: Color(0xFF1565C0), // Dark blue
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Choose a feature to explore the world around you",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Feature Cards
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
                      ],
                    ),
                  ),
                ),

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
          
          // Command/Status Display (positioned above bottom nav bar)
          if (_recognizedCommand != null || _statusMessage != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 90, // Above bottom nav bar
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _statusMessage != null 
                      ? Colors.orange.shade50 
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _statusMessage != null 
                        ? Colors.orange.shade200 
                        : Colors.blue.shade200, 
                    width: 1
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                      size: 20
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage != null
                            ? _statusMessage!
                            : 'Detected: "$_recognizedCommand"',
                        style: TextStyle(
                          color: _statusMessage != null 
                              ? Colors.orange.shade900 
                              : Colors.blue.shade900,
                          fontSize: 14,
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
              // Microphone Icon (Active) with Ripple Effect
              _buildMicrophoneButton(),
              // Help Icon
              IconButton(
                onPressed: () {
                  _showHelpDialog(context);
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

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Help & Guide'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How to use بصارت:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.visibility,
                  title: 'Object Detection',
                  description: 'Tap the Object Detection card to identify objects around you using your camera.',
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.document_scanner,
                  title: 'Text Reading',
                  description: 'Tap the Text Reading card to scan and read text from documents or signs.',
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.mic,
                  title: 'Voice Commands',
                  description: 'Tap the microphone button in the bottom navigation to use voice commands. Say "object detection", "text reading" to navigate.',
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.volume_up,
                  title: 'Voice Guide',
                  description: 'Tap the speaker button (top right) to hear screen descriptions and announcements.',
                ),
                const SizedBox(height: 12),
                _buildHelpItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  description: 'Tap the settings icon (top right) to customize language, voice speed, and other preferences.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMicrophoneButton() {
    return SizedBox(
      width: 80, // Fixed width to contain ripple
      height: 80, // Fixed height to contain ripple
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Ripple effect when listening - constrained to button area
          if (_isListening)
            Positioned(
              child: AnimatedBuilder(
                animation: _rippleAnimation,
                builder: (context, child) {
                  return Container(
                    width: 56 + (_rippleAnimation.value * 15),
                    height: 56 + (_rippleAnimation.value * 15),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withOpacity(1.0 - _rippleAnimation.value),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
          // Main button
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
