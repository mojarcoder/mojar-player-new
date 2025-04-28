import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart'
    show AudioPlayer, Source, DeviceFileSource, UrlSource, BytesSource;
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/media_controls.dart';
import '../widgets/context_menu.dart';
import '../widgets/audio_effects.dart';
import '../widgets/subtitle_settings.dart';
import '../services/folder_browser_service.dart';
import '../services/platform_service.dart';
import 'about_screen.dart';

// Define colors that match the app theme
const Color primaryPink = Color(0xFFFF4D8D);
const Color lightPink = Color(0xFFFFB6C1);
const Color darkPink = Color(0xFFE91E63);

// Define enums for playback control
enum PlaybackSpeed { x0_5, x0_75, x1_0, x1_25, x1_5, x2_0 }

enum LoopMode { none, one, all }

class PlayerScreen extends StatefulWidget {
  final String videoPath;
  final String? subtitlePath;

  const PlayerScreen({
    super.key,
    required this.videoPath,
    this.subtitlePath,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final Player _player;
  late final VideoController _controller;
  AudioPlayer? _audioPlayer;
  ChewieController? _chewieController;
  late AnimationController _cassetteController;
  late Animation<double> _cassetteAnimation;
  final AudioEffects _audioEffects = AudioEffects();

  // Player state
  bool _isPlaying = false;
  bool _isMuted = false;
  double _volume = 1.0;
  final double _playbackSpeed = 1.0;
  LoopMode _loopMode = LoopMode.none;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _aspectRatio = 16 / 9;
  String? _albumArtPath;
  List<String> _playlist = [];
  int _currentPlaylistIndex = 0;
  double _audioDelay = 0.0;
  List<SubtitleTrack> _subtitleTracks = [];
  int _currentSubtitleTrack = -1;
  final bool _isRepeatMode = false;
  bool _isShuffleMode = false;
  final bool _isFullscreen = false;
  bool _isInitialized = false;
  String? _subtitlePath;
  bool _isLoading = true;
  String? _error;
  double _subtitleDelay = 0.0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _playlist = [widget.videoPath];
    _initializePlayer();
    _startHideControlsTimer();

    // Initialize cassette animation
    _cassetteController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _cassetteAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_cassetteController);

    // Listen for media completion
    _player.stream.completed.listen((completed) {
      if (!_disposed && mounted && completed) {
        _handleMediaCompletion();
      }
    });
  }

  Future<void> _initializePlayer() async {
    try {
      _player = Player();
      _controller = VideoController(_player);
      _audioEffects.setPlayer(_player);

      final media = Media(widget.videoPath);
      await _player.open(
        media,
        play: true,
      );

      if (widget.subtitlePath != null) {
        await _player.setSubtitleTrack(SubtitleTrack.uri(widget.subtitlePath!));
      }

      _player.stream.position.listen((position) {
        if (!_disposed && mounted) {
          setState(() => _position = position);
        }
      });

      _player.stream.duration.listen((duration) {
        if (!_disposed && mounted) {
          setState(() => _duration = duration);
        }
      });

      _player.stream.playing.listen((playing) {
        if (!_disposed && mounted) {
          setState(() => _isPlaying = playing);
        }
      });

      _player.stream.tracks.listen((tracks) {
        if (!_disposed && mounted) {
          setState(() {
            _subtitleTracks = tracks.subtitle;
          });
        }
      });

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (!_disposed && mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_showControls) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  Future<void> _cleanupResources() async {
    if (_disposed) return;
    _disposed = true;

    // Cancel timer first
    _hideControlsTimer?.cancel();

    // Stop animation
    if (_cassetteController.isAnimating) {
      _cassetteController.stop();
    }
    _cassetteController.dispose();

    // Reset audio effects
    _audioEffects.resetEffects();

    // Cleanup player
    try {
      if (_player.state.playing) {
        _player.pause();
      }
      _player.dispose();
    } catch (e) {
      debugPrint('Error during player cleanup: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_disposed) return const SizedBox.shrink();

    return WillPopScope(
      onWillPop: () async {
        if (!_disposed) {
          await _cleanupResources();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: MouseRegion(
            onHover: (_) {
              if (!_disposed && mounted) {
                setState(() => _showControls = true);
                _startHideControlsTimer();
              }
            },
            child: GestureDetector(
              onSecondaryTapUp: (details) {
                if (!_disposed) {
                  _showContextMenu(context, details.globalPosition);
                }
              },
              child: Stack(
                children: [
                  _buildMediaDisplay(),
                  if (_showControls) _buildControls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black54,
          ],
          stops: [0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bottom controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Seek bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white),
              ),
              Expanded(
                child: Slider(
                  value: _position.inMilliseconds
                      .clamp(0, _duration.inMilliseconds)
                      .toDouble(),
                  min: 0,
                  max: _duration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    setState(() {
                      _position = Duration(milliseconds: value.toInt());
                    });
                  },
                  onChangeEnd: (value) {
                    _player.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        // Control buttons
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: _currentPlaylistIndex > 0 ? _playPrevious : null,
              ),
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () => _seekRelative(const Duration(seconds: -10)),
              ),
              FloatingActionButton(
                onPressed: () {
                  setState(() => _isPlaying = !_isPlaying);
                  _isPlaying ? _player.play() : _player.pause();
                },
                backgroundColor: primaryPink,
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () => _seekRelative(const Duration(seconds: 10)),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: _currentPlaylistIndex < _playlist.length - 1
                    ? _playNext
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                onPressed: () async {
                  if (!_disposed) {
                    await _cleanupResources();
                    if (mounted && Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }
                  }
                },
              ),
            ],
          ),
        ),
        // Volume and additional controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white),
                onPressed: () {
                  setState(() => _isMuted = !_isMuted);
                  _player.setVolume(_isMuted ? 0 : _volume * 100);
                },
              ),
              SizedBox(
                width: 100, // Reduced width for volume slider
                child: Slider(
                  value: _volume,
                  onChanged: (value) {
                    setState(() {
                      _volume = value;
                      _isMuted = false;
                    });
                    _player.setVolume(_volume * 100);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.playlist_play, color: Colors.white),
                onPressed: _showPlaylistDialog,
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () => _showContextMenu(context, null),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showContextMenu(BuildContext context, Offset? position) {
    if (position != null) {
      // Show context menu at right-click position
      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx + 1,
          position.dy + 1,
        ),
        items: _buildContextMenuItems(context),
        color: Colors.black.withOpacity(0.85),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      );
    } else {
      // Show context menu as dialog (for the menu button)
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildContextMenuItems(context)
                .map((item) => ListTile(
                      leading: (item.child as Row).children[0] as Icon,
                      title: (item.child as Row).children[2] as Text,
                      onTap: () {
                        Navigator.pop(context);
                        item.onTap?.call();
                      },
                    ))
                .toList(),
          ),
        ),
      );
    }
  }

  List<PopupMenuItem<String>> _buildContextMenuItems(BuildContext context) {
    final isVideo =
        _playlist[_currentPlaylistIndex].toLowerCase().endsWith('.mp4') ||
            _playlist[_currentPlaylistIndex].toLowerCase().endsWith('.mkv') ||
            _playlist[_currentPlaylistIndex].toLowerCase().endsWith('.avi');
    final isAudio =
        _playlist[_currentPlaylistIndex].toLowerCase().endsWith('.mp3') ||
            _playlist[_currentPlaylistIndex].toLowerCase().endsWith('.wav') ||
            _playlist[_currentPlaylistIndex].toLowerCase().endsWith('.flac') ||
            _playlist[_currentPlaylistIndex].toLowerCase().endsWith('.m4a');

    final menuItems = <PopupMenuItem<String>>[
      PopupMenuItem(
        value: 'open',
        onTap: _openMedia,
        child: const Row(
          children: [
            Icon(Icons.folder_open, color: Colors.white),
            SizedBox(width: 8),
            Text('Open Media', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'playlist',
        child: const Row(
          children: [
            Icon(Icons.playlist_play, color: Colors.white),
            SizedBox(width: 8),
            Text('Playlist Settings', style: TextStyle(color: Colors.white)),
          ],
        ),
        onTap: () => _showPlaylistSettings(),
      ),
      if (isVideo) // Only show aspect ratio for video files
        PopupMenuItem(
          value: 'aspect',
          child: const Row(
            children: [
              Icon(Icons.aspect_ratio, color: Colors.white),
              SizedBox(width: 8),
              Text('Aspect Ratio', style: TextStyle(color: Colors.white)),
            ],
          ),
          onTap: () => _showAspectRatioDialog(),
        ),
      PopupMenuItem(
        value: 'audio',
        child: const Row(
          children: [
            Icon(Icons.audiotrack, color: Colors.white),
            SizedBox(width: 8),
            Text('Audio Effects', style: TextStyle(color: Colors.white)),
          ],
        ),
        onTap: () => _showAudioSettings(),
      ),
      PopupMenuItem(
        value: 'info',
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('File Info', style: TextStyle(color: Colors.white)),
          ],
        ),
        onTap: () => _showFileInfoDialog(),
      ),
    ];

    if (isAudio) {
      menuItems.add(
        PopupMenuItem(
          value: 'album_art',
          child: const Row(
            children: [
              Icon(Icons.image, color: Colors.white),
              SizedBox(width: 8),
              Text('Set Album Art', style: TextStyle(color: Colors.white)),
            ],
          ),
          onTap: () => _setAlbumArt(),
        ),
      );

      // Add Clear Album Art option if album art exists
      if (_albumArtPath != null) {
        menuItems.add(
          PopupMenuItem(
            value: 'clear_album_art',
            child: const Row(
              children: [
                Icon(Icons.clear, color: Colors.white),
                SizedBox(width: 8),
                Text('Clear Album Art', style: TextStyle(color: Colors.white)),
              ],
            ),
            onTap: () {
              setState(() {
                _albumArtPath = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Album art cleared'),
                  backgroundColor: primaryPink,
                ),
              );
            },
          ),
        );
      }
    }

    if (isVideo) {
      menuItems.add(
        PopupMenuItem(
          value: 'subtitles',
          child: const Row(
            children: [
              Icon(Icons.subtitles, color: Colors.white),
              SizedBox(width: 8),
              Text('Subtitles', style: TextStyle(color: Colors.white)),
            ],
          ),
          onTap: () => _showSubtitleSettingsDialog(),
        ),
      );
    }

    // Add common options
    menuItems.addAll([
      PopupMenuItem(
        value: 'audio_sync',
        child: const Row(
          children: [
            Icon(Icons.sync, color: Colors.white),
            SizedBox(width: 8),
            Text('Audio Sync', style: TextStyle(color: Colors.white)),
          ],
        ),
        onTap: () => _showAudioSyncDialog(),
      ),
      PopupMenuItem(
        value: 'about',
        child: const Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            SizedBox(width: 8),
            Text('About', style: TextStyle(color: Colors.white)),
          ],
        ),
        onTap: () => _showAboutScreen(),
      ),
    ]);

    return menuItems;
  }

  void _showPlaylistSettings() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Playlist Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Shuffle Playlist'),
                  trailing: Switch(
                    value: _isShuffleMode,
                    onChanged: (value) async {
                      setState(() => _isShuffleMode = value);
                      if (value) {
                        await _shufflePlaylist();
                      } else {
                        await _unshufflePlaylist();
                      }
                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Loop Mode'),
                  trailing: DropdownButton<LoopMode>(
                    value: _loopMode,
                    items: const [
                      DropdownMenuItem(
                          value: LoopMode.none, child: Text('None')),
                      DropdownMenuItem(value: LoopMode.all, child: Text('All')),
                      DropdownMenuItem(value: LoopMode.one, child: Text('One')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _loopMode = value;
                        });
                        if (mounted) {
                          setState(() {});
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showPlaylistDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Manage Playlist'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAspectRatioDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aspect Ratio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('16:9 (Widescreen)'),
              onTap: () {
                setState(() => _aspectRatio = 16 / 9);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('4:3 (Standard)'),
              onTap: () {
                setState(() => _aspectRatio = 4 / 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('21:9 (UltraWide)'),
              onTap: () {
                setState(() => _aspectRatio = 21 / 9);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('1:1 (Square)'),
              onTap: () {
                setState(() => _aspectRatio = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('2.39:1 (Cinema)'),
              onTap: () {
                setState(() => _aspectRatio = 2.39);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaDisplay() {
    if (_playlist.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_remove, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'No media in playlist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add media files to start playing',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final isAudio =
        _playlist[_currentPlaylistIndex].toLowerCase().endsWith('.mp3') ||
        _playlist[_currentPlaylistIndex].toLowerCase().endsWith('.wav') ||
        _playlist[_currentPlaylistIndex].toLowerCase().endsWith('.flac') ||
        _playlist[_currentPlaylistIndex].toLowerCase().endsWith('.m4a');

    if (isAudio) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_albumArtPath != null)
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(File(_albumArtPath!)),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              AnimatedBuilder(
                animation: _cassetteAnimation,
                builder: (context, child) {
                  return Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: primaryPink.withOpacity(0.5), width: 2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Cassette body
                        Container(
                          width: 250,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                        ),
                        // Rotating reels
                        Positioned(
                          left: 70,
                          child: Transform.rotate(
                            angle: _cassetteAnimation.value,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: primaryPink, width: 2),
                              ),
                              child: Center(
                                child: Container(
                                  width: 15,
                                  height: 15,
                                  decoration: const BoxDecoration(
                                    color: primaryPink,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Second reel
                        Positioned(
                          right: 70,
                          child: Transform.rotate(
                            angle:
                                -_cassetteAnimation.value, // Opposite rotation
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: primaryPink, width: 2),
                              ),
                              child: Center(
                                child: Container(
                                  width: 15,
                                  height: 15,
                                  decoration: const BoxDecoration(
                                    color: primaryPink,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Label area
                        Positioned(
                          bottom: 85,
                          child: Container(
                            width: 180,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.music_note,
                                color: primaryPink,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
            Text(
              _playlist[_currentPlaylistIndex].split('/').last,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            final targetHeight = screenWidth / _aspectRatio;

            return Container(
              width: screenWidth,
              height: targetHeight > screenHeight ? screenHeight : targetHeight,
              child: Video(controller: _controller),
            );
          },
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  void _playPrevious() async {
    if (_currentPlaylistIndex > 0) {
      setState(() => _currentPlaylistIndex--);
      await _initializeNewMedia(_playlist[_currentPlaylistIndex]);
    }
  }

  void _playNext() async {
    if (_currentPlaylistIndex < _playlist.length - 1) {
      setState(() => _currentPlaylistIndex++);
      await _initializeNewMedia(_playlist[_currentPlaylistIndex]);
    }
  }

  void _seekRelative(Duration duration) {
    final newPosition = _position + duration;
    if (newPosition < Duration.zero) {
      _player.seek(Duration.zero);
    } else if (newPosition > _duration) {
      _player.seek(_duration);
    } else {
      _player.seek(newPosition);
    }
  }

  void _showAboutScreen() async {
    if (_disposed) return;

    // Store current playing state
    final wasPlaying = _player.state.playing;

    // Pause playback before navigation
    if (wasPlaying) {
      _player.pause();
    }

    if (!mounted || _disposed) return;

    try {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (context) => const AboutScreen()),
      );

      // Only resume if we actually returned from the About screen
      if (result == true && mounted && !_disposed && wasPlaying) {
        _player.play();
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
    }
  }

  void _showPlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Playlist'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.pop(context);
                    _openMedia().then((_) {
                      if (mounted) {
                        setState(() {});
                      }
                    });
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _playlist.length,
                itemBuilder: (context, index) {
                  final filename = _playlist[index].split('/').last;
                  return ListTile(
                    leading: Icon(
                      index == _currentPlaylistIndex
                          ? Icons.play_arrow
                          : Icons.music_note,
                      color:
                          index == _currentPlaylistIndex ? primaryPink : null,
                    ),
                    title: Text(
                      filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            index == _currentPlaylistIndex ? primaryPink : null,
                        fontWeight: index == _currentPlaylistIndex
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() {
                          if (index == _currentPlaylistIndex) {
                            // If removing current playing item
                            if (_playlist.length > 1) {
                              // If there are other items in playlist
                              _playlist.removeAt(index);
                              if (index == _playlist.length) {
                                // If it was the last item
                                _currentPlaylistIndex--;
                              }
                              _initializeNewMedia(_playlist[_currentPlaylistIndex])
                                  .then((_) {
                                if (mounted) {
                                  setState(() {});
                                }
                              });
                            } else {
                              // If it's the only item
                              _playlist.clear();
                              _currentPlaylistIndex = 0;
                              _player.pause();
                              // Close the dialog and return to home screen
                              Navigator.of(context).pop(); // Close dialog
                              Navigator.of(context).pop(); // Return to home screen
                            }
                          } else {
                            // If removing another item
                            _playlist.removeAt(index);
                            if (index < _currentPlaylistIndex) {
                              _currentPlaylistIndex--;
                            }
                          }
                        });
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                    onTap: () {
                      if (index != _currentPlaylistIndex) {
                        setState(() => _currentPlaylistIndex = index);
                        _initializeNewMedia(_playlist[index]).then((_) {
                          if (mounted) {
                            setState(() {});
                          }
                        });
                      }
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAudioSettings() {
    showDialog(
      context: context,
      builder: (context) => _audioEffects.buildAudioEffectsDialog(context),
    );
  }

  void _showFileInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${_playlist[_currentPlaylistIndex].split('/').last}'),
            const SizedBox(height: 8),
            Text('Duration: ${_formatDuration(_duration)}'),
            const SizedBox(height: 8),
            Text('Current Position: ${_formatDuration(_position)}'),
            const SizedBox(height: 8),
            Text('Aspect Ratio: ${_aspectRatio.toStringAsFixed(2)}'),
          ],
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

  Future<void> _shufflePlaylist() async {
    if (_playlist.length > 1) {
      final currentItem = _playlist[_currentPlaylistIndex];
      final shuffledList = List<String>.from(_playlist)
        ..removeAt(_currentPlaylistIndex);
      shuffledList.shuffle();
      setState(() {
        _playlist = [currentItem, ...shuffledList];
        _currentPlaylistIndex = 0;
      });
      // Update player playlist by opening the new current item
      await _player.open(Media(_playlist[_currentPlaylistIndex]));
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _unshufflePlaylist() async {
    // Reset to original order
    setState(() {
      _isShuffleMode = false;
    });
    // Update player by opening the current item
    await _player.open(Media(_playlist[_currentPlaylistIndex]));
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openMedia() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Media Files',
        extensions: ['mp4', 'mkv', 'avi', 'mp3', 'wav', 'flac', 'm4a'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        // Add to playlist if not already present
        if (!_playlist.contains(file.path)) {
          setState(() {
            _playlist.add(file.path);
            _currentPlaylistIndex = _playlist.length - 1;
          });
        } else {
          // If already in playlist, just switch to it
          setState(() {
            _currentPlaylistIndex = _playlist.indexOf(file.path);
          });
        }

        // Initialize player with new media
        await _initializeNewMedia(file.path);
      }
    } catch (e) {
      debugPrint('Error opening media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening media: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initializeNewMedia(String path) async {
    try {
      if (_player.state.playing) {
        await _player.pause();
      }

      await _player.open(Media(path), play: true);
      setState(() {
        _isPlaying = true;
        _position = Duration.zero;
        _isInitialized = true;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Error initializing new media: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _setAlbumArt() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Image Files',
        extensions: ['jpg', 'jpeg', 'png'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        setState(() {
          _albumArtPath = file.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Album art set successfully'),
            backgroundColor: primaryPink,
          ),
        );
      }
    } catch (e) {
      print('Error setting album art: $e');
    }
  }

  void _showSubtitleSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => SubtitleSettings(
        player: _player,
        subtitles: _subtitleTracks,
        currentSubtitleIndex: _currentSubtitleTrack,
        subtitleDelay: _subtitleDelay,
        onSubtitleChanged: (index) async {
          setState(() => _currentSubtitleTrack = index);
          if (index == -1) {
            await _player.setSubtitleTrack(SubtitleTrack.no());
          } else {
            await _player.setSubtitleTrack(_subtitleTracks[index]);
          }
        },
        onSubtitleAdded: (path) async {
          try {
            await _player.setSubtitleTrack(SubtitleTrack.uri(path));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subtitle file loaded successfully'),
                  backgroundColor: primaryPink,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error loading subtitle file: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        onSubtitleDelayChanged: (delay) async {
          setState(() => _subtitleDelay = delay);
          if (_player.platform is NativePlayer) {
            final nativePlayer = _player.platform as NativePlayer;
            await nativePlayer.setProperty(
              'sub-delay',
              (delay * 1000).round().toString(),
            );
          }
        },
      ),
    );
  }

  void _showAudioSyncDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Sync'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current delay: ${_audioDelay.toStringAsFixed(1)} seconds'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    setState(() {
                      _audioDelay -= 0.1;
                      _applyAudioDelay();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: () {
                    setState(() {
                      _audioDelay = 0.0;
                      _applyAudioDelay();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _audioDelay += 0.1;
                      _applyAudioDelay();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyAudioDelay() {
    try {
      // Get current position
      final currentPosition = _player.state.position;

      // Calculate adjusted position based on audio delay
      final adjustedPosition = currentPosition +
          Duration(milliseconds: (_audioDelay * 1000).toInt());

      // Ensure the position is within valid bounds
      final validPosition = adjustedPosition < Duration.zero
          ? Duration.zero
          : adjustedPosition > _duration
              ? _duration
              : adjustedPosition;

      // Apply the adjusted position
      if (_player.state.playing) {
        // Pause temporarily to make adjustment more noticeable
        _player.pause();

        // Wait a tiny bit for UI feedback, then seek and resume
        Future.delayed(const Duration(milliseconds: 100), () {
          _player.seek(validPosition);
          _player.play();
        });
      } else {
        // If not playing, just seek
        _player.seek(validPosition);
      }

      debugPrint(
        'Applied audio delay: $_audioDelay seconds, adjusted position to $validPosition',
      );
    } catch (e) {
      debugPrint('Error applying audio delay: $e');
    }

    // Show feedback to the user
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
        backgroundColor: primaryPink,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleMediaCompletion() {
    switch (_loopMode) {
      case LoopMode.one:
        // Loop current track
        _player.seek(Duration.zero);
        _player.play();
        break;
      case LoopMode.all:
        // Play next track or loop to first if at end
        if (_currentPlaylistIndex < _playlist.length - 1) {
          _playNext();
        } else {
          setState(() => _currentPlaylistIndex = 0);
          _initializeNewMedia(_playlist[0]);
        }
        break;
      case LoopMode.none:
        // Stop playback
        _player.pause();
        break;
    }
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }
}
