import 'package:flutter/material.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../widgets/context_menu.dart';

enum MediaType { audio, video }

enum LoopMode { none, all, one }

enum PlaybackSpeed { x0_5, x0_75, x1_0, x1_25, x1_5, x2_0 }

class MediaControls extends StatefulWidget {
  final MediaType mediaType;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isFullscreen;
  final double volume;
  final bool isMuted;
  final LoopMode loopMode;
  final PlaybackSpeed playbackSpeed;
  final Widget? thumbnail;
  final String title;
  final String? artist;

  // Callbacks
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onToggleFullscreen;
  final ValueChanged<double>? onVolumeChanged;
  final VoidCallback? onToggleMute;
  final ValueChanged<LoopMode>? onLoopModeChanged;
  final ValueChanged<PlaybackSpeed>? onPlaybackSpeedChanged;
  final VoidCallback? onShowPlaylist;

  const MediaControls({
    super.key,
    required this.mediaType,
    required this.position,
    required this.duration,
    this.isPlaying = false,
    this.isFullscreen = false,
    this.volume = 1.0,
    this.isMuted = false,
    this.loopMode = LoopMode.none,
    this.playbackSpeed = PlaybackSpeed.x1_0,
    this.thumbnail,
    required this.title,
    this.artist,
    this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.onSeek,
    this.onToggleFullscreen,
    this.onVolumeChanged,
    this.onToggleMute,
    this.onLoopModeChanged,
    this.onPlaybackSpeedChanged,
    this.onShowPlaylist,
  });

  @override
  State<MediaControls> createState() => _MediaControlsState();
}

class _MediaControlsState extends State<MediaControls> {
  // Global key for getting context
  final GlobalKey _contextKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.mediaType == MediaType.video;
    final isPink =
        Theme.of(context).colorScheme.primary == const Color(0xFFFF4D8D);

    // Define theme colors
    final Color primaryColor =
        isPink
            ? const Color(0xFFFF4D8D)
            : Theme.of(context).colorScheme.primary;
    final Color iconColor = isVideo ? Colors.white : primaryColor;
    final Color backgroundColor =
        isVideo
            ? Colors.black.withOpacity(0.7)
            : Theme.of(context).scaffoldBackgroundColor;
    final Color progressBarColor = isVideo ? Colors.white : primaryColor;

    return Container(
      key: _contextKey,
      color: backgroundColor,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isVideo ? 8 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isVideo) _buildHeader(context, iconColor, backgroundColor),
          const SizedBox(height: 8),

          // Progress bar
          ProgressBar(
            progress: widget.position,
            total: widget.duration,
            progressBarColor: progressBarColor,
            baseBarColor: progressBarColor.withOpacity(0.24),
            bufferedBarColor: progressBarColor.withOpacity(0.5),
            thumbColor: progressBarColor,
            barHeight: 3.0,
            thumbRadius: 6.0,
            timeLabelLocation:
                isVideo ? TimeLabelLocation.sides : TimeLabelLocation.below,
            timeLabelTextStyle: TextStyle(
              color:
                  isVideo
                      ? Colors.white
                      : Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 12,
            ),
            onSeek: widget.onSeek,
          ),

          const SizedBox(height: 8),

          // Main controls
          _buildMainControls(context, iconColor, backgroundColor),

          // Additional controls
          if (!isVideo) _buildAdditionalControls(context, iconColor),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color iconColor,
    Color backgroundColor,
  ) {
    return Row(
      children: [
        if (widget.thumbnail != null) ...[
          SizedBox(
            width: 50,
            height: 50,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: widget.thumbnail,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: GestureDetector(
            onTap: () => _showMediaInfoMenu(context),
            onLongPress: () => _showMediaInfoMenu(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.artist != null)
                  Text(
                    widget.artist!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainControls(
    BuildContext context,
    Color iconColor,
    Color backgroundColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Loop mode
        IconButton(
          icon: Icon(
            _getLoopModeIcon(),
            color:
                widget.loopMode == LoopMode.none
                    ? iconColor.withOpacity(0.6)
                    : iconColor,
          ),
          onPressed: () => _showLoopModeMenu(context),
          tooltip: 'Loop mode',
        ),

        // Skip backward 10s
        IconButton(
          icon: Icon(Icons.replay_10, color: iconColor),
          onPressed: () {
            if (widget.onSeek != null && widget.position.inSeconds > 10) {
              widget.onSeek!(widget.position - const Duration(seconds: 10));
            } else if (widget.onSeek != null) {
              widget.onSeek!(Duration.zero);
            }
          },
          tooltip: '10s Backward',
        ),

        // Previous
        IconButton(
          icon: Icon(Icons.skip_previous, color: iconColor),
          onPressed: widget.onPrevious,
          tooltip: 'Previous',
        ),

        // Play/Pause
        GestureDetector(
          onTap: widget.onPlayPause,
          onLongPress: () => _showPlaybackMenu(context),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Icon(
              widget.isPlaying ? Icons.pause : Icons.play_arrow,
              color: backgroundColor,
              size: 32,
            ),
          ),
        ),

        // Next
        IconButton(
          icon: Icon(Icons.skip_next, color: iconColor),
          onPressed: widget.onNext,
          tooltip: 'Next',
        ),

        // Skip forward 10s
        IconButton(
          icon: Icon(Icons.forward_10, color: iconColor),
          onPressed: () {
            if (widget.onSeek != null) {
              widget.onSeek!(widget.position + const Duration(seconds: 10));
            }
          },
          tooltip: '10s Forward',
        ),

        // Speed control
        IconButton(
          icon: Icon(
            Icons.speed,
            color:
                widget.playbackSpeed != PlaybackSpeed.x1_0
                    ? iconColor
                    : iconColor.withOpacity(0.6),
          ),
          onPressed: () => _showPlaybackSpeedMenu(context),
          tooltip: 'Playback speed',
        ),
      ],
    );
  }

  Widget _buildAdditionalControls(BuildContext context, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Volume controls
          Row(
            children: [
              // Mute button
              IconButton(
                icon: Icon(
                  widget.isMuted
                      ? Icons.volume_off
                      : widget.volume < 0.1
                      ? Icons.volume_mute
                      : widget.volume < 0.5
                      ? Icons.volume_down
                      : Icons.volume_up,
                  color: iconColor,
                ),
                onPressed: widget.onToggleMute,
                tooltip: widget.isMuted ? 'Unmute' : 'Mute',
              ),
              // Volume slider with context menu
              GestureDetector(
                onSecondaryTapDown: (details) {
                  _showVolumeMenu(context, details.globalPosition);
                },
                child: SizedBox(
                  width: 80,
                  child: Slider(
                    value: widget.isMuted ? 0 : widget.volume,
                    onChanged: widget.onVolumeChanged,
                    activeColor: iconColor,
                    inactiveColor: iconColor.withOpacity(0.2),
                  ),
                ),
              ),
            ],
          ),

          // Additional buttons on the right
          Row(
            children: [
              // Playlist button
              IconButton(
                icon: Icon(Icons.playlist_play, color: iconColor),
                onPressed: widget.onShowPlaylist,
                tooltip: 'Playlist',
              ),

              // Fullscreen button
              IconButton(
                icon: Icon(
                  widget.isFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  color: iconColor,
                ),
                onPressed: widget.onToggleFullscreen,
                tooltip: widget.isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Context menu for track info
  void _showMediaInfoMenu(BuildContext context, {Offset? position}) {
    // Use the center of the screen if no position is provided
    final Offset menuPosition =
        position ??
        Offset(
          MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height / 2,
        );

    showContextMenu(
      context: context,
      position: menuPosition,
      menuItems: [
        ContextMenuItem(
          title: widget.title,
          icon: Icons.music_note,
          isBold: true,
        ),
        if (widget.artist != null)
          ContextMenuItem(
            title: 'Artist: ${widget.artist}',
            icon: Icons.person,
          ),
        ContextMenuItem(
          title: 'Duration: ${_formatDuration(widget.duration)}',
          icon: Icons.timer,
        ),
        ContextMenuItem(
          title:
              widget.mediaType == MediaType.audio
                  ? 'Audio Track'
                  : 'Video Track',
          icon:
              widget.mediaType == MediaType.audio
                  ? Icons.audiotrack
                  : Icons.videocam,
          addDivider: true,
        ),
        ContextMenuItem(
          title: 'Add to Playlist',
          icon: Icons.playlist_add,
          onPressed: () {
            // Add to playlist logic here
          },
        ),
        ContextMenuItem(
          title: 'Share',
          icon: Icons.share,
          onPressed: () {
            // Share logic here
          },
        ),
      ],
    );
  }

  // Context menu for playback
  void _showPlaybackMenu(BuildContext context, {Offset? position}) {
    // Use the center of the screen if no position is provided
    final Offset menuPosition =
        position ??
        Offset(
          MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height / 2,
        );

    showContextMenu(
      context: context,
      position: menuPosition,
      menuItems: [
        ContextMenuItem(
          title: widget.isPlaying ? 'Pause' : 'Play',
          icon: widget.isPlaying ? Icons.pause : Icons.play_arrow,
          onPressed: widget.onPlayPause,
        ),
        ContextMenuItem(
          title: 'Previous Track',
          icon: Icons.skip_previous,
          onPressed: widget.onPrevious,
        ),
        ContextMenuItem(
          title: 'Next Track',
          icon: Icons.skip_next,
          onPressed: widget.onNext,
          addDivider: true,
        ),
        ContextMenuItem(
          title: 'Seek Forward 10s',
          icon: Icons.forward_10,
          onPressed: () {
            if (widget.onSeek != null) {
              widget.onSeek!(widget.position + const Duration(seconds: 10));
            }
          },
        ),
        ContextMenuItem(
          title: 'Seek Backward 10s',
          icon: Icons.replay_10,
          onPressed: () {
            if (widget.onSeek != null && widget.position.inSeconds > 10) {
              widget.onSeek!(widget.position - const Duration(seconds: 10));
            } else if (widget.onSeek != null) {
              widget.onSeek!(Duration.zero);
            }
          },
        ),
      ],
    );
  }

  // Loop mode menu
  void _showLoopModeMenu(BuildContext context) {
    if (widget.onLoopModeChanged == null) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset position = renderBox.localToGlobal(Offset.zero);

    showContextMenu(
      context: context,
      position: position,
      menuItems: [
        ContextMenuItem(
          title: 'No Loop',
          icon: Icons.repeat,
          iconColor: Colors.grey,
          onPressed: () => widget.onLoopModeChanged!(LoopMode.none),
          trailingIcon: widget.loopMode == LoopMode.none ? Icons.check : null,
        ),
        ContextMenuItem(
          title: 'Loop All',
          icon: Icons.repeat,
          onPressed: () => widget.onLoopModeChanged!(LoopMode.all),
          trailingIcon: widget.loopMode == LoopMode.all ? Icons.check : null,
        ),
        ContextMenuItem(
          title: 'Loop One',
          icon: Icons.repeat_one,
          onPressed: () => widget.onLoopModeChanged!(LoopMode.one),
          trailingIcon: widget.loopMode == LoopMode.one ? Icons.check : null,
        ),
      ],
    );
  }

  // Speed menu
  void _showPlaybackSpeedMenu(BuildContext context) {
    if (widget.onPlaybackSpeedChanged == null) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset position = renderBox.localToGlobal(Offset.zero);

    showContextMenu(
      context: context,
      position: position,
      menuItems: [
        ContextMenuItem(
          title: '0.5x',
          onPressed: () => widget.onPlaybackSpeedChanged!(PlaybackSpeed.x0_5),
          trailingIcon:
              widget.playbackSpeed == PlaybackSpeed.x0_5 ? Icons.check : null,
        ),
        ContextMenuItem(
          title: '0.75x',
          onPressed: () => widget.onPlaybackSpeedChanged!(PlaybackSpeed.x0_75),
          trailingIcon:
              widget.playbackSpeed == PlaybackSpeed.x0_75 ? Icons.check : null,
        ),
        ContextMenuItem(
          title: '1.0x (Normal)',
          onPressed: () => widget.onPlaybackSpeedChanged!(PlaybackSpeed.x1_0),
          trailingIcon:
              widget.playbackSpeed == PlaybackSpeed.x1_0 ? Icons.check : null,
        ),
        ContextMenuItem(
          title: '1.25x',
          onPressed: () => widget.onPlaybackSpeedChanged!(PlaybackSpeed.x1_25),
          trailingIcon:
              widget.playbackSpeed == PlaybackSpeed.x1_25 ? Icons.check : null,
        ),
        ContextMenuItem(
          title: '1.5x',
          onPressed: () => widget.onPlaybackSpeedChanged!(PlaybackSpeed.x1_5),
          trailingIcon:
              widget.playbackSpeed == PlaybackSpeed.x1_5 ? Icons.check : null,
        ),
        ContextMenuItem(
          title: '2.0x',
          onPressed: () => widget.onPlaybackSpeedChanged!(PlaybackSpeed.x2_0),
          trailingIcon:
              widget.playbackSpeed == PlaybackSpeed.x2_0 ? Icons.check : null,
        ),
      ],
    );
  }

  // Volume menu
  void _showVolumeMenu(BuildContext context, Offset position) {
    showContextMenu(
      context: context,
      position: position,
      menuItems: [
        ContextMenuItem(
          title: widget.isMuted ? 'Unmute' : 'Mute',
          icon: widget.isMuted ? Icons.volume_up : Icons.volume_off,
          onPressed: widget.onToggleMute,
        ),
        ContextMenuItem(
          title: 'Volume: ${(widget.volume * 100).toInt()}%',
          icon:
              widget.volume < 0.1
                  ? Icons.volume_mute
                  : widget.volume < 0.5
                  ? Icons.volume_down
                  : Icons.volume_up,
        ),
        ContextMenuItem(
          title: 'Set Volume to 25%',
          onPressed: () => widget.onVolumeChanged?.call(0.25),
        ),
        ContextMenuItem(
          title: 'Set Volume to 50%',
          onPressed: () => widget.onVolumeChanged?.call(0.5),
        ),
        ContextMenuItem(
          title: 'Set Volume to 75%',
          onPressed: () => widget.onVolumeChanged?.call(0.75),
        ),
        ContextMenuItem(
          title: 'Set Volume to 100%',
          onPressed: () => widget.onVolumeChanged?.call(1.0),
        ),
      ],
    );
  }

  // Helper to get the loop mode icon
  IconData _getLoopModeIcon() {
    switch (widget.loopMode) {
      case LoopMode.none:
        return Icons.repeat;
      case LoopMode.all:
        return Icons.repeat;
      case LoopMode.one:
        return Icons.repeat_one;
    }
  }

  // Helper to format duration
  String _formatDuration(Duration duration) {
    final String hours = duration.inHours > 0 ? '${duration.inHours}:' : '';
    final String minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final String seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$hours$minutes:$seconds';
  }
}
