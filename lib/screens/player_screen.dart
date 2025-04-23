import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/media_controls.dart';
import '../widgets/context_menu.dart';
import '../widgets/controls/media_controls.dart' as controls;
import '../services/platform_service.dart';
import '../services/folder_browser_service.dart';
import 'about_screen.dart';

// Define colors that match the app theme
const Color primaryPink = Color(0xFFFF4D8D);
const Color lightPink = Color(0xFFFFB6C1);
const Color darkPink = Color(0xFFE91E63);

class PlayerScreen extends StatefulWidget {
  final String filePath;
  final List<String>? playlist;
  final int? initialPlaylistIndex;

  const PlayerScreen({
    super.key,
    required this.filePath,
    this.playlist,
    this.initialPlaylistIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  just_audio.AudioPlayer? _audioPlayer;
  ChewieController? _chewieController;

  bool _isLoading = true;
  bool _showControls = true;
  bool _showPlaylist = false;
  bool _isFullscreen = false;
  bool _isDarkMode = true;
  bool _isPortrait = false; // Track current orientation
  bool _showTip = true; // Control tip visibility
  bool _hasSubtitles = false;
  String? _subtitlePath;
  List<SubtitleItem> _subtitles = [];
  int _currentSubtitleIndex = 0;

  // Player state
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isMuted = false;
  double _volume = 1.0;
  LoopMode _loopMode = LoopMode.none;
  PlaybackSpeed _playbackSpeed = PlaybackSpeed.x1_0;
  double _aspectRatio = 16 / 9; // Default aspect ratio
  double _audioDelay = 0.0; // Audio synchronization delay in seconds

  List<String> _playlist = [];
  int _currentPlaylistIndex = 0;
  Timer? _hideControlsTimer;
  Timer? _positionUpdateTimer; // Timer for updating position

  final GlobalKey _videoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Initialize playlist if available
    if (widget.playlist != null && widget.playlist!.isNotEmpty) {
      _playlist = List.from(widget.playlist!);
      _currentPlaylistIndex = widget.initialPlaylistIndex ?? 0;
    } else {
      _playlist = [widget.filePath];
      _currentPlaylistIndex = 0;
    }

    // Make sure controls are initially visible
    _showControls = true;

    // Show tip for 2 seconds then hide it
    _showTip = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showTip = false;
        });
      }
    });

    // Keep screen on during video playback
    PlatformService.keepScreenOn(true);

    // Start position update timer
    _startPositionUpdateTimer();

    // Load saved playlist
    _loadPlaylist().then((_) {
      // Add current file to playlist if not already there
      if (!_playlist.contains(widget.filePath)) {
        setState(() {
          _playlist.add(widget.filePath);
          _currentPlaylistIndex = _playlist.length - 1;
        });
      }

      // Initialize player with current file
      _initializePlayer(_playlist[_currentPlaylistIndex]);
    });

    // Initially set to landscape orientation
    _setLandscapeOrientation();

    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Allow screen to turn off when player is closed
    PlatformService.keepScreenOn(false);

    _videoController?.dispose();
    _audioPlayer?.dispose();
    _chewieController?.dispose();
    _hideControlsTimer?.cancel();
    _positionUpdateTimer?.cancel(); // Cancel position update timer

    // Reset orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Show system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  Future<void> _initializePlayer(String path) async {
    setState(() {
      _isLoading = true;
      _showControls = true; // Always show controls when loading new media
    });

    try {
      // Dispose existing controllers
      _chewieController?.dispose();
      _videoController?.dispose();
      _audioPlayer?.dispose();

      final isAudio = _isAudioFile(path);

      if (isAudio) {
        await _initializeAudioPlayer(path);
      } else {
        await _initializeVideoPlayer(path);
      }

      setState(() {
        _isLoading = false;
      });

      // Add to recent playlist if not already there
      if (!_playlist.contains(path)) {
        setState(() {
          _playlist.add(path);
          _currentPlaylistIndex = _playlist.length - 1;
        });
        _savePlaylist();
      }

      // Start auto-hide timer for controls
      _startHideTimer();
    } catch (e) {
      debugPrint('Error initializing player: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing media: $e')));
      }
    }
  }

  Future<void> _initializeVideoPlayer(String path) async {
    _videoController = VideoPlayerController.file(File(path));
    await _videoController!.initialize();

    _videoController!.addListener(_videoPlayerListener);

    // Get actual video aspect ratio to prevent stretching
    if (_videoController!.value.size.width > 0 &&
        _videoController!.value.size.height > 0) {
      setState(() {
        _aspectRatio = _videoController!.value.aspectRatio;
      });
    }

    // Initialize player state
    setState(() {
      _duration = _videoController!.value.duration;
      _isPlaying = _videoController!.value.isPlaying;
      _volume = _videoController!.value.volume;
    });

    // Set up Chewie controller
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      allowPlaybackSpeedChanging: true,
      allowedScreenSleep: false,
      showControls: false, // We'll use our custom controls
      aspectRatio: _aspectRatio, // Use actual video aspect ratio
    );

    // Start playback
    _videoController!.play();
  }

  Future<void> _initializeAudioPlayer(String path) async {
    _audioPlayer = just_audio.AudioPlayer();
    await _audioPlayer!.setFilePath(path);

    _audioPlayer!.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer!.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer!.playingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });

    // Initialize player state
    setState(() {
      _duration = _audioPlayer!.duration ?? Duration.zero;
      _isPlaying = _audioPlayer!.playing;
      _volume = _audioPlayer!.volume;
    });

    // Start playback
    _audioPlayer!.play();
  }

  void _videoPlayerListener() {
    if (!mounted) return;

    setState(() {
      _position = _videoController!.value.position;
      _isPlaying = _videoController!.value.isPlaying;
    });

    if (_hasSubtitles) {
      _updateCurrentSubtitle();
    }

    // Handle playback completion
    if (_videoController!.value.position >= _videoController!.value.duration) {
      if (_playlist.length > 1 &&
          _currentPlaylistIndex < _playlist.length - 1) {
        _skipToNext();
      }
    }
  }

  // Controls visibility
  void _startHideTimer() {
    // Cancel any existing timer first
    _hideControlsTimer?.cancel();

    // Set a longer timeout for Android
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _handleUserInteraction() {
    setState(() {
      _showControls = true;
    });
    _startHideTimer();
  }

  // Playback controls
  void _togglePlayPause() {
    if (_videoController != null) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    } else if (_audioPlayer != null) {
      if (_audioPlayer!.playing) {
        _audioPlayer!.pause();
      } else {
        _audioPlayer!.play();
      }
    }
  }

  void _seek(Duration position) {
    // Ensure position is not negative
    final Duration validPosition =
        position.isNegative ? Duration.zero : position;

    // Ensure position is not beyond duration
    final Duration clampedPosition =
        _duration > Duration.zero && validPosition > _duration
            ? _duration
            : validPosition;

    if (_videoController != null) {
      _videoController!.seekTo(clampedPosition);
    } else if (_audioPlayer != null) {
      _audioPlayer!.seek(clampedPosition);
    }

    // Update state to reflect new position immediately
    setState(() {
      _position = clampedPosition;
    });
  }

  void _skipToNext() {
    if (_playlist.length > 1 && _currentPlaylistIndex < _playlist.length - 1) {
      setState(() {
        _currentPlaylistIndex++;
      });
      _initializePlayer(_playlist[_currentPlaylistIndex]);
    }
  }

  void _skipToPrevious() {
    if (_playlist.length > 1 && _currentPlaylistIndex > 0) {
      setState(() {
        _currentPlaylistIndex--;
      });
      _initializePlayer(_playlist[_currentPlaylistIndex]);
    }
  }

  void _changeVolume(double volume) {
    if (_videoController != null) {
      _videoController!.setVolume(volume);
      setState(() {
        _volume = volume;
      });
    } else if (_audioPlayer != null) {
      _audioPlayer!.setVolume(volume);
      setState(() {
        _volume = volume;
      });
    }
  }

  void _toggleMute() {
    if (_videoController != null) {
      if (_isMuted) {
        _videoController!.setVolume(_volume);
      } else {
        _videoController!.setVolume(0);
      }
      setState(() {
        _isMuted = !_isMuted;
      });
    } else if (_audioPlayer != null) {
      if (_isMuted) {
        _audioPlayer!.setVolume(_volume);
      } else {
        _audioPlayer!.setVolume(0);
      }
      setState(() {
        _isMuted = !_isMuted;
      });
    }
  }

  void _changePlaybackSpeed(PlaybackSpeed speed) {
    double speedValue;
    switch (speed) {
      case PlaybackSpeed.x0_5:
        speedValue = 0.5;
        break;
      case PlaybackSpeed.x0_75:
        speedValue = 0.75;
        break;
      case PlaybackSpeed.x1_0:
        speedValue = 1.0;
        break;
      case PlaybackSpeed.x1_25:
        speedValue = 1.25;
        break;
      case PlaybackSpeed.x1_5:
        speedValue = 1.5;
        break;
      case PlaybackSpeed.x2_0:
        speedValue = 2.0;
        break;
    }

    if (_videoController != null) {
      _videoController!.setPlaybackSpeed(speedValue);
      setState(() {
        _playbackSpeed = speed;
      });
    } else if (_audioPlayer != null) {
      _audioPlayer!.setSpeed(speedValue);
      setState(() {
        _playbackSpeed = speed;
      });
    }
  }

  void _changeLoopMode(LoopMode mode) {
    setState(() {
      _loopMode = mode;
    });

    if (_videoController != null) {
      _videoController!.setLooping(mode != LoopMode.none);
    } else if (_audioPlayer != null) {
      switch (mode) {
        case LoopMode.none:
          _audioPlayer!.setLoopMode(just_audio.LoopMode.off);
          break;
        case LoopMode.one:
          _audioPlayer!.setLoopMode(just_audio.LoopMode.one);
          break;
        case LoopMode.all:
          _audioPlayer!.setLoopMode(just_audio.LoopMode.all);
          break;
      }
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _togglePlaylist() {
    setState(() {
      _showPlaylist = !_showPlaylist;
    });
  }

  void _handleContextMenu(BuildContext context, Offset position) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 15),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  _buildContextMenuItem(
                    icon: Icons.folder_open,
                    title: 'Open Media',
                    onTap: () {
                      Navigator.pop(context);
                      _openNewMedia();
                    },
                  ),
                  _buildContextMenuItem(
                    icon: Icons.playlist_play,
                    title: _showPlaylist ? 'Hide Playlist' : 'Show Playlist',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _showPlaylist = !_showPlaylist;
                      });
                    },
                  ),
                  _buildContextMenuItem(
                    icon: Icons.info_outline,
                    title: 'Media Information',
                    onTap: () {
                      Navigator.pop(context);
                      _showMediaInfo();
                    },
                  ),
                  _buildContextMenuItem(
                    icon: Icons.camera_alt,
                    title: 'Take Screenshot',
                    onTap: () {
                      Navigator.pop(context);
                      _takeScreenshot();
                    },
                  ),
                  if (!_isAudioFile(_playlist[_currentPlaylistIndex])) ...[
                    _buildContextMenuItem(
                      icon: Icons.subtitles,
                      title:
                          _hasSubtitles ? 'Remove Subtitles' : 'Add Subtitles',
                      onTap: () {
                        Navigator.pop(context);
                        if (_hasSubtitles) {
                          setState(() {
                            _hasSubtitles = false;
                            _subtitlePath = null;
                            _subtitles.clear();
                            _currentSubtitleIndex = -1;
                          });
                        } else {
                          _addSubtitle();
                        }
                      },
                    ),
                    _buildContextMenuItem(
                      icon: Icons.sync,
                      title: 'Audio Sync',
                      onTap: () {
                        Navigator.pop(context);
                        _showAudioSyncSettings();
                      },
                    ),
                    _buildContextMenuItem(
                      icon: Icons.aspect_ratio,
                      title: 'Aspect Ratio',
                      onTap: () {
                        Navigator.pop(context);
                        _showAspectRatioSettings();
                      },
                    ),
                  ] else ...[
                    _buildContextMenuItem(
                      icon: Icons.audiotrack,
                      title: 'Audio Settings',
                      onTap: () {
                        Navigator.pop(context);
                        _showSettingsDialog();
                      },
                    ),
                  ],
                  _buildContextMenuItem(
                    icon: Icons.help_outline,
                    title: 'About',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildContextMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: primaryPink),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
      dense: true,
    );
  }

  Future<void> _takeScreenshot() async {
    if (_videoController == null) return;

    try {
      // Pause video to take snapshot
      final wasPlaying = _videoController!.value.isPlaying;
      if (wasPlaying) {
        await _videoController!.pause();
      }

      // Show directory picker dialog before saving
      final folderService = FolderBrowserService();
      final selectedDir = await folderService.pickFolder();

      if (selectedDir == null) {
        // User cancelled the directory selection
        // Resume playing if it was playing
        if (wasPlaying) {
          _videoController!.play();
        }
        return;
      }

      // Create the screenshot with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'snapshot_$timestamp.jpg';
      final path = '$selectedDir/$fileName';

      // Capture the actual screenshot using RenderRepaintBoundary
      final boundary =
          _videoKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData?.buffer.asUint8List();

        if (pngBytes != null) {
          final file = File(path);
          await file.writeAsBytes(pngBytes);

          // Resume playing if it was playing
          if (wasPlaying) {
            _videoController!.play();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Screenshot saved to: $path'),
                action: SnackBarAction(
                  label: 'Open Folder',
                  onPressed: () {
                    // Try to open the folder with the platform's file explorer
                    try {
                      final folderUri = Uri.directory(selectedDir);
                      launchUrl(folderUri);
                    } catch (e) {
                      debugPrint('Error opening folder: $e');
                    }
                  },
                ),
              ),
            );
          }
        } else {
          throw Exception('Failed to capture image data');
        }
      } else {
        throw Exception('Failed to capture video frame');
      }
    } catch (e) {
      debugPrint('Error taking screenshot: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error taking screenshot: $e')));
      }
    }
  }

  void _showMediaInfo() {
    final filePath = _playlist[_currentPlaylistIndex];
    final fileName = filePath.split('/').last;

    try {
      final file = File(filePath);
      final fileSize =
          file.existsSync()
              ? (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2)
              : 'Unknown';

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Media Information'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: $fileName'),
                    Text('Size: $fileSize MB'),
                    Text('Duration: ${_formatDuration(_duration)}'),
                    if (_videoController != null) ...[
                      Text(
                        'Resolution: ${_videoController!.value.size.width.toInt()}x${_videoController!.value.size.height.toInt()}',
                      ),
                      Text('Aspect Ratio: ${_aspectRatio.toStringAsFixed(2)}'),
                      Text(
                        'Video Speed: ${_playbackSpeed.toString().split('.').last.replaceAll('_', '.')}x',
                      ),
                    ],
                    Text('Loop Mode: ${_loopMode.toString().split('.').last}'),
                    Text('Volume: ${(_volume * 100).toInt()}%'),
                    Text('Path: $filePath'),
                    const SizedBox(height: 10),
                    const Text(
                      'Keyboard Shortcuts:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('Space: Play/Pause'),
                    const Text('Right Arrow: Forward 10s'),
                    const Text('Left Arrow: Backward 10s'),
                    const Text('Up Arrow: Volume Up'),
                    const Text('Down Arrow: Volume Down'),
                    const Text('F11: Toggle Fullscreen'),
                    const Text('N: Next Media'),
                    const Text('P: Previous Media'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      debugPrint('Error showing media info: $e');
    }
  }

  void _showSettingsDialog() {
    // This would show audio/video settings like equalizer, etc.
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              _isAudioFile(_playlist[_currentPlaylistIndex])
                  ? 'Audio Settings'
                  : 'Video Settings',
            ),
            content: const Text('Advanced settings coming soon!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isAudioOnly = _audioPlayer != null && _videoController == null;

    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RawKeyboardListener(
                focusNode: FocusNode()..requestFocus(),
                autofocus: true,
                onKey: _handleKeyPress,
                child: SafeArea(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      debugPrint("Tap detected");
                      setState(() {
                        _showControls = !_showControls;
                      });
                      if (_showControls) {
                        _startHideTimer();
                      }
                    },
                    onLongPress:
                        () => _handleContextMenu(
                          context,
                          Offset(screenSize.width / 2, screenSize.height / 2),
                        ),
                    onDoubleTap: _togglePlayPause,
                    // Enable right-click menu for desktop platforms
                    onSecondaryTap:
                        () => _handleContextMenu(
                          context,
                          Offset(screenSize.width / 2, screenSize.height / 2),
                        ),
                    child: Stack(
                      children: [
                        // Video content with proper aspect ratio
                        Center(
                          child:
                              isAudioOnly
                                  ? _buildAudioPlayerUI()
                                  : RepaintBoundary(
                                    key: _videoKey,
                                    child: AspectRatio(
                                      aspectRatio: _aspectRatio,
                                      child:
                                          _chewieController != null
                                              ? Chewie(
                                                controller: _chewieController!,
                                              )
                                              : Container(color: Colors.black),
                                    ),
                                  ),
                        ),

                        // Controls overlay - always show briefly when loaded
                        AnimatedOpacity(
                          opacity: _showControls ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            color: Colors.black.withOpacity(0.4),
                            child: Stack(
                              children: [
                                // Top bar
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: _buildTopBar(),
                                ),

                                // Play/Pause button in center
                                Align(
                                  alignment: Alignment.center,
                                  child: IconButton(
                                    iconSize: 60,
                                    icon: Icon(
                                      _isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                      color: Colors.white,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                ),

                                // Bottom controls
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: _buildBottomControls(),
                                ),

                                // Playlist sidebar if visible
                                if (_showPlaylist)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    bottom: 0,
                                    width: screenSize.width * 0.7,
                                    child: _buildPlaylistSidebar(),
                                  ),

                                if (_hasSubtitles) _buildSubtitleOverlay(),
                              ],
                            ),
                          ),
                        ),

                        // Tip message - shows for 2 seconds then fades out
                        if (_showTip)
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: AnimatedOpacity(
                              opacity: _showTip ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: primaryPink.withOpacity(0.5),
                                    ),
                                  ),
                                  child: const Text(
                                    "Tip: Long-press for menu, tap for controls",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.black.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            FolderBrowserService().getFileName(
              _playlist[_currentPlaylistIndex],
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              // Keyboard shortcuts help button
              IconButton(
                icon: const Icon(Icons.keyboard, color: Colors.white),
                onPressed: _showKeyboardShortcutsHelp,
                tooltip: 'Keyboard Shortcuts',
              ),
              // Orientation toggle button
              IconButton(
                icon: Icon(
                  _isPortrait
                      ? Icons.screen_rotation
                      : Icons.stay_current_portrait,
                  color: Colors.white,
                ),
                onPressed: _toggleOrientation,
                tooltip:
                    _isPortrait ? 'Switch to Landscape' : 'Switch to Portrait',
              ),
              // Aspect ratio button - allows user to cycle through aspect ratio options
              IconButton(
                icon: const Icon(Icons.aspect_ratio, color: Colors.white),
                onPressed: _cycleAspectRatio,
                tooltip: 'Change Aspect Ratio',
              ),
              IconButton(
                icon: const Icon(Icons.playlist_play, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showPlaylist = !_showPlaylist;
                  });
                  _startHideTimer();
                },
              ),
              IconButton(
                icon: Icon(
                  _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                ),
                onPressed: _toggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Toggle between portrait and landscape
  void _toggleOrientation() {
    if (_isPortrait) {
      _setLandscapeOrientation();
    } else {
      _setPortraitOrientation();
    }

    // Force a rebuild of the UI
    setState(() {});
  }

  // Helper method to set landscape orientation
  void _setLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() {
      _isPortrait = false;
    });
  }

  // Helper method to set portrait orientation
  void _setPortraitOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    setState(() {
      _isPortrait = true;
    });
  }

  // Method to cycle through common aspect ratios
  void _cycleAspectRatio() {
    final aspectRatios = [
      _videoController?.value.aspectRatio ?? 16 / 9, // Original
      16 / 9, // Widescreen
      4 / 3, // Standard
      1.0, // Square
      21 / 9, // Ultrawide
    ];

    // Find current aspect ratio index
    int currentIndex = 0;
    for (int i = 0; i < aspectRatios.length; i++) {
      if ((aspectRatios[i] - _aspectRatio).abs() < 0.1) {
        currentIndex = i;
        break;
      }
    }

    // Move to next aspect ratio
    final nextIndex = (currentIndex + 1) % aspectRatios.length;

    setState(() {
      _aspectRatio = aspectRatios[nextIndex];
    });

    // Update Chewie controller
    if (_chewieController != null) {
      final currentController = _chewieController!;
      _chewieController = ChewieController(
        videoPlayerController: currentController.videoPlayerController,
        autoPlay: true,
        looping: currentController.looping,
        allowPlaybackSpeedChanging: true,
        allowedScreenSleep: false,
        showControls: false,
        aspectRatio: _aspectRatio,
      );
    }

    // Show aspect ratio info
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aspect Ratio: ${_aspectRatio.toStringAsFixed(2)}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // Show keyboard shortcuts help dialog
  void _showKeyboardShortcutsHelp() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.keyboard, color: primaryPink),
                const SizedBox(width: 10),
                const Text('Keyboard Shortcuts'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _KeyboardShortcutItem(
                    keyText: 'Space',
                    description: 'Play/Pause',
                  ),
                  _KeyboardShortcutItem(
                    keyText: '→',
                    description: 'Forward 10s',
                  ),
                  _KeyboardShortcutItem(
                    keyText: '←',
                    description: 'Backward 10s',
                  ),
                  _KeyboardShortcutItem(keyText: '↑', description: 'Volume Up'),
                  _KeyboardShortcutItem(
                    keyText: '↓',
                    description: 'Volume Down',
                  ),
                  _KeyboardShortcutItem(
                    keyText: 'F11',
                    description: 'Toggle Fullscreen',
                  ),
                  _KeyboardShortcutItem(
                    keyText: 'N',
                    description: 'Next Media',
                  ),
                  _KeyboardShortcutItem(
                    keyText: 'P',
                    description: 'Previous Media',
                  ),
                  _KeyboardShortcutItem(
                    keyText: 'M',
                    description: 'Toggle Mute',
                  ),
                  _KeyboardShortcutItem(
                    keyText: 'O',
                    description: 'Toggle Orientation',
                  ),
                  _KeyboardShortcutItem(
                    keyText: 'A',
                    description: 'Cycle Aspect Ratio',
                  ),
                  _KeyboardShortcutItem(
                    keyText: 'I',
                    description: 'Media Information',
                  ),
                  _KeyboardShortcutItem(
                    keyText: 'Esc',
                    description: 'Exit Fullscreen/Close Player',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  // Method to open new media file
  Future<void> _openNewMedia() async {
    try {
      final selectedFiles = await FolderBrowserService().pickMediaFiles();

      if (selectedFiles.isNotEmpty) {
        final filePath = selectedFiles.first;

        // Add to playlist and save
        setState(() {
          _playlist.add(filePath);
          _currentPlaylistIndex = _playlist.length - 1;
        });

        // Save updated playlist
        _savePlaylist();

        // Play the new media
        _initializePlayer(filePath);
      }
    } catch (e) {
      debugPrint('Error opening new media: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening media: $e')));
      }
    }
  }

  // Save playlist to local storage
  Future<void> _savePlaylist() async {
    try {
      // In a real implementation, you would save to local storage
      // For now, we just print to console for demonstration
      debugPrint('Playlist saved: $_playlist');
    } catch (e) {
      debugPrint('Error saving playlist: $e');
    }
  }

  // Load playlist from local storage
  Future<void> _loadPlaylist() async {
    try {
      // In a real implementation, you would load from local storage
      // For now, we just use the current playlist
      debugPrint('Playlist loaded: $_playlist');
    } catch (e) {
      debugPrint('Error loading playlist: $e');
    }
  }

  // Build the playlist sidebar
  Widget _buildPlaylistSidebar() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Column(
        children: [
          // Playlist header
          Container(
            padding: const EdgeInsets.all(16),
            color: primaryPink,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Playlist',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: _addToPlaylist,
                      tooltip: 'Add Media',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _showPlaylist = false;
                        });
                      },
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Now playing item
          if (_playlist.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: primaryPink.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Now Playing:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FolderBrowserService().getFileName(
                      _playlist[_currentPlaylistIndex],
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

          // Playlist items
          Expanded(
            child: ListView.builder(
              itemCount: _playlist.length,
              itemBuilder: (context, index) {
                final isPlaying = index == _currentPlaylistIndex;
                final fileName = FolderBrowserService().getFileName(
                  _playlist[index],
                );
                final isAudio = _isAudioFile(_playlist[index]);

                return ListTile(
                  leading: Icon(
                    isAudio ? Icons.music_note : Icons.movie,
                    color: isPlaying ? primaryPink : Colors.white70,
                  ),
                  title: Text(
                    fileName,
                    style: TextStyle(
                      color: isPlaying ? primaryPink : Colors.white,
                      fontWeight:
                          isPlaying ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    isAudio ? 'Audio' : 'Video',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  trailing:
                      isPlaying
                          ? const Icon(
                            Icons.play_circle_fill,
                            color: primaryPink,
                            size: 20,
                          )
                          : null,
                  onTap: () {
                    if (index != _currentPlaylistIndex) {
                      setState(() {
                        _currentPlaylistIndex = index;
                      });
                      _initializePlayer(_playlist[index]);
                    }
                  },
                  onLongPress: () => _showPlaylistItemMenu(context, index),
                );
              },
            ),
          ),

          // Playlist controls
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black.withOpacity(0.7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.shuffle, color: Colors.white70),
                  onPressed: _shufflePlaylist,
                  tooltip: 'Shuffle',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.white70),
                  onPressed: _clearPlaylist,
                  tooltip: 'Clear All',
                ),
                IconButton(
                  icon: Icon(
                    _loopMode == LoopMode.all ? Icons.repeat_on : Icons.repeat,
                    color:
                        _loopMode == LoopMode.all
                            ? primaryPink
                            : Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _loopMode =
                          _loopMode == LoopMode.all
                              ? LoopMode.none
                              : LoopMode.all;
                    });
                    _changeLoopMode(_loopMode);
                  },
                  tooltip: 'Repeat All',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Check if file is audio
  bool _isAudioFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return [
      'mp3',
      'wav',
      'ogg',
      'aac',
      'flac',
      'm4a',
      'wma',
    ].contains(extension);
  }

  // Format duration to string
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  // Handle keyboard input
  void _handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.space:
          _togglePlayPause();
          break;
        case LogicalKeyboardKey.arrowRight:
          _seek(_position + const Duration(seconds: 10));
          break;
        case LogicalKeyboardKey.arrowLeft:
          _seek(_position - const Duration(seconds: 10));
          break;
        case LogicalKeyboardKey.arrowUp:
          _changeVolume((_volume + 0.1).clamp(0.0, 1.0));
          break;
        case LogicalKeyboardKey.arrowDown:
          _changeVolume((_volume - 0.1).clamp(0.0, 1.0));
          break;
        case LogicalKeyboardKey.f11:
          _toggleFullscreen();
          break;
        case LogicalKeyboardKey.keyN:
          _skipToNext();
          break;
        case LogicalKeyboardKey.keyP:
          _skipToPrevious();
          break;
        case LogicalKeyboardKey.keyM:
          _toggleMute();
          break;
        case LogicalKeyboardKey.keyO:
          _toggleOrientation();
          break;
        case LogicalKeyboardKey.keyA:
          _cycleAspectRatio();
          break;
        case LogicalKeyboardKey.keyI:
          _showMediaInfo();
          break;
        case LogicalKeyboardKey.escape:
          if (_isFullscreen) {
            _toggleFullscreen();
          } else {
            Navigator.pop(context);
          }
          break;
      }
    }
  }

  // Build audio player UI
  Widget _buildAudioPlayerUI() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Album art placeholder (can be replaced with actual album art if available)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: primaryPink.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.music_note, size: 100, color: primaryPink),
            ),
          ),
          const SizedBox(height: 30),
          // Song title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              FolderBrowserService().getFileName(
                _playlist[_currentPlaylistIndex],
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          // Additional info (can be populated with metadata if available)
          Text(
            "Now Playing",
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // Build seekbar
  Widget _buildSeekBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          // Seekbar slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              activeTrackColor: primaryPink,
              inactiveTrackColor: Colors.grey[600],
              thumbColor: Colors.white,
              overlayColor: primaryPink.withOpacity(0.3),
            ),
            child: Slider(
              value: _position.inSeconds.toDouble(),
              min: 0,
              max:
                  _duration.inSeconds > 0
                      ? _duration.inSeconds.toDouble()
                      : 1.0,
              onChanged: (value) {
                _seek(Duration(seconds: value.toInt()));
                // Keep controls visible after seeking
                _startHideTimer();
              },
              onChangeStart: (_) {
                // Keep controls visible during seeking
                _hideControlsTimer?.cancel();
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build bottom controls
  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Add seekbar
        _buildSeekBar(),
        // Control buttons
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.black.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 10 seconds backward
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () => _seek(_position - const Duration(seconds: 10)),
                tooltip: '10 Seconds Backward',
              ),
              // Previous track
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: _skipToPrevious,
                tooltip: 'Previous Track',
              ),
              // Play/Pause
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: _togglePlayPause,
                tooltip: _isPlaying ? 'Pause' : 'Play',
              ),
              // Next track
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: _skipToNext,
                tooltip: 'Next Track',
              ),
              // 10 seconds forward
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () => _seek(_position + const Duration(seconds: 10)),
                tooltip: '10 Seconds Forward',
              ),
              // Volume control
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: _toggleMute,
                tooltip: _isMuted ? 'Unmute' : 'Mute',
              ),
              // Exit app
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Exit Player'),
                          content: const Text('Are you sure you want to exit?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                              child: const Text('Exit'),
                            ),
                          ],
                        ),
                  );
                },
                tooltip: 'Exit Player',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Add to playlist
  Future<void> _addToPlaylist() async {
    try {
      final selectedFiles = await FolderBrowserService().pickMediaFiles();
      if (selectedFiles.isNotEmpty) {
        setState(() {
          _playlist.addAll(selectedFiles);
        });
        _savePlaylist();
      }
    } catch (e) {
      debugPrint('Error adding to playlist: $e');
    }
  }

  // Show playlist item menu
  void _showPlaylistItemMenu(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 15),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.play_arrow, color: primaryPink),
                    title: const Text(
                      'Play Now',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentPlaylistIndex = index;
                      });
                      _initializePlayer(_playlist[index]);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: primaryPink),
                    title: const Text(
                      'Remove from Playlist',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _removeFromPlaylist(index);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Shuffle playlist
  void _shufflePlaylist() {
    if (_playlist.length <= 1) return;
    final currentPath = _playlist[_currentPlaylistIndex];
    setState(() {
      _playlist.shuffle();
      _currentPlaylistIndex = _playlist.indexOf(currentPath);
    });
  }

  // Clear playlist
  void _clearPlaylist() {
    if (_playlist.isEmpty) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Playlist'),
            content: const Text('Are you sure you want to clear the playlist?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _playlist = [_playlist[_currentPlaylistIndex]];
                    _currentPlaylistIndex = 0;
                  });
                },
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }

  // Show video settings
  void _showVideoSettings() {
    double brightness = 1.0;
    double contrast = 1.0;
    double saturation = 1.0;
    double sharpness = 1.0;
    double gamma = 1.0;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Video Settings'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Brightness'),
                        Slider(
                          value: brightness,
                          min: 0.5,
                          max: 1.5,
                          divisions: 10,
                          label: brightness.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() => brightness = value);
                            _applyVideoEffects(
                              brightness,
                              contrast,
                              saturation,
                              sharpness,
                              gamma,
                            );
                          },
                        ),
                        const Text('Contrast'),
                        Slider(
                          value: contrast,
                          min: 0.5,
                          max: 1.5,
                          divisions: 10,
                          label: contrast.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() => contrast = value);
                            _applyVideoEffects(
                              brightness,
                              contrast,
                              saturation,
                              sharpness,
                              gamma,
                            );
                          },
                        ),
                        const Text('Saturation'),
                        Slider(
                          value: saturation,
                          min: 0.0,
                          max: 2.0,
                          divisions: 10,
                          label: saturation.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() => saturation = value);
                            _applyVideoEffects(
                              brightness,
                              contrast,
                              saturation,
                              sharpness,
                              gamma,
                            );
                          },
                        ),
                        const Text('Sharpness'),
                        Slider(
                          value: sharpness,
                          min: 0.5,
                          max: 1.5,
                          divisions: 10,
                          label: sharpness.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() => sharpness = value);
                            _applyVideoEffects(
                              brightness,
                              contrast,
                              saturation,
                              sharpness,
                              gamma,
                            );
                          },
                        ),
                        const Text('Gamma'),
                        Slider(
                          value: gamma,
                          min: 0.5,
                          max: 1.5,
                          divisions: 10,
                          label: gamma.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() => gamma = value);
                            _applyVideoEffects(
                              brightness,
                              contrast,
                              saturation,
                              sharpness,
                              gamma,
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                brightness = 1.0;
                                contrast = 1.0;
                                saturation = 1.0;
                                sharpness = 1.0;
                                gamma = 1.0;
                              });
                              _applyVideoEffects(
                                brightness,
                                contrast,
                                saturation,
                                sharpness,
                                gamma,
                              );
                            },
                            child: const Text('Reset to Default'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          ),
    );
  }

  // Apply video effects
  void _applyVideoEffects(
    double brightness,
    double contrast,
    double saturation,
    double sharpness,
    double gamma,
  ) {
    if (_videoController != null) {
      // In a real implementation, you would apply these effects to the video
      // For now, we'll show a message indicating the changes
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Video Effects:\n'
            'Brightness: ${brightness.toStringAsFixed(1)}\n'
            'Contrast: ${contrast.toStringAsFixed(1)}\n'
            'Saturation: ${saturation.toStringAsFixed(1)}\n'
            'Sharpness: ${sharpness.toStringAsFixed(1)}\n'
            'Gamma: ${gamma.toStringAsFixed(1)}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Audio sync settings
  void _showAudioSyncSettings() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Audio Synchronization'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Current delay: ${_audioDelay.toStringAsFixed(1)} seconds',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Slider(
                        value: _audioDelay,
                        min: -5.0,
                        max: 5.0,
                        divisions: 100,
                        label: _audioDelay.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() => _audioDelay = value);
                          _applyAudioDelay();
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              setState(() {
                                _audioDelay = (_audioDelay - 0.1).clamp(
                                  -5.0,
                                  5.0,
                                );
                              });
                              _applyAudioDelay();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              setState(() => _audioDelay = 0.0);
                              _applyAudioDelay();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                _audioDelay = (_audioDelay + 0.1).clamp(
                                  -5.0,
                                  5.0,
                                );
                              });
                              _applyAudioDelay();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Adjust if audio and video are out of sync.\n'
                        'Negative values make audio play earlier,\n'
                        'positive values make audio play later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          ),
    );
  }

  // Apply audio delay
  void _applyAudioDelay() {
    if (_videoController != null) {
      // In a real implementation, you would apply the audio delay
      // For now, we'll show a message indicating the change
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Audio delay set to ${_audioDelay.toStringAsFixed(1)} seconds',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // Aspect ratio settings
  void _showAspectRatioSettings() {
    final aspectRatios = [
      {
        'name': 'Original',
        'ratio': _videoController?.value.aspectRatio ?? 16 / 9,
      },
      {'name': '16:9 (Widescreen)', 'ratio': 16 / 9},
      {'name': '4:3 (Standard)', 'ratio': 4 / 3},
      {'name': '1:1 (Square)', 'ratio': 1.0},
      {'name': '21:9 (Ultrawide)', 'ratio': 21 / 9},
      {
        'name': 'Stretch to Fill',
        'ratio':
            MediaQuery.of(context).size.width /
            MediaQuery.of(context).size.height,
      },
    ];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Aspect Ratio'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  aspectRatios.map((ar) {
                    final ratio = ar['ratio'] as double;
                    return ListTile(
                      title: Text(ar['name'] as String),
                      subtitle: Text('${ratio.toStringAsFixed(2)}'),
                      selected: (ratio - _aspectRatio).abs() < 0.1,
                      onTap: () {
                        setState(() {
                          _aspectRatio = ratio;
                        });
                        if (_chewieController != null) {
                          final currentController = _chewieController!;
                          _chewieController = ChewieController(
                            videoPlayerController:
                                currentController.videoPlayerController,
                            autoPlay: true,
                            looping: currentController.looping,
                            allowPlaybackSpeedChanging: true,
                            allowedScreenSleep: false,
                            showControls: false,
                            aspectRatio: _aspectRatio,
                          );
                        }
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  // Subtitle settings
  void _showSubtitleSettings() {
    double fontSize = 16.0;
    Color fontColor = Colors.white;
    Color backgroundColor = Colors.black.withOpacity(0.5);
    String position = 'Bottom';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Subtitle Settings'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('Font Size'),
                          trailing: DropdownButton<double>(
                            value: fontSize,
                            items:
                                [12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0]
                                    .map(
                                      (size) => DropdownMenuItem(
                                        value: size,
                                        child: Text('${size.toInt()}'),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => fontSize = value);
                                _applySubtitleSettings(
                                  fontSize,
                                  fontColor,
                                  backgroundColor,
                                  position,
                                );
                              }
                            },
                          ),
                        ),
                        ListTile(
                          title: const Text('Font Color'),
                          trailing: DropdownButton<Color>(
                            value: fontColor,
                            items:
                                [
                                      Colors.white,
                                      Colors.yellow,
                                      Colors.green,
                                      Colors.cyan,
                                      Colors.red,
                                    ]
                                    .map(
                                      (color) => DropdownMenuItem(
                                        value: color,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          color: color,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => fontColor = value);
                                _applySubtitleSettings(
                                  fontSize,
                                  fontColor,
                                  backgroundColor,
                                  position,
                                );
                              }
                            },
                          ),
                        ),
                        ListTile(
                          title: const Text('Background Color'),
                          trailing: DropdownButton<Color>(
                            value: backgroundColor,
                            items:
                                [
                                      Colors.black.withOpacity(0.5),
                                      Colors.black.withOpacity(0.7),
                                      Colors.black.withOpacity(0.9),
                                      Colors.transparent,
                                    ]
                                    .map(
                                      (color) => DropdownMenuItem(
                                        value: color,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          color: color,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => backgroundColor = value);
                                _applySubtitleSettings(
                                  fontSize,
                                  fontColor,
                                  backgroundColor,
                                  position,
                                );
                              }
                            },
                          ),
                        ),
                        ListTile(
                          title: const Text('Position'),
                          trailing: DropdownButton<String>(
                            value: position,
                            items:
                                ['Top', 'Middle', 'Bottom']
                                    .map(
                                      (pos) => DropdownMenuItem(
                                        value: pos,
                                        child: Text(pos),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => position = value);
                                _applySubtitleSettings(
                                  fontSize,
                                  fontColor,
                                  backgroundColor,
                                  position,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                fontSize = 16.0;
                                fontColor = Colors.white;
                                backgroundColor = Colors.black.withOpacity(0.5);
                                position = 'Bottom';
                              });
                              _applySubtitleSettings(
                                fontSize,
                                fontColor,
                                backgroundColor,
                                position,
                              );
                            },
                            child: const Text('Reset to Default'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          ),
    );
  }

  // Apply subtitle settings
  void _applySubtitleSettings(
    double fontSize,
    Color fontColor,
    Color backgroundColor,
    String position,
  ) {
    if (_videoController != null) {
      // In a real implementation, you would apply these settings to the video player
      // For now, we'll show a message indicating the changes
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subtitle Settings:\n'
            'Font Size: ${fontSize.toInt()}\n'
            'Font Color: ${fontColor.toString()}\n'
            'Background: ${backgroundColor.toString()}\n'
            'Position: $position',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Remove item from playlist
  void _removeFromPlaylist(int index) {
    if (_playlist.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove the only item in playlist'),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      if (index == _currentPlaylistIndex) {
        if (index < _playlist.length - 1) {
          _playlist.removeAt(index);
          _initializePlayer(_playlist[_currentPlaylistIndex]);
        } else {
          _playlist.removeAt(index);
          _currentPlaylistIndex = _playlist.length - 1;
          _initializePlayer(_playlist[_currentPlaylistIndex]);
        }
      } else {
        if (index < _currentPlaylistIndex) {
          _currentPlaylistIndex--;
        }
        _playlist.removeAt(index);
      }
    });

    _savePlaylist();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item removed from playlist'),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Add subtitle file
  Future<void> _addSubtitle() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        _subtitlePath = file.path;
        await _loadSubtitles(file);
        setState(() {
          _hasSubtitles = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading subtitle file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading subtitle file: $e')),
        );
      }
    }
  }

  // Load subtitles from file
  Future<void> _loadSubtitles(File file) async {
    try {
      final content = await file.readAsString();
      _subtitles = _parseSubtitleFile(content);
      setState(() {});
    } catch (e) {
      debugPrint('Error parsing subtitle file: $e');
      throw Exception('Failed to parse subtitle file');
    }
  }

  // Parse subtitle file content
  List<SubtitleItem> _parseSubtitleFile(String content) {
    final List<SubtitleItem> subtitles = [];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;

      try {
        // Parse SRT format
        if (lines[i].contains('-->')) {
          final times = lines[i].split('-->');
          final startTime = _parseSubtitleTime(times[0].trim());
          final endTime = _parseSubtitleTime(times[1].trim());

          i++;
          final text = StringBuffer();
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            text.writeln(lines[i]);
            i++;
          }

          subtitles.add(
            SubtitleItem(
              startTime: startTime,
              endTime: endTime,
              text: text.toString().trim(),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error parsing subtitle line: $e');
      }
    }

    return subtitles;
  }

  // Parse subtitle time format
  Duration _parseSubtitleTime(String time) {
    final parts = time.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = double.parse(parts[2].replaceAll(',', '.'));

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds.toInt(),
      milliseconds: ((seconds - seconds.toInt()) * 1000).toInt(),
    );
  }

  // Update current subtitle based on video position
  void _updateCurrentSubtitle() {
    if (_videoController == null || _subtitles.isEmpty) return;

    final position = _videoController!.value.position;
    for (int i = 0; i < _subtitles.length; i++) {
      if (position >= _subtitles[i].startTime &&
          position <= _subtitles[i].endTime) {
        if (_currentSubtitleIndex != i) {
          setState(() {
            _currentSubtitleIndex = i;
          });
        }
        return;
      }
    }

    if (_currentSubtitleIndex != -1) {
      setState(() {
        _currentSubtitleIndex = -1;
      });
    }
  }

  // Build subtitle overlay
  Widget _buildSubtitleOverlay() {
    if (!_hasSubtitles || _currentSubtitleIndex == -1) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          _subtitles[_currentSubtitleIndex].text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            shadows: [
              Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }

  // Start timer to update position periodically
  void _startPositionUpdateTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) {
      if (mounted) {
        if (_videoController != null && _videoController!.value.isInitialized) {
          setState(() {
            _position = _videoController!.value.position;
          });
        } else if (_audioPlayer != null) {
          _updateAudioPosition();
        }
      }
    });
  }

  // Update audio position directly
  void _updateAudioPosition() async {
    if (_audioPlayer != null) {
      final position = await _audioPlayer!.position;
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    }
  }
}

// Helper widget for displaying keyboard shortcuts
class _KeyboardShortcutItem extends StatelessWidget {
  final String keyText;
  final String description;

  const _KeyboardShortcutItem({
    required this.keyText,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Text(
              keyText,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }
}

// Subtitle item class
class SubtitleItem {
  final Duration startTime;
  final Duration endTime;
  final String text;

  SubtitleItem({
    required this.startTime,
    required this.endTime,
    required this.text,
  });
}
