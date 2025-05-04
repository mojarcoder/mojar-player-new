import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to protect assets from unauthorized modifications
class AssetProtectionService {
  static const String _assetHashesKey = 'assetHashes';
  static bool _assetsVerified = false;
  static bool _tamperedAssetsFound = false;
  static List<String> _tamperedAssets = [];
  static Timer? _periodicVerificationTimer;
  static final List<Function(List<String>)> _tamperingCallbacks = [];

  // List of assets to protect
  static final List<String> _protectedAssets = [
    'assets/images/profile.jpg',
    'assets/images/mojar_icon.png',
    // Add more assets here as needed
  ];

  /// Initialize the service and perform first-time hash generation if needed
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final hasStoredHashes = prefs.containsKey(_assetHashesKey);

    if (!hasStoredHashes) {
      await _generateAndStoreHashes();
    }
  }

  /// Generate and store hashes for protected assets
  static Future<void> _generateAndStoreHashes() async {
    final Map<String, String> assetHashes = {};

    for (final asset in _protectedAssets) {
      try {
        final ByteData data = await rootBundle.load(asset);
        final List<int> bytes = data.buffer.asUint8List();
        final String hash = _calculateHash(bytes);
        assetHashes[asset] = hash;
      } catch (e) {
        print('Error generating hash for $asset: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_assetHashesKey, jsonEncode(assetHashes));
  }

  /// Calculate SHA-256 hash for byte data
  static String _calculateHash(List<int> bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify all protected assets against stored hashes
  static Future<bool> verifyAssets() async {
    if (_assetsVerified &&
        (_periodicVerificationTimer == null ||
            !_periodicVerificationTimer!.isActive)) {
      return !_tamperedAssetsFound;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedHashesJson = prefs.getString(_assetHashesKey);

    if (storedHashesJson == null) {
      await _generateAndStoreHashes();
      _assetsVerified = true;
      return true;
    }

    final Map<String, dynamic> storedHashes = jsonDecode(storedHashesJson);
    final previouslyTampered = _tamperedAssets.isNotEmpty;
    _tamperedAssets = [];

    for (final asset in _protectedAssets) {
      try {
        final ByteData data = await rootBundle.load(asset);
        final List<int> bytes = data.buffer.asUint8List();
        final String currentHash = _calculateHash(bytes);

        if (storedHashes[asset] != currentHash) {
          _tamperedAssets.add(asset);
        }
      } catch (e) {
        // Asset not found or can't be loaded - consider it tampered
        _tamperedAssets.add(asset);
      }
    }

    _tamperedAssetsFound = _tamperedAssets.isNotEmpty;
    _assetsVerified = true;

    // Notify callbacks if assets were fine but now are tampered
    if (!previouslyTampered && _tamperedAssetsFound) {
      _notifyTamperingCallbacks();
    }

    return !_tamperedAssetsFound;
  }

  /// Get list of tampered assets
  static List<String> getTamperedAssets() {
    return _tamperedAssets;
  }

  /// Reset stored hashes (for development purposes)
  static Future<void> resetStoredHashes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_assetHashesKey);
    _assetsVerified = false;
    _tamperedAssetsFound = false;
    _tamperedAssets = [];
  }

  /// Start periodic verification of assets
  static void startPeriodicVerification({
    Duration interval = const Duration(minutes: 2),
  }) {
    stopPeriodicVerification();
    _periodicVerificationTimer = Timer.periodic(interval, (_) async {
      await verifyAssets();
    });
  }

  /// Stop periodic verification of assets
  static void stopPeriodicVerification() {
    _periodicVerificationTimer?.cancel();
    _periodicVerificationTimer = null;
  }

  /// Register a callback to be notified when tampering is detected
  static void registerTamperingCallback(Function(List<String>) callback) {
    _tamperingCallbacks.add(callback);
  }

  /// Unregister a tampering callback
  static void unregisterTamperingCallback(Function(List<String>) callback) {
    _tamperingCallbacks.remove(callback);
  }

  /// Notify all registered callbacks about tampering
  static void _notifyTamperingCallbacks() {
    for (final callback in _tamperingCallbacks) {
      callback(_tamperedAssets);
    }
  }
}
