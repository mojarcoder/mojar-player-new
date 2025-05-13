import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// A service to handle platform-specific functionality
class PlatformService {
  static const MethodChannel _channel = MethodChannel(
    'com.mojarplayer.mojar_player_pro/system',
  );
  static bool _initialized = false;

  /// Initialize the platform service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set up a method channel handler for testing the connection
      _channel.setMethodCallHandler((call) async {
        debugPrint('Received method call from platform: ${call.method}');
        if (call.method == 'ping') {
          return 'pong';
        }
        return null;
      });

      // Test the channel connection
      try {
        await _channel.invokeMethod<bool>('ping');
        debugPrint('Platform channel connection successful');
      } catch (e) {
        debugPrint('Platform channel connection test failed: $e');
        // Continue anyway as the platform might not implement ping
      }

      // Initialize platform-specific features
      if (Platform.isAndroid) {
        // Check if any initialization is needed
        debugPrint('Android platform service initialized');
      } else if (Platform.isIOS) {
        // iOS-specific initialization
        debugPrint('iOS platform service initialized');
      } else if (Platform.isWindows) {
        // Windows-specific initialization
        debugPrint('Windows platform service initialized');
      } else if (Platform.isLinux) {
        debugPrint('Linux platform service initialized');
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing platform service: $e');
    }
  }

  /// Keep the screen on (useful during media playback)
  static Future<void> keepScreenOn(bool enable) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('keepScreenOn', {'enable': enable});
      } else if (Platform.isIOS) {
        // iOS implementation would go here
      } else {
        // Default implementation for desktop platforms
        debugPrint(
          'keepScreenOn not implemented for ${Platform.operatingSystem}',
        );
      }
    } catch (e) {
      debugPrint('Error in keepScreenOn: $e');
    }
  }

  /// Check if the app is running on Android 13 or higher
  static Future<bool> isAndroid13OrHigher() async {
    if (Platform.isAndroid) {
      try {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.version.sdkInt >= 33; // Android 13 is API level 33
      } catch (e) {
        debugPrint('Error checking Android version: $e');
      }
    }
    return false;
  }

  static Future<bool> enterFullscreen() async {
    try {
      final result = await _channel.invokeMethod('enterFullscreen');
      return result ?? false;
    } catch (e) {
      debugPrint('Error entering fullscreen: $e');
      return false;
    }
  }

  static Future<bool> exitFullscreen() async {
    try {
      // First check if we're actually in fullscreen
      final isCurrentlyFullscreen = await isFullscreen();
      if (!isCurrentlyFullscreen) {
        debugPrint('Already in windowed mode, no need to exit fullscreen');
        return true;
      }

      debugPrint('Calling native exitFullscreen method');
      final result = await _channel.invokeMethod('exitFullscreen');

      // Add a delay to ensure the window has time to update
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify the state changed
      final newState = await isFullscreen();
      debugPrint('After exitFullscreen: isFullscreen = $newState, expected: false');

      // If still in fullscreen, try one more time
      if (newState) {
        debugPrint('Still in fullscreen after first attempt, trying again');
        await _channel.invokeMethod('exitFullscreen');
        await Future.delayed(const Duration(milliseconds: 200));
      }

      return result ?? false;
    } catch (e) {
      debugPrint('Error exiting fullscreen: $e');
      return false;
    }
  }

  static Future<bool> toggleFullscreen() async {
    try {
      // Make sure the platform service is initialized
      if (!_initialized) {
        await initialize();
      }

      // First check the current fullscreen state
      final currentState = await isFullscreen();
      debugPrint('Current fullscreen state before toggle: $currentState');

      // Instead of using the native toggleFullscreen, explicitly call enter or exit
      // This gives us more control over the process
      bool result;

      if (currentState) {
        // We're in fullscreen mode, so exit fullscreen
        debugPrint('Currently in fullscreen, explicitly calling exitFullscreen');

        // Try up to 3 times to exit fullscreen
        result = false;
        int attempts = 0;

        while (!result && attempts < 3) {
          attempts++;
          debugPrint('Exit fullscreen attempt $attempts');

          // Call the native method
          result = await _channel.invokeMethod('exitFullscreen') ?? false;

          // Add a delay to ensure the window has time to update
          await Future.delayed(const Duration(milliseconds: 300));

          // Check if we're still in fullscreen
          final stillFullscreen = await isFullscreen();
          debugPrint('After exit attempt $attempts: stillFullscreen = $stillFullscreen');

          // If we're still in fullscreen, try again
          if (stillFullscreen) {
            result = false;
          } else {
            result = true;
            break;
          }
        }
      } else {
        // We're in windowed mode, so enter fullscreen
        debugPrint('Currently not in fullscreen, explicitly calling enterFullscreen');
        result = await enterFullscreen();

        // Add a delay to ensure the window has time to update
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Final check to ensure UI state matches actual state
      final finalState = await isFullscreen();
      debugPrint('Final fullscreen state after toggle: $finalState, expected: ${!currentState}');

      return result;
    } catch (e) {
      debugPrint('Error toggling fullscreen: $e');
      return false;
    }
  }

  static Future<bool> isFullscreen() async {
    try {
      // Make sure the platform service is initialized
      if (!_initialized) {
        await initialize();
      }

      debugPrint('Sending isFullscreen to platform');
      final result = await _channel.invokeMethod('isFullscreen');
      debugPrint('Received isFullscreen result: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking fullscreen state: $e');
      return false;
    }
  }
}
