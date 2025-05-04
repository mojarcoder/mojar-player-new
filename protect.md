# Asset Protection Implementation Guide

## Overview

This document explains how the Mojar Player Pro application implements asset integrity protection to prevent unauthorized modification of assets such as PNG, ICO, and JPG files. The system detects if anyone edits, replaces, or removes these files from the assets folder during runtime and shows a warning, preventing the application from being used if tampering is detected.

## Implementation Details

### 1. Asset Integrity Service (`lib/services/asset_integrity_service.dart`)

The core component responsible for asset verification is the `AssetIntegrityService` class which:

- Calculates and stores SHA-256 hashes of protected asset files
- Verifies assets by comparing current hashes with stored values
- Supports both startup and runtime checks for asset modifications

```dart
class AssetIntegrityService {
  // Storage key for asset hashes in SharedPreferences
  static const String _hashesKey = 'asset_integrity_hashes';
  static Timer? _periodicCheckTimer;
  static bool _periodicCheckRunning = false;
  
  // List of protected assets (paths relative to assets folder)
  static final List<String> _protectedAssets = [
    'images/profile.jpg',
    'images/mojar_icon.png',
    // Add more protected assets as needed
  ];
  
  // Initialize the service and generate hash values
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
  
  // Compute hash for a single asset
  static Future<String> _computeAssetHash(String assetPath) async {
    final ByteData data = await rootBundle.load('assets/$assetPath');
    final Uint8List bytes = data.buffer.asUint8List();
    final Digest digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Start periodic integrity checks
  static void startPeriodicChecks({
    required Duration checkInterval, 
    required Function(List<String>) onModifiedAssetsDetected,
  }) {
    // Implementation details in the code file
  }
}
```

### 2. Asset Integrity Warning UI (`lib/widgets/asset_integrity_warning.dart`)

If asset tampering is detected, this UI component shows a non-dismissible warning screen that:
- Displays which files have been modified/tampered with
- Prevents application usage
- Provides an exit button to close the application

```dart
class AssetIntegrityWarning extends StatelessWidget {
  final VoidCallback onExit;
  final List<String> modifiedAssets;

  const AssetIntegrityWarning({
    Key? key,
    required this.onExit,
    required this.modifiedAssets,
  }) : super(key: key);
  
  // Implementation details in the code file
}
```

### 3. Integration in Application Startup Flow (`lib/main.dart`)

The asset integrity verification is integrated into the app's startup flow using an `AssetIntegrityCheck` widget that:
- Runs asset verification checks at app startup
- Shows appropriate UI based on check results
- Prevents app usage if tampering is detected

```dart
class AssetIntegrityCheck extends StatefulWidget {
  final Widget child;

  const AssetIntegrityCheck({super.key, required this.child});

  @override
  State<AssetIntegrityCheck> createState() => _AssetIntegrityCheckState();
}

class _AssetIntegrityCheckState extends State<AssetIntegrityCheck> {
  bool _isChecking = true;
  bool _isValid = true;
  List<String> _modifiedAssets = [];

  @override
  void initState() {
    super.initState();
    _checkAssetIntegrity();
  }
  
  // Implementation details in the code file
}
```

### 4. Runtime Integrity Checks

The application also implements periodic runtime checks to detect asset modifications that may occur while the app is running:

```dart
// In HomeScreen
void _startAssetIntegrityChecks() {
  AssetIntegrityService.startPeriodicChecks(
    checkInterval: const Duration(minutes: 5),
    onModifiedAssetsDetected: (modifiedAssets) {
      // Show the integrity warning when an asset modification is detected
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AssetIntegrityWarning(
              modifiedAssets: modifiedAssets,
              onExit: () {
                debugPrint('Exiting due to runtime asset integrity violation');
              },
            ),
          ),
        );
      }
    },
  );
}
```

## How It Works

1. **First Run Initialization**:
   - On the first app run, SHA-256 hashes are generated for all protected assets
   - Hashes are stored in the device's `SharedPreferences` for future verification

2. **Startup Verification**:
   - When the app starts, it verifies all protected assets by:
     - Loading each asset file
     - Computing its current hash
     - Comparing with the stored hash value
   - If any hash doesn't match, the app shows a warning and prevents usage

3. **Runtime Verification**:
   - Every 5 minutes, the app repeats the verification process
   - If tampering is detected, it immediately shows the warning screen
   - This catches modifications made while the app is running

4. **Asset Protection Coverage**:
   - PNG, ICO, and JPG files in the assets folder are protected
   - The system can be extended to cover other file types by adding them to the `_protectedAssets` list

## Technical Details

### How Asset Hashes Are Generated

The hash generation uses the following approach:
1. Load the asset file using Flutter's `rootBundle.load()`
2. Convert the file data to a byte array
3. Compute a SHA-256 hash of the byte array
4. Store the resulting hash as a string

```dart
static Future<String> _computeAssetHash(String assetPath) async {
  final ByteData data = await rootBundle.load('assets/$assetPath');
  final Uint8List bytes = data.buffer.asUint8List();
  final Digest digest = sha256.convert(bytes);
  return digest.toString();
}
```

### Hash Storage

Asset hashes are stored using Flutter's `SharedPreferences`:
- The key is defined as `asset_integrity_hashes`
- The value is a JSON-encoded map of asset paths to hash values
- This allows the app to detect modifications even after being closed and reopened

### Required Dependencies

The implementation requires the following packages:
- `crypto`: ^3.0.3 (for hash computation)
- `shared_preferences`: ^2.2.2 (for persistent storage of hash values)

## Security Considerations

1. **Tamper Evidence, Not Prevention**:
   - This implementation provides tamper evidence, not tamper prevention
   - It detects when assets have been modified but cannot prevent modifications to the files themselves

2. **SharedPreferences Limitations**:
   - The hash values are stored in SharedPreferences, which is not secure against a determined attacker
   - For higher security, consider using encrypted storage or remote verification

3. **Root/Jailbreak Detection**:
   - This system doesn't detect if a device is rooted/jailbroken
   - Rooted devices might be able to bypass this protection

4. **Asset Bundle Protection**:
   - The protection only works for assets in the Flutter asset bundle
   - Dynamic assets loaded from other locations would need different protection mechanisms

## How to Add More Protected Assets

To add more files to the protected assets list, modify the `_protectedAssets` array in `AssetIntegrityService`:

```dart
static final List<String> _protectedAssets = [
  'images/profile.jpg',
  'images/mojar_icon.png',
  'images/new_image.jpg', // Add new assets here
  'icons/app_icon.ico',    // Add new assets here
  // Add more protected assets as needed
];
```

## Troubleshooting

If the application incorrectly reports asset tampering:

1. **Reset Hashes** (admin use only):
   - You can add a hidden admin feature to call `AssetIntegrityService.resetHashes()`
   - This will update stored hashes to match current assets
   - Use this only when legitimate asset updates are made

2. **Clear App Data**:
   - Users can clear the app data to reset the stored hashes
   - On next run, the app will generate new hashes from current assets

## Conclusion

This asset protection implementation provides a robust way to detect unauthorized modifications to critical assets in your application. It helps ensure the visual and functional integrity of your app by preventing usage when tampering is detected. 