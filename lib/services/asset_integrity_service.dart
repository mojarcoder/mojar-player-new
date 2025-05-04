import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssetIntegrityService {
  static const String _hashesKey = 'asset_integrity_hashes';
  static Timer? _periodicCheckTimer;
  static bool _periodicCheckRunning = false;

  // List of protected asset paths (relative to assets folder)
  static final List<String> _protectedAssets = [
    'images/profile.jpg',
    'images/mojar_icon.png',
    // Add more protected assets as needed
  ];

  // Initialize the service and generate hash values for assets
  static Future<bool> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHashes = prefs.getString(_hashesKey);

      if (storedHashes == null) {
        // First run, generate and store hashes
        final assetHashes = await _generateAssetHashes();
        await prefs.setString(_hashesKey, jsonEncode(assetHashes));
        debugPrint('Asset integrity hashes initialized');
        return true;
      }

      return true;
    } catch (e) {
      debugPrint('Error initializing asset integrity service: $e');
      return false;
    }
  }

  // Verify the integrity of all protected assets
  static Future<Map<String, bool>> verifyAssets() async {
    final results = <String, bool>{};
    final prefs = await SharedPreferences.getInstance();
    final storedHashesJson = prefs.getString(_hashesKey);

    if (storedHashesJson == null) {
      // If no stored hashes, initialize first
      await initialize();
      return _protectedAssets.asMap().map((_, asset) => MapEntry(asset, true));
    }

    final Map<String, dynamic> storedHashes = jsonDecode(storedHashesJson);

    // Check each protected asset
    for (final assetPath in _protectedAssets) {
      try {
        final currentHash = await _computeAssetHash(assetPath);
        final originalHash = storedHashes[assetPath];

        if (originalHash == null) {
          // Asset not in original list - treat as modified
          results[assetPath] = false;
        } else {
          // Compare hashes
          results[assetPath] = (currentHash == originalHash);
        }
      } catch (e) {
        // Asset couldn't be loaded - treat as missing
        debugPrint('Error verifying asset $assetPath: $e');
        results[assetPath] = false;
      }
    }

    return results;
  }

  // Reset stored hashes with current assets (use with caution)
  static Future<bool> resetHashes() async {
    try {
      final assetHashes = await _generateAssetHashes();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_hashesKey, jsonEncode(assetHashes));
      return true;
    } catch (e) {
      debugPrint('Error resetting asset hashes: $e');
      return false;
    }
  }

  // Generate hashes for all protected assets
  static Future<Map<String, String>> _generateAssetHashes() async {
    final Map<String, String> hashes = {};

    for (final assetPath in _protectedAssets) {
      try {
        final hash = await _computeAssetHash(assetPath);
        hashes[assetPath] = hash;
      } catch (e) {
        debugPrint('Error computing hash for $assetPath: $e');
      }
    }

    return hashes;
  }

  // Compute hash for a single asset
  static Future<String> _computeAssetHash(String assetPath) async {
    final ByteData data = await rootBundle.load('assets/$assetPath');
    final Uint8List bytes = data.buffer.asUint8List();
    final Digest digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Check if assets are modified and show warning
  static Future<bool> ensureAssetIntegrity() async {
    final verificationResults = await verifyAssets();

    // Check if any asset is modified or missing
    final anyModified = verificationResults.values.any((isValid) => !isValid);

    if (anyModified) {
      // Return false to indicate modified assets
      return false;
    }

    return true;
  }

  // Start periodic integrity checks (e.g., every 5 minutes)
  static void startPeriodicChecks({
    required Duration checkInterval,
    required Function(List<String>) onModifiedAssetsDetected,
  }) {
    if (_periodicCheckRunning) {
      return; // Already running
    }

    _periodicCheckRunning = true;
    _periodicCheckTimer = Timer.periodic(
      checkInterval,
      (_) async {
        try {
          final verificationResults = await verifyAssets();

          // Get list of modified assets
          final modifiedAssets = verificationResults.entries
              .where((entry) => !entry.value)
              .map((entry) => entry.key)
              .toList();

          if (modifiedAssets.isNotEmpty) {
            // Call the callback with the list of modified assets
            onModifiedAssetsDetected(modifiedAssets);

            // Stop periodic checks after reporting a violation
            stopPeriodicChecks();
          }
        } catch (e) {
          debugPrint('Error during periodic asset integrity check: $e');
        }
      },
    );
  }

  // Stop periodic integrity checks
  static void stopPeriodicChecks() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
    _periodicCheckRunning = false;
  }
}
