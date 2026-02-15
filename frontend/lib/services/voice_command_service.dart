import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'voice_guide.dart';
import '../state/app_settings.dart';
import '../screens/object_detection_screen.dart';
import '../screens/text_reader_screen.dart';
import '../screens/settings_screen.dart';
import 'voice_command_service_web_stub.dart'
    if (dart.library.html) 'voice_command_service_web.dart' as web_utils;

/// Voice Command Service - Complete Implementation
/// 
/// This service handles speech-to-text recognition and command processing.
/// It uses the speech_to_text package which works on web and mobile platforms.
/// 
/// Features:
/// - Real-time speech recognition with partial results
/// - Automatic restart when recognition stops
/// - Command matching with keyword lists
/// - Debouncing to prevent duplicate commands
/// - Error handling and recovery
/// - Status callbacks for UI updates
class VoiceCommandService {
  // Core speech recognition instance
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  // State management
  bool _isListening = false;
  bool _isInitialized = false;
  bool _isRestarting = false;
  
  // Callbacks for UI updates
  Function(String)? _onResultCallback;
  Function(String)? _onErrorCallback;
  Function(String)? _onPartialResultCallback;
  Function(String)? _onStatusCallback;
  BuildContext? _context;
  
  // Debouncing: Track last command to prevent repeated triggers
  String? _lastCommand;
  DateTime? _lastCommandTime;
  static const Duration _debounceDuration = Duration(seconds: 1);
  
  // Restart management: Prevent rapid restarts
  DateTime? _lastRestartTime;
  static const Duration _restartCooldown = Duration(milliseconds: 500);

  /// Command keyword lists - organized by priority (most common first)
  /// Each command has multiple keyword variations for better recognition
  static const Map<String, List<String>> _commandKeywords = {
    'text_reading': [
      'text reading',
      'reading text',
      'read text',
      'readtext',
      'text read',
      'read the text',
      'scan text',
      'text scan',
      'scantext',
      'ocr',
      'read', // Single word - works alone
      'text', // Single word - works alone
    ],
    'object_detection': [
      'object detection',
      'detect object',
      'object detect',
      'detect the object',
      'object recognition',
      'identify object',
      'detection',
      'object',
    ],
    'home': [
      'home',
      'go home',
      'home screen',
      'main screen',
      'back home',
      'home page',
      'go to home',
    ],
    'settings': [
      'settings',
      'setting', // Singular form
      'open settings',
      'open setting',
      'go to settings',
      'go to setting',
      'settings screen',
      'setting screen',
      'preferences',
      'configure',
    ],
    'language_urdu': [
      'urdu',
      'urdu language',
      'change language urdu',
      'set language urdu',
      'switch to urdu',
      'language urdu',
    ],
    'language_english': [
      'english',
      'english language',
      'change language english',
      'set language english',
      'switch to english',
      'language english',
    ],
    'speed_fast': [
      'fast',
      'speed fast',
      'faster',
      'voice fast',
      'increase speed',
    ],
    'speed_slow': [
      'slow',
      'speed slow',
      'slower',
      'voice slow',
      'decrease speed',
    ],
    'speed_normal': [
      'normal',
      'speed normal',
      'medium speed',
      'normal speed',
      'default speed',
    ],
    'dark_mode_on': [
      'dark mode',
      'enable dark mode',
      'turn on dark mode',
      'dark theme',
      'dark',
    ],
    'dark_mode_off': [
      'light mode',
      'disable dark mode',
      'turn off dark mode',
      'light theme',
      'light',
    ],
    'vibration_on': [
      'enable vibration',
      'turn on vibration',
      'vibration on',
      'enable vibrate',
      'turn on vibrate',
      'vibrate',
    ],
    'vibration_off': [
      'disable vibration',
      'turn off vibration',
      'vibration off',
      'disable vibrate',
      'turn off vibrate',
      'no vibration',
    ],
    'voice_command_off': [
      'stop voice command',
      'turn off voice command',
      'stop listening',
      'disable voice command',
      'stop voice commands',
      'turn off voice commands',
      'exit voice command',
      'close voice command',
    ],
    'voice_guide_on': [
      'enable voice guide',
      'turn on voice guide',
      'voice guide on',
      'turn on voice',
      'enable voice',
    ],
    'voice_guide_off': [
      'disable voice guide',
      'turn off voice guide',
      'voice guide off',
      'turn off voice',
      'disable voice',
    ],
  };

  /// Initialize speech recognition engine
  /// Must be called before starting to listen
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }
    
    try {
      print('[VoiceCommand] Initializing speech recognition...');
      final available = await _speech.initialize(
        onError: (error) {
          print('[VoiceCommand] Error: ${error.errorMsg}');
          if (_onErrorCallback != null) {
            _onErrorCallback!(error.errorMsg);
          }
        },
        onStatus: (status) {
          _handleStatusChange(status);
        },
      );
      
      _isInitialized = available;
      print('[VoiceCommand] Initialized: $available');
      return available;
    } catch (e) {
      print('[VoiceCommand] Failed to initialize: $e');
      return false;
    }
  }

  /// Handle status changes from speech recognition
  void _handleStatusChange(String status) {
    print('[VoiceCommand] Status: $status');
    
    if (status == 'listening') {
      if (_onStatusCallback != null) {
        _onStatusCallback!('Listening...');
      }
    } else if (status == 'done') {
      // Recognition session ended - restart if we're supposed to be listening
      _handleRecognitionDone();
    } else if (status == 'notListening') {
      // Temporarily paused - will auto-resume, don't restart immediately
      print('[VoiceCommand] Recognition paused (notListening)');
    }
  }

  /// Handle when recognition is done - restart if needed
  void _handleRecognitionDone() {
    // Only restart if we're still supposed to be listening
    if (!_isListening || _isRestarting) {
      return;
    }

    // Check if we have all required callbacks and context
    if (_onResultCallback == null || 
        _onErrorCallback == null || 
        _context == null) {
      print('[VoiceCommand] Cannot restart - missing callbacks or context');
      return;
    }

    // Apply cooldown to prevent rapid restarts
    final now = DateTime.now();
    if (_lastRestartTime != null &&
        now.difference(_lastRestartTime!) < _restartCooldown) {
      print('[VoiceCommand] Restart cooldown active, waiting...');
      Future.delayed(_restartCooldown, () {
        if (_isListening && !_isRestarting) {
          _handleRecognitionDone();
        }
      });
      return;
    }

    print('[VoiceCommand] Restarting recognition...');
    _lastRestartTime = now;
    
    if (_onStatusCallback != null) {
      _onStatusCallback!('Restarting...');
    }
    
    // Restart after a brief delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_isListening && !_isRestarting) {
        _restartListening();
      }
    });
  }

  /// Request microphone permission using browser's native API
  Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) {
      return await web_utils.requestMicrophonePermissionWeb();
    }
    // For non-web platforms, permission is handled by the platform
    return true;
  }

  /// Check microphone permission status
  Future<bool> checkPermission() async {
    if (!_isInitialized) {
      await initialize();
    }
    try {
      return await _speech.hasPermission;
    } catch (e) {
      // On web, hasPermission might throw - assume we need to request
      return false;
    }
  }

  /// Start listening for voice commands
  /// 
  /// Parameters:
  /// - onResult: Called when a recognized command is processed
  /// - onError: Called when an error occurs
  /// - context: BuildContext for navigation
  /// - onPartialResult: Optional - called with real-time recognized text
  /// - onStatus: Optional - called with status updates (listening, restarting, etc.)
  Future<void> startListening({
    required Function(String command) onResult,
    required Function(String error) onError,
    required BuildContext context,
    Function(String)? onPartialResult,
    Function(String)? onStatus,
  }) async {
    // Initialize if needed
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError('Speech recognition not available. Please check microphone permissions.');
        return;
      }
    }

    // Stop any existing listening session
    if (_isListening) {
      await stopListening();
    }

    try {
      _isListening = true;
      
      // Store callbacks and context for auto-restart
      _onResultCallback = onResult;
      _onErrorCallback = onError;
      _onPartialResultCallback = onPartialResult;
      _onStatusCallback = onStatus;
      _context = context;
      
      print('[VoiceCommand] Starting speech recognition...');
      
      if (_onStatusCallback != null) {
        _onStatusCallback!('Starting...');
      }
      
      // Start listening with optimal settings
      await _speech.listen(
        onResult: (result) {
          _handleSpeechResult(result);
        },
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false, // Don't stop on errors
          partialResults: true, // Get real-time results
          listenMode: stt.ListenMode.confirmation, // Better accuracy
        ),
        listenFor: const Duration(seconds: 30), // Max listening duration
        pauseFor: const Duration(seconds: 5), // Wait 5s of silence before stopping
        localeId: 'en_US', // English recognition
      );
      
      print('[VoiceCommand] Speech recognition started');
      
    } catch (e, stackTrace) {
      _isListening = false;
      print('[VoiceCommand] Error starting recognition: $e');
      print('[VoiceCommand] Stack trace: $stackTrace');
      
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('permission') || 
          errorMsg.contains('not allowed') || 
          errorMsg.contains('denied')) {
        onError('Microphone permission denied. Please allow microphone access.');
      } else {
        onError('Failed to start listening: $e');
      }
    }
  }

  /// Handle speech recognition results
  void _handleSpeechResult(dynamic result) {
    final command = result.recognizedWords.toLowerCase().trim();
    
    print('[VoiceCommand] Recognized: "$command" (final: ${result.finalResult}, confidence: ${result.confidence})');
    
    if (command.isEmpty) {
      return;
    }
    
    // Always show partial results in real-time
    if (_onPartialResultCallback != null) {
      _onPartialResultCallback!(command);
    }
    
    // Process the command
    final action = processCommand(command);
    
    if (action != null) {
      // Command matched - process if it's final or has good confidence
      if (result.finalResult || result.confidence > 0.5) {
        if (_shouldProcessCommand(action)) {
          print('[VoiceCommand] Processing command: $action');
          if (_onResultCallback != null) {
            _onResultCallback!(command);
          }
        } else {
          print('[VoiceCommand] Command debounced (ignoring duplicate)');
        }
      } else {
        print('[VoiceCommand] Partial result - waiting for final...');
      }
    } else {
      print('[VoiceCommand] Command did not match any keywords');
    }
  }

  /// Internal method to restart listening after a session ends
  Future<void> _restartListening() async {
    if (!_isListening || 
        !_isInitialized || 
        _onResultCallback == null || 
        _isRestarting) {
      return;
    }
    
    _isRestarting = true;
    
    try {
      print('[VoiceCommand] Restarting recognition...');
      
      if (_onStatusCallback != null) {
        _onStatusCallback!('Reconnecting...');
      }
      
      await _speech.listen(
        onResult: (result) {
          _handleSpeechResult(result);
        },
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
        ),
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        localeId: 'en_US',
      );
      
      print('[VoiceCommand] Recognition restarted successfully');
      
      if (_onStatusCallback != null) {
        _onStatusCallback!('Listening...');
      }
      
    } catch (e) {
      print('[VoiceCommand] Error restarting: $e');
      
      if (_onStatusCallback != null) {
        _onStatusCallback!('Error. Retrying...');
      }
      
      // Retry after delay
      if (_isListening) {
        Future.delayed(const Duration(seconds: 2), () {
          if (_isListening && !_isRestarting) {
            _isRestarting = false;
            _restartListening();
          }
        });
      }
    } finally {
      // Reset restart flag after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _isRestarting = false;
      });
    }
  }

  /// Stop listening for voice commands
  Future<void> stopListening() async {
    if (_isListening) {
      print('[VoiceCommand] Stopping speech recognition...');
      
      await _speech.stop();
      _isListening = false;
      
      // Clear callbacks
      _onResultCallback = null;
      _onErrorCallback = null;
      _onPartialResultCallback = null;
      _onStatusCallback = null;
      _context = null;
      _isRestarting = false;
      
      print('[VoiceCommand] Speech recognition stopped');
    }
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Process voice command using keyword matching
  /// Returns the action string if a command is recognized, null otherwise
  String? processCommand(String command) {
    final lowerCommand = command.toLowerCase().trim();
    
    print('[VoiceCommand] Processing command: "$lowerCommand"');
    
    // Special handling for text reading - check if both "read" and "text" are present
    final hasRead = lowerCommand.contains('read');
    final hasText = lowerCommand.contains('text');
    if (hasRead && hasText) {
      print('[VoiceCommand] Matched: text_reading (found both "read" and "text")');
      return 'text_reading';
    }
    
    // Check for single words "read" or "text" alone - they should open text reading
    if (lowerCommand == 'read' || lowerCommand == 'text') {
      print('[VoiceCommand] Matched: text_reading (single word: "$lowerCommand")');
      return 'text_reading';
    }
    
    // Loop through all command keywords
    for (final entry in _commandKeywords.entries) {
      final action = entry.key;
      final keywords = entry.value;
      
      // Check if any keyword matches the command
      for (final keyword in keywords) {
        if (lowerCommand.contains(keyword)) {
          print('[VoiceCommand] Matched: $action (keyword: "$keyword")');
          return action;
        }
      }
    }
    
    // Special handling for context-dependent commands
    if (lowerCommand.contains('language')) {
      for (final keyword in _commandKeywords['language_urdu']!) {
        if (lowerCommand.contains(keyword)) {
          return 'language_urdu';
        }
      }
      for (final keyword in _commandKeywords['language_english']!) {
        if (lowerCommand.contains(keyword)) {
          return 'language_english';
        }
      }
    }
    
    if (lowerCommand.contains('speed') || lowerCommand.contains('voice')) {
      for (final keyword in _commandKeywords['speed_fast']!) {
        if (lowerCommand.contains(keyword)) {
          return 'speed_fast';
        }
      }
      for (final keyword in _commandKeywords['speed_slow']!) {
        if (lowerCommand.contains(keyword)) {
          return 'speed_slow';
        }
      }
      for (final keyword in _commandKeywords['speed_normal']!) {
        if (lowerCommand.contains(keyword)) {
          return 'speed_normal';
        }
      }
    }
    
    print('[VoiceCommand] No match found');
    return null;
  }

  /// Check if command should be processed (debounce check)
  bool _shouldProcessCommand(String action) {
    final now = DateTime.now();
    
    // Prevent processing the same command within debounce duration
    if (_lastCommand == action && 
        _lastCommandTime != null && 
        now.difference(_lastCommandTime!) < _debounceDuration) {
      print('[VoiceCommand] Command debounced: "$action"');
      return false;
    }
    
    // Update last command and timestamp
    _lastCommand = action;
    _lastCommandTime = now;
    return true;
  }

  /// Handle voice command - execute the appropriate action
  Future<void> handleVoiceCommand({
    required String command,
    required BuildContext context,
    required AppSettings appSettings,
    VoidCallback? onStopListening, // Callback to stop listening (for voice_command_off)
  }) async {
    final action = processCommand(command);
    
    if (action == null) {
      // Command not recognized
      final vg = VoiceGuideService();
      await vg.setLanguage(appSettings.languageCode);
      await vg.setRate(appSettings.speechRate);
      await vg.speak('Command not recognized. Please try again.');
      return;
    }

    final vg = VoiceGuideService();
    await vg.setLanguage(appSettings.languageCode);
    await vg.setRate(appSettings.speechRate);

    // Execute the appropriate action
    switch (action) {
      case 'object_detection':
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ObjectDetectionScreen(),
            ),
          );
        }
        break;
        
      case 'text_reading':
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TextReaderScreen(),
            ),
          );
        }
        break;
        
      case 'home':
        final isOnHomeScreen = Navigator.canPop(context) == false;
        if (isOnHomeScreen) {
          await vg.speak('Home screen. Choose a feature: Object Detection or Text Reading.');
        } else {
          if (context.mounted) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        }
        break;
        
      case 'settings':
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SettingsScreen(),
            ),
          );
        }
        break;
        
      case 'language_urdu':
        appSettings.setLanguage('ur-PK');
        await vg.setLanguage('ur-PK');
        await vg.speak('Language changed to Urdu.');
        break;
        
      case 'language_english':
        appSettings.setLanguage('en-US');
        await vg.setLanguage('en-US');
        await vg.speak('Language changed to English.');
        break;
        
      case 'speed_fast':
        appSettings.setSpeechRate(0.8);
        await vg.setRate(0.8);
        await vg.speak('Voice speed changed to fast.');
        break;
        
      case 'speed_slow':
        appSettings.setSpeechRate(0.3);
        await vg.setRate(0.3);
        await vg.speak('Voice speed changed to slow.');
        break;
        
      case 'speed_normal':
        appSettings.setSpeechRate(0.5);
        await vg.setRate(0.5);
        await vg.speak('Voice speed changed to normal.');
        break;
        
      case 'dark_mode_on':
        appSettings.setDarkMode(true);
        await vg.speak('Dark mode enabled.');
        break;
        
      case 'dark_mode_off':
        appSettings.setDarkMode(false);
        await vg.speak('Dark mode disabled.');
        break;
        
      case 'vibration_on':
        appSettings.setVibration(true);
        await vg.speak('Vibration enabled.');
        break;
        
      case 'vibration_off':
        appSettings.setVibration(false);
        await vg.speak('Vibration disabled.');
        break;
        
      case 'voice_command_off':
        // Stop listening for voice commands
        await stopListening();
        await vg.speak('Voice commands turned off.');
        // Call the callback to update UI if provided
        if (onStopListening != null) {
          onStopListening();
        }
        break;
        
      case 'voice_guide_on':
        appSettings.toggleVoiceGuide(true);
        await vg.speak('Voice guide enabled.');
        break;
        
      case 'voice_guide_off':
        // Announce before disabling (so user can hear it)
        await vg.speak('Voice guide disabled.');
        appSettings.toggleVoiceGuide(false);
        break;
    }
  }

  /// Cleanup resources
  void dispose() {
    _speech.stop();
    _isListening = false;
    _isInitialized = false;
    _onResultCallback = null;
    _onErrorCallback = null;
    _onPartialResultCallback = null;
    _onStatusCallback = null;
    _context = null;
  }
}
