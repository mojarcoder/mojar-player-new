import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
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
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        return result == PermissionStatus.granted;
      }
      return true;
    }
    return true;
  }

  // Get common directories for Android
  Future<List<Directory>> getCommonDirectoriesForAndroid() async {
    List<Directory> dirs = [];

    try {
      // Add Internal Storage root
      final Directory internalStorage = Directory('/storage/emulated/0');
      if (await internalStorage.exists()) {
        dirs.add(internalStorage);
      }

      // Add External SD Card storage if available
      try {
        final List<Directory>? externalDirs =
            await getExternalStorageDirectories();
        if (externalDirs != null && externalDirs.isNotEmpty) {
          for (var dir in externalDirs) {
            // Navigate up to find the root of each storage
            String path = dir.path;
            final int androidIndex = path.indexOf('/Android');
            if (androidIndex != -1) {
              // Get the parent directory of Android folder
              final String storageRoot = path.substring(0, androidIndex);
              final Directory storageDir = Directory(storageRoot);

              // Don't add if it's the same as internal storage
              if (storageDir.path != internalStorage.path &&
                  await storageDir.exists()) {
                dirs.add(storageDir);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error accessing external storage: $e');
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

  // Get common directories for iOS
  Future<List<Directory>> getCommonDirectoriesForIOS() async {
    List<Directory> dirs = [];

    try {
      // Get documents directory
      final docDir = await getApplicationDocumentsDirectory();
      if (await docDir.exists()) {
        dirs.add(docDir);
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        dirs.add(tempDir);
      }

      // Get library directory
      final libraryDir = await getLibraryDirectory();
      if (await libraryDir.exists()) {
        dirs.add(libraryDir);
      }

      // Get application support directory
      final supportDir = await getApplicationSupportDirectory();
      if (await supportDir.exists() && supportDir.path != libraryDir.path) {
        dirs.add(supportDir);
      }

      // Get other common iOS directories
      try {
        final downloadsDir = Directory('${docDir.path}/../Downloads');
        if (await downloadsDir.exists()) {
          dirs.add(downloadsDir);
        }

        final moviesDir = Directory('${docDir.path}/../Movies');
        if (await moviesDir.exists()) {
          dirs.add(moviesDir);
        }

        final musicDir = Directory('${docDir.path}/../Music');
        if (await musicDir.exists()) {
          dirs.add(musicDir);
        }

        final picturesDir = Directory('${docDir.path}/../Pictures');
        if (await picturesDir.exists()) {
          dirs.add(picturesDir);
        }
      } catch (e) {
        debugPrint('Error accessing iOS media directories: $e');
      }
    } catch (e) {
      debugPrint('Error getting iOS directories: $e');
    }

    return dirs;
  }

  // Get platform-specific common directories
  Future<List<Directory>> getCommonDirectories() async {
    List<Directory> dirs = [];

    if (Platform.isAndroid) {
      dirs = await getCommonDirectoriesForAndroid();
    } else if (Platform.isMacOS) {
      dirs = await getCommonDirectoriesForMacOS();
    } else if (Platform.isWindows) {
      dirs = await getCommonDirectoriesForWindows();
    } else if (Platform.isIOS) {
      dirs = await getCommonDirectoriesForIOS();
    } else if (Platform.isLinux) {
      dirs = await getCommonDirectoriesForLinux();
    }

    // If no directories were found or on an unsupported platform,
    // at least return the application documents directory
    if (dirs.isEmpty) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        if (await docDir.exists()) {
          dirs.add(docDir);
        }
      } catch (e) {
        debugPrint('Error getting fallback directory: $e');
      }
    }

    return dirs;
  }

  // Get common directories for Linux
  Future<List<Directory>> getCommonDirectoriesForLinux() async {
    List<Directory> dirs = [];

    try {
      // Get home directory
      final docs = await getApplicationDocumentsDirectory();
      final homeDir = Directory(docs.path.split('/Documents')[0]);
      if (await homeDir.exists()) {
        dirs.add(homeDir);
      }

      // Common Linux directories
      final List<String> commonPaths = [
        '${homeDir.path}/Desktop',
        '${homeDir.path}/Documents',
        '${homeDir.path}/Downloads',
        '${homeDir.path}/Music',
        '${homeDir.path}/Pictures',
        '${homeDir.path}/Videos',
        '/media/${homeDir.path.split('/').last}', // External media mounted for user
      ];

      for (var path in commonPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          dirs.add(dir);
        }
      }

      // Common system media locations
      final List<String> systemPaths = ['/media', '/mnt'];

      for (var path in systemPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          try {
            // Add mounted media devices
            final entities = await dir.list().toList();
            for (var entity in entities) {
              if (entity is Directory) {
                dirs.add(entity);
              }
            }
          } catch (e) {
            debugPrint('Error listing system directory $path: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting Linux directories: $e');
    }

    return dirs;
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

  // Use file_selector to select a folder
  Future<String?> getDirectoryPath() async {
    try {
      final String? selectedDirectory = await getDirectoryPath();
      return selectedDirectory;
    } catch (e) {
      print('Error picking directory: $e');
      return null;
    }
  }

  // Use file_selector to select multiple media files
  Future<List<String>> pickMediaFiles() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Media Files',
        extensions: ['mp4', 'mkv', 'avi', 'mp3', 'wav', 'flac'],
      );
      final List<XFile> files = await openFiles(acceptedTypeGroups: [typeGroup]);
      return files.map((file) => file.path).toList();
    } catch (e) {
      print('Error picking files: $e');
      return [];
    }
  }

  // Get file details like name, size
  String getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  String getDirectoryName(String path) {
    final separator = Platform.isWindows ? '\\' : '/';
    final parts = path.split(separator);
    final name = parts.last.isEmpty ? parts[parts.length - 2] : parts.last;

    // Make common path names more readable
    if (Platform.isAndroid) {
      if (path == '/storage/emulated/0') return 'Internal Storage';
      if (name == '0' && path.contains('emulated')) return 'Internal Storage';
      if (name == 'emulated') return 'Internal Storage';
      if (name == 'self') return 'Internal Storage';

      // External SD card
      if (path.startsWith('/storage/') &&
          !path.startsWith('/storage/emulated/') &&
          !path.startsWith('/storage/self/')) {
        if (parts.length >= 3) {
          return 'SD Card ($name)';
        }
        return 'SD Card';
      }
    }

    if (Platform.isIOS) {
      if (path.endsWith('/Documents')) return 'Documents';
      if (path.endsWith('/tmp')) return 'Temporary';
      if (path.contains('/Library/')) return 'Library';
    }

    // Common names across platforms
    if (name == 'Download' || name == 'Downloads') return 'Downloads';
    if (name == 'Music') return 'Music';
    if (name == 'Movies') return 'Movies';
    if (name == 'Pictures') return 'Pictures';
    if (name == 'Videos') return 'Videos';
    if (name == 'DCIM') return 'Camera';
    if (name == 'WhatsApp') return 'WhatsApp';
    if (name == 'Media' && path.contains('WhatsApp')) return 'WhatsApp Media';

    // Handle Windows drive letter
    if (Platform.isWindows && path.endsWith(':\\')) {
      return '$name Drive';
    }

    // Handle Linux mounted devices
    if (Platform.isLinux &&
        (path.startsWith('/media/') || path.startsWith('/mnt/'))) {
      return '$name (External)';
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
    final extension = getFileExtension(path);
    if (extension == null) return false;
    
    return mediaExtensions.contains(extension.toLowerCase());
  }

  String? getFileExtension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : null;
  }
}
