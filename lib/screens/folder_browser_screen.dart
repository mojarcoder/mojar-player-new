import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/folder_browser_service.dart';

class FolderBrowserScreen extends StatefulWidget {
  const FolderBrowserScreen({super.key});

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  final FolderBrowserService _folderService = FolderBrowserService();
  List<Directory> _storageList = [];
  List<FileSystemEntity> _currentFiles = [];
  String _currentPath = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initStoragePaths();
  }

  Future<void> _initStoragePaths() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hasPermission = await _folderService.checkPermissions();
      if (!hasPermission) {
        _showPermissionDeniedDialog();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      _storageList = await _folderService.getCommonDirectories();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing storage paths: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Storage Permission Required'),
            content: const Text(
              'Storage access permission is required to browse your media files. '
              'Please grant the permission in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  Future<void> _browseDirectory(Directory directory) async {
    setState(() {
      _isLoading = true;
      _currentPath = directory.path;
    });

    try {
      final files = await _folderService.browseDirectory(directory.path);

      setState(() {
        _currentFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error browsing directory: $e');
      setState(() {
        _currentFiles = [];
        _isLoading = false;
      });

      // Show error message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error browsing directory: $e')));
    }
  }

  void _navigateBack() {
    if (_currentPath.isNotEmpty) {
      final directory = Directory(_currentPath);
      final parent = directory.parent;

      if (_storageList.any((dir) => dir.path == parent.path)) {
        // We're back at the root level, show storage list
        setState(() {
          _currentPath = '';
          _currentFiles = [];
        });
      } else {
        _browseDirectory(parent);
      }
    }
  }

  void _onItemTap(FileSystemEntity entity) {
    if (entity is Directory) {
      _browseDirectory(entity);
    } else if (entity is File) {
      _openMediaFile(entity);
    }
  }

  void _openMediaFile(File file) {
    // Navigate back to home screen and play the file
    Navigator.pop(context, file.path);
  }

  Future<void> _pickFolder() async {
    final selectedDir = await _folderService.getDirectoryPath();
    if (selectedDir != null) {
      _browseDirectory(Directory(selectedDir));
    }
  }

  Future<void> _pickFiles() async {
    final selectedFiles = await _folderService.pickMediaFiles();
    if (selectedFiles.isNotEmpty) {
      // Just return the first file for now
      Navigator.pop(context, selectedFiles.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentPath.isEmpty
              ? 'Browse Folders'
              : _folderService.getDirectoryName(_currentPath),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading:
            _currentPath.isEmpty
                ? null
                : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateBack,
                ),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'Select Folder',
            onPressed: _pickFolder,
          ),
          IconButton(
            icon: const Icon(Icons.file_open),
            tooltip: 'Select Files',
            onPressed: _pickFiles,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentPath.isEmpty
              ? _buildStorageList()
              : _buildFileList(),
    );
  }

  Widget _buildStorageList() {
    if (_storageList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No storage locations found'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Select a Folder'),
              onPressed: _pickFolder,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.file_open),
              label: const Text('Select Files'),
              onPressed: _pickFiles,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _storageList.length,
      itemBuilder: (context, index) {
        final storage = _storageList[index];
        final name = _folderService.getDirectoryName(storage.path);

        return ListTile(
          leading: const Icon(Icons.folder, color: Colors.amber),
          title: Text(name),
          subtitle: Text(storage.path),
          onTap: () => _browseDirectory(storage),
        );
      },
    );
  }

  Widget _buildFileList() {
    if (_currentFiles.isEmpty) {
      return const Center(
        child: Text('No media files found in this directory'),
      );
    }

    return ListView.builder(
      itemCount: _currentFiles.length,
      itemBuilder: (context, index) {
        final entity = _currentFiles[index];
        final name = _folderService.getFileName(entity.path);
        final isDirectory = entity is Directory;

        return ListTile(
          leading: Icon(
            isDirectory ? Icons.folder : _getFileIcon(entity.path),
            color: isDirectory ? Colors.amber : Colors.blue,
          ),
          title: Text(name),
          subtitle:
              !isDirectory
                  ? Text(_folderService.getFileSize(entity as File))
                  : null,
          onTap: () => _onItemTap(entity),
        );
      },
    );
  }

  IconData _getFileIcon(String path) {
    final extension = path.toLowerCase().split('.').last;

    // Video files
    if ([
      'mp4',
      'mkv',
      'webm',
      'mov',
      'avi',
      '3gp',
      'flv',
      'wmv',
    ].contains(extension)) {
      return Icons.movie;
    }

    // Audio files
    if ([
      'mp3',
      'wav',
      'ogg',
      'aac',
      'flac',
      'm4a',
      'wma',
    ].contains(extension)) {
      return Icons.music_note;
    }

    return Icons.insert_drive_file;
  }
}
