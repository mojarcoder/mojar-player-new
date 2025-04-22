import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// A service to handle platform-specific functionality
class PlatformService {
  static const MethodChannel _channel = MethodChannel(
    'com.mojarplayer.mojar_player_new/system',
  );
  static bool _initialized = false;

  /// Initialize the platform service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
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
}
