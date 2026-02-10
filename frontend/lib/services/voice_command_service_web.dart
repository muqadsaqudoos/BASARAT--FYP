/* 

// Web-specific implementation for microphone permission
import 'dart:html' as html;

/// Request microphone permission using browser's native API
/// This will definitely trigger the browser permission prompt
/// MUST be called from a user gesture (button click) for browser to show prompt
Future<bool> requestMicrophonePermissionWeb() async {
  try {
    // Check if getUserMedia is available
    if (html.window.navigator.mediaDevices == null) {
      return false;
    }
    
    // Use browser's native getUserMedia API to request microphone permission
    // This will show the browser permission prompt
    // IMPORTANT: This must be called directly from a user gesture
    final stream = await html.window.navigator.mediaDevices!.getUserMedia({
      'audio': true,
    });
    
    // Stop the stream immediately - we just needed it to trigger permission
    stream.getTracks().forEach((track) {
      track.stop();
    });
    
    return true;
  } catch (e) {
    // Permission denied or error
    // Don't log here - let the caller handle it
    return false;
  }
}

*/
