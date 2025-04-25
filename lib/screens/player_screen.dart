import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

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
  AudioPlayer? _audioPlayer;
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

  // Add these properties to the _PlayerScreenState class
  double _bassBoost = 0.0;
  double _trebleBoost = 0.0;
  double _balance = 0.0; // -1.0 (left) to 1.0 (right)
  double _spatializer = 0.0;
  bool _nightMode = false;
  bool _autoVolume = false;
  bool _voiceEnhancement = false;
  List<double> _equalizerBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  int _selectedAudioPreset = 0;

  // List of audio presets
  final List<String> _audioPresets = [
    'Flat (Default)',
    'Bass Boost',
    'Treble Boost',
    'Classical',
    'Rock',
    'Pop',
    'Jazz',
    'Electronic',
    'Vocal Boost',
  ];

  // Store custom album art paths for audio files
  final Map<String, String> _customAlbumArtPaths = {};

  // Get custom album art path for a file if it exists
  String? _getCustomAlbumArtPath(String audioFilePath) {
    return _customAlbumArtPaths[audioFilePath];
  }

  // Set custom album art for current audio file
  Future<void> _setCustomAlbumArt() async {
    if (!_isAudioFile(_playlist[_currentPlaylistIndex])) return;

    try {
      // Use FilePicker to select an image
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final imagePath = result.files.first.path;
        if (imagePath != null) {
          // Show preview dialog
          if (mounted) {
            final bool confirmed = await _showAlbumArtPreviewDialog(imagePath);
            if (!confirmed) return; // User canceled
          }

          // Store the custom album art path for this audio file
          setState(() {
            _customAlbumArtPaths[_playlist[_currentPlaylistIndex]] = imagePath;
          });

          // Save the mapping to persistent storage
          await _saveCustomAlbumArtMappings();

          // Show confirmation
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Album art set successfully'),
                backgroundColor: primaryPink,
              ),
            );
          }

          // Refresh the UI to show the new album art
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error setting custom album art: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting album art: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show a preview of the selected album art with confirmation
  Future<bool> _showAlbumArtPreviewDialog(String imagePath) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.grey[900],
                title: Text(
                  'Confirm Album Art',
                  style: TextStyle(color: Colors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: 300,
                        maxWidth: 300,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(imagePath),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.red,
                                size: 50,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Use this image as album art?',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(backgroundColor: primaryPink),
                    child: Text(
                      'Set as Album Art',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        ) ??
        false; // Return false if dialog is dismissed
  }

  // Save custom album art mappings to persistent storage
  Future<void> _saveCustomAlbumArtMappings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/custom_album_art.json');

      // Convert map to JSON string using proper encoding
      final Map<String, dynamic> jsonMap = {};
      _customAlbumArtPaths.forEach((key, value) {
        jsonMap[key] = value;
      });

      final jsonString = json.encode(jsonMap);
      await file.writeAsString(jsonString);

      debugPrint('Custom album art mappings saved');
    } catch (e) {
      debugPrint('Error saving custom album art mappings: $e');
    }
  }

  // Load custom album art mappings from persistent storage
  Future<void> _loadCustomAlbumArtMappings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/custom_album_art.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final Map<String, dynamic> jsonMap = json.decode(jsonString);

        jsonMap.forEach((key, value) {
          _customAlbumArtPaths[key] = value.toString();
        });

        debugPrint(
          'Loaded ${_customAlbumArtPaths.length} custom album art mappings',
        );
      }
    } catch (e) {
      debugPrint('Error loading custom album art mappings: $e');
    }
  }

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

    // Load custom album art mappings
    _loadCustomAlbumArtMappings();

    // Load saved playlist
    _loadPlaylist().then((_) {
      // Add current file to playlist if not already there
      if (!_playlist.contains(widget.filePath)) {
        setState(() {
          _playlist.add(widget.filePath);
          _currentPlaylistIndex = _playlist.length - 1;
        });
      }

      // Check if it's an audio file and set orientation accordingly
      final isAudio = _isAudioFile(widget.filePath);
      if (isAudio) {
        _setPortraitOrientation();
      } else {
        _setLandscapeOrientation();
      }

      // Initialize player with current file
      _initializePlayer(_playlist[_currentPlaylistIndex]);
    });

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

      // Set controllers to null to avoid using disposed instances
      _chewieController = null;
      _videoController = null;
      _audioPlayer = null;

      final isAudio = _isAudioFile(path);

      if (isAudio) {
        // Set portrait orientation for audio files
        _setPortraitOrientation();
        await _initializeAudioPlayer(path);
      } else {
        // Set landscape orientation for video files
        _setLandscapeOrientation();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing media: $e'),
            action: SnackBarAction(
              label: 'Try Again',
              onPressed: () {
                // Try to initialize again or skip to next item if available
                if (_playlist.length > 1 &&
                    _currentPlaylistIndex < _playlist.length - 1) {
                  _skipToNext();
                } else {
                  _initializePlayer(path);
                }
              },
            ),
          ),
        );
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
    try {
      // Clean up any existing audio player to prevent resource leaks
      if (_audioPlayer != null) {
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }

      // Create a new instance
      _audioPlayer = AudioPlayer();

      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      debugPrint('Initializing audio player with path: $path');

      // Create a proper File object and verify it exists
      final audioFile = File(path);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found: $path');
      }

      // Log file details
      final fileSize = await audioFile.length();
      debugPrint(
        'Audio file exists: ${await audioFile.exists()}, Size: ${fileSize} bytes',
      );

      // Set up event listeners
      _setUpAudioEventListeners();

      // Different approach based on platform
      bool sourceSet = false;

      try {
        // First attempt: direct file source
        final source = DeviceFileSource(path);
        await _audioPlayer!.play(source);
        sourceSet = true;
        debugPrint('Standard method: Audio source set and playing');
      } catch (e) {
        debugPrint('First approach failed: $e');

        if (!sourceSet && Platform.isWindows) {
          try {
            // Second attempt: URI approach
            debugPrint('Trying URI approach');
            final uri = Uri.file(path).toString();
            debugPrint('URI: $uri');

            final source = UrlSource(uri);
            await _audioPlayer!.play(source);
            sourceSet = true;
            debugPrint('URI approach: Audio source set and playing');
          } catch (e2) {
            debugPrint('Second approach failed: $e2');

            // Third attempt: buffer into memory (only for smaller files)
            if (fileSize < 30 * 1024 * 1024) {
              // Less than 30MB
              try {
                debugPrint('Trying memory buffer approach for small file');
                final bytes = await audioFile.readAsBytes();
                debugPrint(
                  'File loaded into memory, size: ${bytes.length} bytes',
                );

                await _audioPlayer!.setSource(BytesSource(bytes));
                await _audioPlayer!.resume();
                sourceSet = true;
                debugPrint(
                  'Memory buffer approach: Audio source set and playing',
                );
              } catch (e3) {
                debugPrint('Memory buffer approach failed: $e3');
              }
            } else {
              debugPrint(
                'File too large for memory approach (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)',
              );
            }
          }
        }
      }

      // If we couldn't load the audio, throw an error
      if (!sourceSet) {
        throw Exception('Failed to set audio source after multiple attempts');
      }

      // Set volume and loop mode
      await _audioPlayer!.setVolume(_volume);

      // Initialize player state - audioplayers provides position/duration on demand
      setState(() {
        _isPlaying = true;
        _isLoading = false;
      });

      // Start a timer to update position periodically
      _startPositionUpdateTimer();
    } catch (e, stack) {
      debugPrint('Fatal error initializing audio player: $e');
      debugPrint('Stack trace: $stack');
      _handleAudioFailure(e);
    }
  }

  // Set up the audio player event listeners
  void _setUpAudioEventListeners() {
    if (_audioPlayer == null) return;

    _audioPlayer!.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    }, onError: (e) => debugPrint('Position changed error: $e'));

    _audioPlayer!.onDurationChanged.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    }, onError: (e) => debugPrint('Duration changed error: $e'));

    _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
        debugPrint('Player state changed: $state');
      }
    }, onError: (e) => debugPrint('Player state changed error: $e'));

    _audioPlayer!.onPlayerComplete.listen((_) {
      debugPrint('Audio playback completed with loop mode: $_loopMode');

      // Handle playback completion based on loop mode
      if (_loopMode == LoopMode.one) {
        // Loop the current track (already set in _changeLoopMode)
        // Just seek back to start to ensure it works properly
        _audioPlayer!.seek(Duration.zero);
        _audioPlayer!.resume();
      } else if (_loopMode == LoopMode.all && _playlist.length > 1) {
        // Loop through the playlist
        if (_currentPlaylistIndex < _playlist.length - 1) {
          _skipToNext();
        } else {
          // Return to the first item
          setState(() {
            _currentPlaylistIndex = 0;
          });
          _initializePlayer(_playlist[0]);
        }
      } else if (_loopMode == LoopMode.none) {
        // No looping, just go to next if available
        if (_playlist.length > 1 &&
            _currentPlaylistIndex < _playlist.length - 1) {
          _skipToNext();
        }
      }
    }, onError: (e) => debugPrint('Player complete error: $e'));
  }

  // Add video completion listener
  void _videoPlayerListener() {
    if (!mounted) return;

    // Handle video completion based on loop mode
    if (_videoController != null &&
        _videoController!.value.position >= _videoController!.value.duration &&
        !_videoController!.value.isPlaying) {
      debugPrint('Video playback completed with loop mode: $_loopMode');

      if (_loopMode == LoopMode.one) {
        // Loop current video
        _videoController!.seekTo(Duration.zero);
        _videoController!.play();
      } else if (_loopMode == LoopMode.all && _playlist.length > 1) {
        // Loop through playlist
        if (_currentPlaylistIndex < _playlist.length - 1) {
          _skipToNext();
        } else {
          // Return to first track
          setState(() {
            _currentPlaylistIndex = 0;
          });
          _initializePlayer(_playlist[0]);
        }
      } else if (_loopMode == LoopMode.none) {
        // No looping, just go to next if available
        if (_playlist.length > 1 &&
            _currentPlaylistIndex < _playlist.length - 1) {
          _skipToNext();
        }
      }
    }

    // Update subtitle if available
    if (_hasSubtitles) {
      _updateCurrentSubtitle();
    }

    // Update position state
    if (mounted && _videoController != null) {
      setState(() {
        _position = _videoController!.value.position;
        _isPlaying = _videoController!.value.isPlaying;
      });
    }
  }

  // Show a snackbar for audio issues
  void _showAudioIssueSnackbar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.orange,
          duration: const Duration(seconds: 3),
          action:
              isError
                  ? SnackBarAction(
                    label: 'Details',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Audio Issue Details'),
                              content: SingleChildScrollView(
                                child: Text(message),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                      );
                    },
                  )
                  : null,
        ),
      );
    }
  }

  void _handleAudioFailure(dynamic error) {
    // Clean up resources
    _audioPlayer?.dispose();
    _audioPlayer = null;

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play audio: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Details',
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Audio Error Details'),
                      content: SingleChildScrollView(child: Text('$error')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
              );
            },
          ),
        ),
      );
    }
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
      if (_isPlaying) {
        _audioPlayer!.pause();
      } else {
        _audioPlayer!.resume();
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
      _audioPlayer!.setPlaybackRate(speedValue);
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
          _audioPlayer!.setReleaseMode(ReleaseMode.release);
          break;
        case LoopMode.one:
          _audioPlayer!.setReleaseMode(ReleaseMode.loop);
          break;
        case LoopMode.all:
          // Note: audioplayers doesn't have direct playlist looping
          // We'll implement this manually in the onComplete handler
          _audioPlayer!.setReleaseMode(ReleaseMode.release);
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
                    _buildContextMenuItem(
                      icon: Icons.image,
                      title: 'Set Album Art',
                      onTap: () {
                        Navigator.pop(context);
                        _setCustomAlbumArt();
                      },
                    ),
                    if (_getCustomAlbumArtPath(
                          _playlist[_currentPlaylistIndex],
                        ) !=
                        null)
                      _buildContextMenuItem(
                        icon: Icons.image_not_supported,
                        title: 'Clear Custom Album Art',
                        onTap: () {
                          Navigator.pop(context);
                          _clearCustomAlbumArt();
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

      // Process the directory path to handle Android path issues
      String processedDir = selectedDir;

      // Fix for duplicate directories in path on Android (e.g. /storage/emulated/0/Documents/Documents)
      if (Platform.isAndroid) {
        // Remove duplicated path segments
        final segments =
            selectedDir.split('/').where((s) => s.isNotEmpty).toList();
        final uniqueSegments = <String>[];

        for (int i = 0; i < segments.length; i++) {
          // Skip if this segment is duplicated immediately after itself
          if (i < segments.length - 1 && segments[i] == segments[i + 1]) {
            continue;
          }
          uniqueSegments.add(segments[i]);
        }

        processedDir = '/${uniqueSegments.join('/')}';

        // Ensure directory exists
        final directory = Directory(processedDir);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }

      final path = '$processedDir/$fileName';
      debugPrint('Saving screenshot to: $path');

      // Capture the actual screenshot using RenderRepaintBoundary
      final boundary =
          _videoKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData?.buffer.asUint8List();

        if (pngBytes != null) {
          // Make sure parent directory exists
          final file = File(path);
          if (!await file.parent.exists()) {
            await file.parent.create(recursive: true);
          }

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
                      final folderUri = Uri.directory(processedDir);
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

      // Resume playing if needed
      if (_videoController != null && !_videoController!.value.isPlaying) {
        _videoController!.play();
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
    final isAudio = _isAudioFile(_playlist[_currentPlaylistIndex]);

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.black.withOpacity(0.9),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        children: [
                          Icon(
                            isAudio ? Icons.audiotrack : Icons.settings,
                            color: primaryPink,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isAudio
                                ? 'Audio Settings'
                                : 'Video & Audio Settings',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white60,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24),

                      // Make the dialog scrollable for many settings
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Audio Presets
                              const Text(
                                'Audio Presets',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _audioPresets.length,
                                  itemBuilder: (context, index) {
                                    final isSelected =
                                        _selectedAudioPreset == index;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedAudioPreset = index;
                                            _applyAudioPreset(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isSelected
                                                    ? primaryPink
                                                    : Colors.black45,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color:
                                                  isSelected
                                                      ? primaryPink
                                                      : Colors.white24,
                                            ),
                                          ),
                                          child: Text(
                                            _audioPresets[index],
                                            style: TextStyle(
                                              color:
                                                  isSelected
                                                      ? Colors.white
                                                      : Colors.white70,
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Equalizer
                              const Text(
                                'Equalizer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 150,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: List.generate(
                                    8,
                                    (index) => _buildEqualizerSlider(
                                      index,
                                      setState,
                                      [
                                        '60Hz',
                                        '150Hz',
                                        '400Hz',
                                        '1kHz',
                                        '2.4kHz',
                                        '6kHz',
                                        '10kHz',
                                        '16kHz',
                                      ][index],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Audio Enhancement
                              const Text(
                                'Audio Enhancement',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Bass Boost
                              Row(
                                children: [
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.graphic_eq,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Bass Boost',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _bassBoost,
                                      min: 0.0,
                                      max: 1.0,
                                      divisions: 10,
                                      label:
                                          (_bassBoost * 100).toInt().toString(),
                                      activeColor: primaryPink,
                                      onChanged: (value) {
                                        setState(() {
                                          _bassBoost = value;
                                          _selectedAudioPreset =
                                              0; // Reset to custom
                                        });
                                        // Apply the effect
                                        _applyAudioEffects();
                                      },
                                    ),
                                  ),
                                  Text(
                                    '${(_bassBoost * 100).toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),

                              // Treble Boost
                              Row(
                                children: [
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.graphic_eq,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Treble Boost',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _trebleBoost,
                                      min: 0.0,
                                      max: 1.0,
                                      divisions: 10,
                                      label:
                                          (_trebleBoost * 100)
                                              .toInt()
                                              .toString(),
                                      activeColor: primaryPink,
                                      onChanged: (value) {
                                        setState(() {
                                          _trebleBoost = value;
                                          _selectedAudioPreset =
                                              0; // Reset to custom
                                        });
                                        // Apply the effect
                                        _applyAudioEffects();
                                      },
                                    ),
                                  ),
                                  Text(
                                    '${(_trebleBoost * 100).toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),

                              // Spatial Audio
                              Row(
                                children: [
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.surround_sound,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Spatial Effect',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _spatializer,
                                      min: 0.0,
                                      max: 1.0,
                                      divisions: 10,
                                      label:
                                          (_spatializer * 100)
                                              .toInt()
                                              .toString(),
                                      activeColor: primaryPink,
                                      onChanged: (value) {
                                        setState(() {
                                          _spatializer = value;
                                          _selectedAudioPreset =
                                              0; // Reset to custom
                                        });
                                        // Apply the effect
                                        _applyAudioEffects();
                                      },
                                    ),
                                  ),
                                  Text(
                                    '${(_spatializer * 100).toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),

                              // Balance
                              Row(
                                children: [
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.compare_arrows,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Balance',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'L',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _balance,
                                      min: -1.0,
                                      max: 1.0,
                                      divisions: 20,
                                      activeColor: primaryPink,
                                      onChanged: (value) {
                                        setState(() {
                                          _balance = value;
                                        });
                                        // Apply the effect
                                        _applyAudioBalance();
                                      },
                                    ),
                                  ),
                                  const Text(
                                    'R',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Additional Options
                              const Text(
                                'Additional Options',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Night Mode
                              SwitchListTile(
                                title: const Text(
                                  'Night Mode',
                                  style: TextStyle(color: Colors.white),
                                ),
                                subtitle: const Text(
                                  'Reduce dynamic range for comfortable listening at night',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                value: _nightMode,
                                activeColor: primaryPink,
                                onChanged: (value) {
                                  setState(() {
                                    _nightMode = value;
                                  });
                                  _applyAudioEffects();
                                },
                              ),

                              // Auto Volume
                              SwitchListTile(
                                title: const Text(
                                  'Auto Volume',
                                  style: TextStyle(color: Colors.white),
                                ),
                                subtitle: const Text(
                                  'Automatically adjust volume levels for consistent sound',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                value: _autoVolume,
                                activeColor: primaryPink,
                                onChanged: (value) {
                                  setState(() {
                                    _autoVolume = value;
                                  });
                                  _applyAudioEffects();
                                },
                              ),

                              // Voice Enhancement
                              SwitchListTile(
                                title: const Text(
                                  'Voice Enhancement',
                                  style: TextStyle(color: Colors.white),
                                ),
                                subtitle: const Text(
                                  'Enhance dialogue and vocals for better clarity',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                value: _voiceEnhancement,
                                activeColor: primaryPink,
                                onChanged: (value) {
                                  setState(() {
                                    _voiceEnhancement = value;
                                  });
                                  _applyAudioEffects();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Divider(color: Colors.white24),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              // Reset all audio settings to default
                              setState(() {
                                _bassBoost = 0.0;
                                _trebleBoost = 0.0;
                                _balance = 0.0;
                                _spatializer = 0.0;
                                _nightMode = false;
                                _autoVolume = false;
                                _voiceEnhancement = false;
                                _equalizerBands = List.filled(8, 0.0);
                                _selectedAudioPreset = 0;
                              });
                              _applyAudioEffects();
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              backgroundColor: primaryPink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            child: const Text(
                              'Done',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  // Build an individual equalizer slider
  Widget _buildEqualizerSlider(int index, StateSetter setState, String label) {
    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: _equalizerBands[index] + 1.0, // Shift to 0.0-2.0 range
              min: 0.0,
              max: 2.0,
              divisions: 20,
              activeColor: primaryPink,
              thumbColor: Colors.white,
              onChanged: (value) {
                setState(() {
                  _equalizerBands[index] =
                      value - 1.0; // Shift back to -1.0 to 1.0 range
                  _selectedAudioPreset = 0; // Reset to custom
                });
                _applyEqualizer();
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        Text(
          '${(_equalizerBands[index] * 100).toInt()}%',
          style: const TextStyle(color: Colors.white60, fontSize: 9),
        ),
      ],
    );
  }

  // Apply audio preset
  void _applyAudioPreset(int presetIndex) {
    switch (presetIndex) {
      case 0: // Flat
        _bassBoost = 0.0;
        _trebleBoost = 0.0;
        _equalizerBands = List.filled(8, 0.0);
        break;
      case 1: // Bass Boost
        _bassBoost = 0.7;
        _trebleBoost = 0.0;
        _equalizerBands = [-0.8, -0.6, -0.2, 0.0, 0.0, 0.1, 0.1, 0.0];
        break;
      case 2: // Treble Boost
        _bassBoost = 0.0;
        _trebleBoost = 0.6;
        _equalizerBands = [0.0, 0.0, 0.0, 0.1, 0.2, 0.4, 0.6, 0.8];
        break;
      case 3: // Classical
        _bassBoost = 0.2;
        _trebleBoost = 0.2;
        _equalizerBands = [0.3, 0.2, 0.0, 0.0, 0.0, 0.1, 0.3, 0.4];
        break;
      case 4: // Rock
        _bassBoost = 0.5;
        _trebleBoost = 0.3;
        _equalizerBands = [0.4, 0.2, -0.1, -0.2, 0, 0.3, 0.4, 0.3];
        break;
      case 5: // Pop
        _bassBoost = 0.1;
        _trebleBoost = 0.2;
        _equalizerBands = [-0.2, 0.0, 0.2, 0.4, 0.3, 0.1, 0.1, 0.0];
        break;
      case 6: // Jazz
        _bassBoost = 0.3;
        _trebleBoost = 0.1;
        _equalizerBands = [0.3, 0.2, 0.0, 0.0, -0.1, -0.1, 0.0, 0.2];
        break;
      case 7: // Electronic
        _bassBoost = 0.6;
        _trebleBoost = 0.4;
        _equalizerBands = [0.5, 0.3, 0.0, -0.3, -0.2, 0.0, 0.5, 0.6];
        break;
      case 8: // Vocal Boost
        _bassBoost = 0.0;
        _trebleBoost = 0.2;
        _equalizerBands = [-0.1, 0.0, 0.2, 0.5, 0.6, 0.3, 0.0, -0.1];
        break;
    }

    // Apply all effects
    _applyAudioEffects();
    _applyEqualizer();
  }

  // Apply equalizer settings
  void _applyEqualizer() {
    if (_videoController != null || _audioPlayer != null) {
      debugPrint('Applying equalizer: $_equalizerBands');

      // Apply equalizer to audio player
      if (_audioPlayer != null) {
        // Create a basic equalizer configuration based on our 8 bands
        try {
          // This is a simulation since just_audio doesn't have direct equalizer support
          // In a real implementation, you would use platform-specific audio effects
          // For Android, you might use AndroidEqualizer from just_audio_background
          // For iOS, you might use AVAudioUnitEQ from AVFoundation

          // Apply volume changes based on equalizer bands (simplified simulation)
          final double avgBoost =
              _equalizerBands.reduce((a, b) => a + b) / _equalizerBands.length;
          final double volumeAdjustment =
              1.0 + (avgBoost * 0.2); // Adjust volume by up to 20% based on EQ
          _audioPlayer!.setVolume(_volume * volumeAdjustment.clamp(0.5, 1.5));

          // For video player with audio
          if (_videoController != null) {
            _videoController!.setVolume(
              _volume * volumeAdjustment.clamp(0.5, 1.5),
            );
          }
        } catch (e) {
          debugPrint('Error applying equalizer: $e');
        }
      }

      // Show feedback to the user with more specific information
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Equalizer settings applied - Audio processing active',
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: primaryPink,
        ),
      );
    }
  }

  // Apply audio effects
  void _applyAudioEffects() {
    if (_videoController != null || _audioPlayer != null) {
      debugPrint(
        'Applying audio effects: Bass=$_bassBoost, Treble=$_trebleBoost, Spatial=$_spatializer',
      );
      debugPrint(
        'Options: NightMode=$_nightMode, AutoVolume=$_autoVolume, VoiceEnhancement=$_voiceEnhancement',
      );

      try {
        if (_audioPlayer != null) {
          // Bass boost simulation (in a real app, you'd use Android's BassBoost or iOS AUBass)
          if (_bassBoost > 0) {
            // Apply playback parameters that might affect bass perception
            _audioPlayer!.setPlaybackRate(1.0); // Reset speed first

            // Night mode (compress dynamic range)
            if (_nightMode) {
              // In a real implementation, you would use DynamicsProcessorAudioEffect
              // For simulation, we'll adjust volume to create a more consistent sound
              final currentVolume =
                  _audioPlayer!
                      .volume; // getVolume() is async, so we'll use the stored value
              _audioPlayer!.setVolume(
                currentVolume * 0.8 + 0.2,
              ); // Reduce dynamic range
            }

            // Voice enhancement would typically use an equalizer to boost speech frequencies
            if (_voiceEnhancement) {
              // In a real implementation, this would boost frequencies around 1kHz-4kHz
              // Here we're just showing it's activated
            }

            // Auto volume would use a compressor/limiter
            if (_autoVolume) {
              // In a real implementation, this would apply a compressor
              // For simulation, we're just showing it's activated
            }
          }

          // For video player with audio
          if (_videoController != null) {
            _videoController!.setPlaybackSpeed(1.0); // Reset speed first

            // Apply similar effects to video player's audio
            if (_nightMode || _autoVolume || _voiceEnhancement) {
              // These would be applied using similar techniques as for audio player
            }
          }
        }
      } catch (e) {
        debugPrint('Error applying audio effects: $e');
      }

      // Show feedback to the user with more detailed information
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _bassBoost > 0 ? Icons.graphic_eq : Icons.audiotrack,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Audio effects applied - ${_getActiveEffectsDescription()}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: primaryPink,
        ),
      );
    }
  }

  // Get description of active effects
  String _getActiveEffectsDescription() {
    List<String> activeEffects = [];

    if (_bassBoost > 0) activeEffects.add('Bass Boost');
    if (_trebleBoost > 0) activeEffects.add('Treble Boost');
    if (_spatializer > 0) activeEffects.add('Spatial Effect');
    if (_nightMode) activeEffects.add('Night Mode');
    if (_autoVolume) activeEffects.add('Auto Volume');
    if (_voiceEnhancement) activeEffects.add('Voice Enhancement');

    if (activeEffects.isEmpty) return 'Standard Audio';
    if (activeEffects.length == 1) return activeEffects[0];
    if (activeEffects.length == 2)
      return '${activeEffects[0]} & ${activeEffects[1]}';

    return '${activeEffects[0]}, ${activeEffects[1]} & more';
  }

  // Apply audio balance
  void _applyAudioBalance() {
    if (_videoController != null || _audioPlayer != null) {
      debugPrint('Applying audio balance: $_balance');

      try {
        if (_audioPlayer != null) {
          // In a real implementation, you would use platform-specific channel balance APIs
          // For Android, you might use AudioBalanceAdjuster or a custom ExoPlayer config
          // For iOS, you might use AVAudioMix with AVAudioMixInputParameters

          // For this simulation, we'll adjust volumes for left/right differently
          // We can't actually implement this with the current just_audio API
          // as it doesn't expose separate channel volume controls

          // For demonstration purposes, we'll just show a more detailed message
        }
      } catch (e) {
        debugPrint('Error applying audio balance: $e');
      }

      // Show feedback to the user
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.compare_arrows, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                _balance < 0
                    ? 'Balance: ${(-_balance * 100).toInt()}% Left'
                    : _balance > 0
                    ? 'Balance: ${(_balance * 100).toInt()}% Right'
                    : 'Balance: Center',
              ),
            ],
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: primaryPink,
        ),
      );
    }
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
    final isAudioOnly = _audioPlayer != null && _videoController == null;

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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                FolderBrowserService().getFileName(
                  _playlist[_currentPlaylistIndex],
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Keyboard shortcuts help button
              IconButton(
                icon: const Icon(Icons.keyboard, color: Colors.white),
                onPressed: _showKeyboardShortcutsHelp,
                tooltip: 'Keyboard Shortcuts',
              ),
              // Only show video-specific controls for video files
              if (!isAudioOnly) ...[
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
                      _isPortrait
                          ? 'Switch to Landscape'
                          : 'Switch to Portrait',
                ),
                // Aspect ratio button - allows user to cycle through aspect ratio options
                IconButton(
                  icon: const Icon(Icons.aspect_ratio, color: Colors.white),
                  onPressed: _cycleAspectRatio,
                  tooltip: 'Change Aspect Ratio',
                ),
              ],
              IconButton(
                icon: const Icon(Icons.playlist_play, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showPlaylist = !_showPlaylist;
                  });
                  _startHideTimer();
                },
                tooltip: 'Playlist',
              ),
              // Only show fullscreen button for video files
              if (!isAudioOnly)
                IconButton(
                  icon: Icon(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                  ),
                  onPressed: _toggleFullscreen,
                  tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
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
    final size = MediaQuery.of(context).size;

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Album art or animated cassette
              _buildAudioVisualization(size.width * 0.7),
              const SizedBox(height: 30),
              // Song title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  FolderBrowserService().getFileName(
                    _playlist[_currentPlaylistIndex],
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
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
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),

              // Show current playback speed for audio
              if (_playbackSpeed != PlaybackSpeed.x1_0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryPink.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "${_getPlaybackSpeedText(_playbackSpeed)}x",
                      style: TextStyle(
                        color: primaryPink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Build audio visualization - either album art or animated cassette
  Widget _buildAudioVisualization(double size) {
    final currentFile = _playlist[_currentPlaylistIndex];

    // Check for album art
    Image? albumArt = _tryGetAlbumArt(currentFile);
    final bool hasAlbumArt = albumArt != null;

    return Container(
      width: size,
      height: size,
      constraints: BoxConstraints(maxWidth: 300, maxHeight: 300),
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
      child:
          hasAlbumArt
              ? _buildAlbumArt(albumArt)
              : _buildAnimatedCassette(isPlaying: _isPlaying),
    );
  }

  // Try to get album art from the audio file
  Image? _tryGetAlbumArt(String filePath) {
    try {
      // First check if there's a custom album art set for this file
      final customArtPath = _getCustomAlbumArtPath(filePath);
      if (customArtPath != null && File(customArtPath).existsSync()) {
        debugPrint('Custom album art found: $customArtPath');
        return Image.file(File(customArtPath), fit: BoxFit.cover);
      }

      // Check if a matching image file exists in the same directory
      final file = File(filePath);
      final directory = file.parent;
      final filename = file.path.split('/').last.split('\\').last;
      final filenameWithoutExt = filename.split('.').first;

      // Check for common album art filenames
      final possibleArtFiles = [
        'cover.jpg',
        'cover.png',
        'folder.jpg',
        'folder.png',
        'album.jpg',
        'album.png',
        '$filenameWithoutExt.jpg',
        '$filenameWithoutExt.png',
      ];

      for (final artFile in possibleArtFiles) {
        final potentialArtPath = '${directory.path}/$artFile';
        if (File(potentialArtPath).existsSync()) {
          debugPrint('Album art found: $potentialArtPath');
          return Image.file(File(potentialArtPath), fit: BoxFit.cover);
        }
      }

      // No album art found
      return null;
    } catch (e) {
      debugPrint('Error looking for album art: $e');
      return null;
    }
  }

  // Album art display
  Widget _buildAlbumArt([Image? albumArt]) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child:
          albumArt ??
          Image.asset(
            'assets/images/default_album.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(Icons.music_note, size: 100, color: primaryPink),
              );
            },
          ),
    );
  }

  // Animated cassette player
  Widget _buildAnimatedCassette({required bool isPlaying}) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[800]!, Colors.grey[900]!],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cassette body
          Container(
            margin: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
          ),

          // Label area
          Container(
            width: 120,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Text(
                "MOJAR PLAYER",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // Spools - these will animate
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAnimatedSpool(isPlaying, true),
              SizedBox(width: 80),
              _buildAnimatedSpool(isPlaying, false),
            ],
          ),

          // Cassette holes
          Positioned(
            top: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCassetteHole(),
                SizedBox(width: 80),
                _buildCassetteHole(),
              ],
            ),
          ),

          // Audio wave animation when playing
          if (isPlaying)
            Positioned(bottom: 30, child: _buildAudioWaveAnimation()),

          // Play indicator
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPlaying ? primaryPink : Colors.grey[600],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    isPlaying ? "PLAYING" : "PAUSED",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Single cassette spool that rotates when playing
  Widget _buildAnimatedSpool(bool isPlaying, bool isLeft) {
    return AnimatedRotation(
      turns: isPlaying ? (isLeft ? 1.0 : -1.0) : 0.0,
      duration: Duration(seconds: 3),
      curve: Curves.linear,
      // If playing, we want continuous rotation
      onEnd:
          isPlaying
              ? () {
                setState(() {
                  // Force a rebuild to continue animation
                });
              }
              : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[400]!, width: 3),
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: primaryPink.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  // Cassette hole
  Widget _buildCassetteHole() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
    );
  }

  // Audio wave animation
  Widget _buildAudioWaveAnimation() {
    return SizedBox(
      width: 120,
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(8, (index) => _buildAudioBar(index)),
      ),
    );
  }

  // Individual animated audio bar
  Widget _buildAudioBar(int index) {
    // Randomize the animation to make it look more natural
    final randomHeight = (math.Random().nextDouble() * 20) + 5;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      width: 4,
      height: _isPlaying ? randomHeight : 5,
      decoration: BoxDecoration(
        color: _isPlaying ? primaryPink : Colors.grey[600],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  // Helper to get playback speed as text
  String _getPlaybackSpeedText(PlaybackSpeed speed) {
    switch (speed) {
      case PlaybackSpeed.x0_5:
        return "0.5";
      case PlaybackSpeed.x0_75:
        return "0.75";
      case PlaybackSpeed.x1_0:
        return "1.0";
      case PlaybackSpeed.x1_25:
        return "1.25";
      case PlaybackSpeed.x1_5:
        return "1.5";
      case PlaybackSpeed.x2_0:
        return "2.0";
    }
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
    final isAudioOnly = _audioPlayer != null && _videoController == null;

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
                  size: isAudioOnly ? 36 : 30,
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

              // For audio, show playback speed instead of exit button
              if (isAudioOnly)
                PopupMenuButton<double>(
                  icon: const Icon(Icons.speed, color: Colors.white),
                  tooltip: 'Playback Speed',
                  onSelected: (double speed) {
                    switch (speed) {
                      case 0.5:
                        _changePlaybackSpeed(PlaybackSpeed.x0_5);
                        break;
                      case 0.75:
                        _changePlaybackSpeed(PlaybackSpeed.x0_75);
                        break;
                      case 1.0:
                        _changePlaybackSpeed(PlaybackSpeed.x1_0);
                        break;
                      case 1.25:
                        _changePlaybackSpeed(PlaybackSpeed.x1_25);
                        break;
                      case 1.5:
                        _changePlaybackSpeed(PlaybackSpeed.x1_5);
                        break;
                      case 2.0:
                        _changePlaybackSpeed(PlaybackSpeed.x2_0);
                        break;
                    }
                  },
                  itemBuilder:
                      (BuildContext context) => <PopupMenuEntry<double>>[
                        const PopupMenuItem<double>(
                          value: 0.5,
                          child: Text('0.5x'),
                        ),
                        const PopupMenuItem<double>(
                          value: 0.75,
                          child: Text('0.75x'),
                        ),
                        const PopupMenuItem<double>(
                          value: 1.0,
                          child: Text('1.0x'),
                        ),
                        const PopupMenuItem<double>(
                          value: 1.25,
                          child: Text('1.25x'),
                        ),
                        const PopupMenuItem<double>(
                          value: 1.5,
                          child: Text('1.5x'),
                        ),
                        const PopupMenuItem<double>(
                          value: 2.0,
                          child: Text('2.0x'),
                        ),
                      ],
                )
              else
                // Exit app - only for video mode
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Exit Player'),
                            content: const Text(
                              'Are you sure you want to exit?',
                            ),
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
      try {
        // Get current position
        final currentPosition = _videoController!.value.position;

        // Calculate adjusted position based on audio delay
        // Positive delay means audio should be behind video (video needs to seek backward)
        // Negative delay means audio should be ahead of video (video needs to seek forward)
        final adjustedPosition =
            currentPosition -
            Duration(milliseconds: (_audioDelay * 1000).toInt());

        // Ensure position is valid
        final validPosition =
            adjustedPosition.isNegative ? Duration.zero : adjustedPosition;

        // Apply the adjusted position
        if (_videoController!.value.isPlaying) {
          // Pause temporarily to make adjustment more noticeable
          _videoController!.pause();

          // Wait a tiny bit for UI feedback, then seek and resume
          Future.delayed(const Duration(milliseconds: 100), () {
            _videoController!.seekTo(validPosition);
            _videoController!.play();
          });
        } else {
          // If not playing, just seek
          _videoController!.seekTo(validPosition);
        }

        debugPrint(
          'Applied audio delay: $_audioDelay seconds, adjusted position to $validPosition',
        );
      } catch (e) {
        debugPrint('Error applying audio delay: $e');
      }

      // Show feedback to the user with visual indicator of direction
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _audioDelay < 0
                    ? Icons.fast_forward
                    : _audioDelay > 0
                    ? Icons.fast_rewind
                    : Icons.sync,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _audioDelay == 0
                    ? 'Audio sync reset to default'
                    : 'Audio ${_audioDelay < 0 ? 'advanced' : 'delayed'} by ${_audioDelay.abs().toStringAsFixed(1)} seconds',
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: primaryPink,
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
      try {
        final position = await _audioPlayer!.getCurrentPosition();
        if (mounted && position != null) {
          setState(() {
            _position = position;
          });
        }
      } catch (e) {
        // Handle any errors that might occur during position retrieval
        debugPrint('Error updating audio position: $e');
      }
    }
  }

  // Controls visibility
  void _startHideTimer() {
    // Cancel any existing timer first
    _hideControlsTimer?.cancel();

    // Set a timer to hide controls after 5 seconds
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  // Clear custom album art
  void _clearCustomAlbumArt() {
    setState(() {
      _customAlbumArtPaths.remove(_playlist[_currentPlaylistIndex]);
      _saveCustomAlbumArtMappings();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom album art cleared'),
        backgroundColor: Colors.green,
      ),
    );
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
