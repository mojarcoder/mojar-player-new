import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:async';

class PlayerProvider {
  final VideoPlayerController? videoController;
  final AudioPlayer? audioPlayer;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isPlaying = false;
  bool isLooping = false;
  double aspectRatio = 16 / 9;
  double volume = 1.0;
  double playbackSpeed = 1.0;
  bool isMuted = false;

  PlayerProvider({this.videoController, this.audioPlayer});

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }
}

class MediaControls extends StatefulWidget {
  final PlayerProvider player;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onSkipNext;
  final VoidCallback onSkipPrevious;
  final VoidCallback onSkipForward; // 10 seconds forward
  final VoidCallback onSkipBackward; // 10 seconds backward
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onPlaybackSpeedChanged;
  final VoidCallback onToggleLoop;
  final ValueChanged<double> onAspectRatioChanged;
  final VoidCallback onTogglePlaylist;
  final VoidCallback onToggleTheme;
  final Future<String?> Function() onTakeSnapshot;
  final VoidCallback onMediaInfo;
  final VoidCallback onSubtitleSettings;
  final VoidCallback onAudioSync;
  final VoidCallback onAbout;
  final bool isDarkMode;

  const MediaControls({
    super.key,
    required this.player,
    required this.onPlayPause,
    required this.onStop,
    required this.onSeek,
    required this.onSkipNext,
    required this.onSkipPrevious,
    required this.onSkipForward,
    required this.onSkipBackward,
    required this.onVolumeChanged,
    required this.onToggleMute,
    required this.onPlaybackSpeedChanged,
    required this.onToggleLoop,
    required this.onAspectRatioChanged,
    required this.onTogglePlaylist,
    required this.onToggleTheme,
    required this.onTakeSnapshot,
    required this.onMediaInfo,
    required this.onSubtitleSettings,
    required this.onAudioSync,
    required this.onAbout,
    required this.isDarkMode,
  });

  @override
  State<MediaControls> createState() => _MediaControlsState();
}

class _MediaControlsState extends State<MediaControls> {
  bool _showVolumeSlider = false;
  bool _showSpeedSelector = false;
  bool _showAspectRatioSelector = false;
  Timer? _hideControlsTimer;
  bool _showControls = true;

  final List<double> _aspectRatios = [
    16 / 9, // Default widescreen
    4 / 3, // Standard
    21 / 9, // UltraWide
    1, // Square
    2.39 / 1, // Cinema Scope
  ];

  final List<double> _playbackSpeeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
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

  void _showContextMenu(BuildContext context, Offset position) {
    final isDark = widget.isDarkMode;
    final primaryColor = Colors.pink;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.of(context).size.width - position.dx,
        MediaQuery.of(context).size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'mediaInfo',
          child: Row(
            children: [
              Icon(Icons.info_outline, color: primaryColor),
              const SizedBox(width: 10),
              Text('Media Info', style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'subtitle',
          child: Row(
            children: [
              Icon(Icons.subtitles, color: primaryColor),
              const SizedBox(width: 10),
              Text('Subtitle Settings', style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'audioSync',
          child: Row(
            children: [
              Icon(Icons.sync, color: primaryColor),
              const SizedBox(width: 10),
              Text('Audio Synchronization', style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'snapshot',
          child: Row(
            children: [
              Icon(Icons.camera_alt, color: primaryColor),
              const SizedBox(width: 10),
              Text('Take Snapshot', style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'about',
          child: Row(
            children: [
              Icon(Icons.help_outline, color: primaryColor),
              const SizedBox(width: 10),
              Text('About Mojar Player', style: TextStyle(color: textColor)),
            ],
          ),
        ),
      ],
      color: backgroundColor,
      elevation: 8.0,
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'mediaInfo':
          widget.onMediaInfo();
          break;
        case 'subtitle':
          widget.onSubtitleSettings();
          break;
        case 'audioSync':
          widget.onAudioSync();
          break;
        case 'snapshot':
          _handleSnapshot();
          break;
        case 'about':
          widget.onAbout();
          break;
      }
    });
  }

  Future<void> _handleSnapshot() async {
    final snapshotPath = await widget.onTakeSnapshot();
    if (snapshotPath != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Snapshot saved to: $snapshotPath'),
          backgroundColor: Colors.pink,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final theme = Theme.of(context);
    final primaryColor = Colors.pink;
    final secondaryColor = isDark ? Colors.pink[200] : Colors.pink[300];
    final backgroundColor =
        isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.7);
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: _handleUserInteraction,
      onDoubleTap: widget.onPlayPause,
      onLongPress: () {
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset position = box.localToGlobal(Offset.zero);
        _showContextMenu(context, position);
      },
      onSecondaryTap: () {
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset position = box.localToGlobal(Offset.zero);
        _showContextMenu(context, position);
      },
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Aspect Ratio
                          IconButton(
                            icon: const Icon(
                              Icons.aspect_ratio,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _showAspectRatioSelector =
                                    !_showAspectRatioSelector;
                                _showVolumeSlider = false;
                                _showSpeedSelector = false;
                              });
                              _startHideTimer();
                            },
                            tooltip: 'Aspect Ratio',
                          ),

                          // Playback Speed
                          IconButton(
                            icon: const Icon(Icons.speed, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _showSpeedSelector = !_showSpeedSelector;
                                _showVolumeSlider = false;
                                _showAspectRatioSelector = false;
                              });
                              _startHideTimer();
                            },
                            tooltip: 'Playback Speed',
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          // Theme Toggle
                          IconButton(
                            icon: Icon(
                              widget.isDarkMode
                                  ? Icons.light_mode
                                  : Icons.dark_mode,
                              color: Colors.white,
                            ),
                            onPressed: widget.onToggleTheme,
                            tooltip:
                                widget.isDarkMode ? 'Light Mode' : 'Dark Mode',
                          ),

                          // Playlist
                          IconButton(
                            icon: const Icon(
                              Icons.playlist_play,
                              color: Colors.white,
                            ),
                            onPressed: widget.onTogglePlaylist,
                            tooltip: 'Playlist',
                          ),

                          // Screenshot
                          IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                            ),
                            onPressed: _handleSnapshot,
                            tooltip: 'Take Snapshot',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Aspect Ratio Selector Popup
              if (_showAspectRatioSelector)
                Positioned(
                  top: 60,
                  left: 10,
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5.0,
                          spreadRadius: 1.0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            'Aspect Ratio',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        ..._aspectRatios.map((ratio) {
                          final isSelected = widget.player.aspectRatio == ratio;
                          String ratioText;
                          if (ratio == 16 / 9) {
                            ratioText = '16:9';
                          } else if (ratio == 4 / 3)
                            ratioText = '4:3';
                          else if (ratio == 21 / 9)
                            ratioText = '21:9';
                          else if (ratio == 1)
                            ratioText = '1:1';
                          else if (ratio == 2.39 / 1)
                            ratioText = '2.39:1';
                          else
                            ratioText = ratio.toString();

                          return InkWell(
                            onTap: () {
                              widget.onAspectRatioChanged(ratio);
                              setState(() {
                                _showAspectRatioSelector = false;
                              });
                              _startHideTimer();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? primaryColor.withOpacity(0.2)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ratioText,
                                    style: TextStyle(
                                      color:
                                          isSelected ? primaryColor : textColor,
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      size: 18,
                                      color: primaryColor,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              // Playback Speed Selector Popup
              if (_showSpeedSelector)
                Positioned(
                  top: 60,
                  left: 60,
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5.0,
                          spreadRadius: 1.0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            'Playback Speed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        ..._playbackSpeeds.map((speed) {
                          final isSelected =
                              widget.player.playbackSpeed == speed;
                          return InkWell(
                            onTap: () {
                              widget.onPlaybackSpeedChanged(speed);
                              setState(() {
                                _showSpeedSelector = false;
                              });
                              _startHideTimer();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? primaryColor.withOpacity(0.2)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${speed}x',
                                    style: TextStyle(
                                      color:
                                          isSelected ? primaryColor : textColor,
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      size: 18,
                                      color: primaryColor,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              // Main Controls
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Progress Bar
                    _buildProgressBar(widget.player),

                    // Control Buttons
                    Container(
                      padding: const EdgeInsets.only(
                        bottom: 40.0,
                        top: 8.0,
                        left: 16.0,
                        right: 16.0,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Volume Controls
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  widget.player.isMuted
                                      ? Icons.volume_off
                                      : (widget.player.volume > 0.5
                                          ? Icons.volume_up
                                          : Icons.volume_down),
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  widget.onToggleMute();
                                  setState(() {
                                    _showVolumeSlider = !_showVolumeSlider;
                                    _showSpeedSelector = false;
                                    _showAspectRatioSelector = false;
                                  });
                                  _startHideTimer();
                                },
                                tooltip:
                                    widget.player.isMuted ? 'Unmute' : 'Mute',
                              ),
                              if (_showVolumeSlider)
                                SizedBox(
                                  width: 120,
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 4.0,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8.0,
                                      ),
                                      activeTrackColor: primaryColor,
                                      inactiveTrackColor: Colors.grey[600],
                                      thumbColor: Colors.white,
                                    ),
                                    child: Slider(
                                      value: widget.player.volume,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (value) {
                                        widget.onVolumeChanged(value);
                                        _startHideTimer();
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Center Controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Previous Button
                              IconButton(
                                icon: const Icon(
                                  Icons.skip_previous,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: widget.onSkipPrevious,
                                tooltip: 'Previous',
                              ),
                              const SizedBox(width: 8),

                              // Skip Backward
                              IconButton(
                                icon: const Icon(
                                  Icons.replay_10,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: widget.onSkipBackward,
                                tooltip: '10 seconds backward',
                              ),
                              const SizedBox(width: 8),

                              // Play/Pause Button
                              Container(
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  iconSize: 36,
                                  icon: Icon(
                                    widget.player.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                  onPressed: widget.onPlayPause,
                                  tooltip:
                                      widget.player.isPlaying
                                          ? 'Pause'
                                          : 'Play',
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Skip Forward
                              IconButton(
                                icon: const Icon(
                                  Icons.forward_10,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: widget.onSkipForward,
                                tooltip: '10 seconds forward',
                              ),
                              const SizedBox(width: 8),

                              // Next Button
                              IconButton(
                                icon: const Icon(
                                  Icons.skip_next,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: widget.onSkipNext,
                                tooltip: 'Next',
                              ),
                            ],
                          ),

                          // Right Controls
                          Row(
                            children: [
                              // Stop Button
                              IconButton(
                                icon: const Icon(
                                  Icons.stop,
                                  color: Colors.white,
                                ),
                                onPressed: widget.onStop,
                                tooltip: 'Stop',
                              ),

                              // Loop Button
                              IconButton(
                                icon: Icon(
                                  Icons.repeat,
                                  color:
                                      widget.player.isLooping
                                          ? primaryColor
                                          : Colors.white,
                                ),
                                onPressed: widget.onToggleLoop,
                                tooltip:
                                    widget.player.isLooping
                                        ? 'Turn off loop'
                                        : 'Turn on loop',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(PlayerProvider player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
              activeTrackColor: Colors.pink,
              inactiveTrackColor: Colors.grey[600],
              thumbColor: Colors.white,
              overlayColor: Colors.pink.withOpacity(0.3),
            ),
            child: Slider(
              value: player.position.inSeconds.toDouble(),
              min: 0,
              max:
                  player.duration.inSeconds.toDouble() > 0
                      ? player.duration.inSeconds.toDouble()
                      : 1.0,
              onChanged: (value) {
                widget.onSeek(Duration(seconds: value.toInt()));
                _startHideTimer();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  player.formatDuration(player.position),
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  player.formatDuration(player.duration),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
