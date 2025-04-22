import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'platform_service.dart';

class FolderBrowserService {
  static final FolderBrowserService _instance =
      FolderBrowserService._internal();

  factory FolderBrowserService() {
    return _instance;
  }

  FolderBrowserService._internal();

  // Media file extensions to filter
  final List<String> mediaExtensions = [
    '.mp4',
    '.mkv',
    '.webm',
    '.mov',
    '.avi',
    '.3gp',
    '.flv',
    '.wmv',
    '.mp3',
    '.wav',
    '.ogg',
    '.aac',
    '.flac',
    '.m4a',
    '.wma',
  ];

  // Check and request permissions based on platform
  Future<bool> checkPermissions() async {
    bool hasPermission = false;

    if (Platform.isAndroid) {
      try {
        // Check Android version using our platform service
        final isAndroid13Plus = await PlatformService.isAndroid13OrHigher();

        if (isAndroid13Plus) {
          // Android 13+: Need Photos, Videos, and Audio permissions
          final videoStatus = await Permission.videos.status;
          final audioStatus = await Permission.audio.status;
          final photosStatus = await Permission.photos.status;

          if (videoStatus.isDenied ||
              audioStatus.isDenied ||
              photosStatus.isDenied) {
            await Permission.videos.request();
            await Permission.audio.request();
            await Permission.photos.request();
          }

          hasPermission =
              await Permission.videos.isGranted &&
              await Permission.audio.isGranted &&
              await Permission.photos.isGranted;
        } else {
          // Below Android 13: Need Storage permission
          final storageStatus = await Permission.storage.status;

          if (storageStatus.isDenied) {
            await Permission.storage.request();
            // For all files access on Android 11+
            if ((await DeviceInfoPlugin().androidInfo).version.sdkInt >= 30) {
              await Permission.manageExternalStorage.request();
            }
          }

          hasPermission = await Permission.storage.isGranted;
        }
      } catch (e) {
        debugPrint('Error checking permissions: $e');
      }
    } else if (Platform.isIOS) {
      // iOS has permission handling through the file picker
      hasPermission = true;
    } else {
      // Desktop platforms don't need runtime permissions
      hasPermission = true;
    }

    return hasPermission;
  }

  // Get common directories for Android
  Future<List<Directory>> getCommonDirectoriesForAndroid() async {
    List<Directory> dirs = [];

    try {
      // Get external storage directory
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        // Go up to the root of Android storage
        Directory? current = directory;
        while (current != null && !current.path.endsWith('/Android')) {
          if (current.path.endsWith('/0') ||
              current.path.endsWith('/storage')) {
            break;
          }
          current = current.parent;
        }

        if (current != null && current.existsSync()) {
          dirs.add(current);
        }
      }

      // Add common media directories
      final List<String> commonPaths = [
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Videos',
        '/storage/emulated/0/WhatsApp/Media',
      ];

      for (var path in commonPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          dirs.add(dir);
        }
      }
    } catch (e) {
      debugPrint('Error getting Android directories: $e');
    }

    return dirs;
  }

  // Get common directories for macOS
  Future<List<Directory>> getCommonDirectoriesForMacOS() async {
    List<Directory> dirs = [];

    try {
      // Home directory
      final home = await getApplicationDocumentsDirectory();
      final homeDir = Directory(home.path.split('/Documents')[0]);
      if (await homeDir.exists()) {
        dirs.add(homeDir);
      }

      // Common macOS directories
      final List<String> commonPaths = [
        '${homeDir.path}/Desktop',
        '${homeDir.path}/Documents',
        '${homeDir.path}/Downloads',
        '${homeDir.path}/Movies',
        '${homeDir.path}/Music',
        '${homeDir.path}/Pictures',
      ];

      for (var path in commonPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          dirs.add(dir);
        }
      }
    } catch (e) {
      debugPrint('Error getting macOS directories: $e');
    }

    return dirs;
  }

  // Get common directories for Windows
  Future<List<Directory>> getCommonDirectoriesForWindows() async {
    List<Directory> dirs = [];

    try {
      // Home/User directory
      final docs = await getApplicationDocumentsDirectory();
      final userDir = Directory(docs.path.split('\\Documents')[0]);
      if (await userDir.exists()) {
        dirs.add(userDir);
      }

      // Common Windows directories
      final List<String> commonPaths = [
        '${userDir.path}\\Desktop',
        '${userDir.path}\\Documents',
        '${userDir.path}\\Downloads',
        '${userDir.path}\\Music',
        '${userDir.path}\\Pictures',
        '${userDir.path}\\Videos',
      ];

      // Windows drives
      if (Platform.isWindows) {
        final driveLetters = ['C:', 'D:', 'E:', 'F:', 'G:'];
        for (var letter in driveLetters) {
          final drive = Directory('$letter\\');
          if (await drive.exists()) {
            dirs.add(drive);
          }
        }
      }

      for (var path in commonPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          dirs.add(dir);
        }
      }
    } catch (e) {
      debugPrint('Error getting Windows directories: $e');
    }

    return dirs;
  }

  // Get platform-specific common directories
  Future<List<Directory>> getCommonDirectories() async {
    if (Platform.isAndroid) {
      return getCommonDirectoriesForAndroid();
    } else if (Platform.isMacOS) {
      return getCommonDirectoriesForMacOS();
    } else if (Platform.isWindows) {
      return getCommonDirectoriesForWindows();
    } else {
      // For other platforms, return an empty list
      return [];
    }
  }

  // Browse directory and return files/folders
  Future<List<FileSystemEntity>> browseDirectory(String path) async {
    final directory = Directory(path);
    final List<FileSystemEntity> files = [];

    try {
      await for (var entity in directory.list(followLinks: false)) {
        // Only add directories and media files
        if (entity is Directory) {
          files.add(entity);
        } else if (entity is File) {
          final extension = entity.path.toLowerCase().split('.').last;
          if (mediaExtensions.any((ext) => ext.endsWith(extension))) {
            files.add(entity);
          }
        }
      }

      // Sort: directories first, then files
      files.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });
    } catch (e) {
      debugPrint('Error browsing directory: $e');
    }

    return files;
  }

  // Use file_picker to select a folder
  Future<String?> pickFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select a folder',
      );

      return selectedDirectory;
    } catch (e) {
      debugPrint('Error picking folder: $e');
      return null;
    }
  }

  // Use file_picker to select multiple media files
  Future<List<String>> pickMediaFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions:
            mediaExtensions.map((e) => e.replaceFirst('.', '')).toList(),
        allowMultiple: true,
      );

      if (result != null) {
        return result.paths
            .where((path) => path != null)
            .map((path) => path!)
            .toList();
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }

    return [];
  }

  // Get file details like name, size
  String getFileName(String path) {
    return path.split(Platform.isWindows ? '\\' : '/').last;
  }

  String getDirectoryName(String path) {
    final separator = Platform.isWindows ? '\\' : '/';
    final parts = path.split(separator);
    final name = parts.last.isEmpty ? parts[parts.length - 2] : parts.last;

    // Make common path names more readable
    if (name == '0') return 'Internal Storage';
    if (name == 'emulated') return 'Internal Storage';
    if (name == 'self') return 'Internal Storage';
    if (name == 'Download') return 'Downloads';

    // Handle Windows drive letter
    if (Platform.isWindows && path.endsWith(':\\')) {
      return '$name Drive';
    }

    return name;
  }

  String getFileSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      return 'Unknown size';
    }
  }

  // Check if a path is a media file
  bool isMediaFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return mediaExtensions.any((ext) => ext.endsWith(extension));
  }
}
