import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:file_selector/file_selector.dart';

class SubtitleSettings extends StatefulWidget {
  final Player player;
  final List<SubtitleTrack> subtitles;
  final int currentSubtitleIndex;
  final Function(int) onSubtitleChanged;
  final Function(String) onSubtitleAdded;
  final double subtitleDelay;
  final Function(double) onSubtitleDelayChanged;

  const SubtitleSettings({
    Key? key,
    required this.player,
    required this.subtitles,
    required this.currentSubtitleIndex,
    required this.onSubtitleChanged,
    required this.onSubtitleAdded,
    required this.subtitleDelay,
    required this.onSubtitleDelayChanged,
  }) : super(key: key);

  @override
  State<SubtitleSettings> createState() => _SubtitleSettingsState();
}

class _SubtitleSettingsState extends State<SubtitleSettings> {
  double _fontSize = 24.0;
  Color _subtitleColor = Colors.white;
  bool _showBackground = true;
  double _backgroundOpacity = 0.6;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Subtitle Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle track selection
                    const Text(
                      'Subtitle Track',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<int>(
                        value: widget.currentSubtitleIndex,
                        dropdownColor: Colors.black.withOpacity(0.9),
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        items: [
                          const DropdownMenuItem(
                            value: -1,
                            child: Text(
                              'No Subtitles',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          ...List.generate(widget.subtitles.length, (index) {
                            final subtitle = widget.subtitles[index];
                            return DropdownMenuItem(
                              value: index,
                              child: Text(
                                subtitle.title ?? 'Track ${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            widget.onSubtitleChanged(value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Load subtitle file button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Load Subtitle File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D8D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: _loadSubtitleFile,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Subtitle delay adjustment
                    const Text(
                      'Subtitle Timing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.white),
                          onPressed: () {
                            widget.onSubtitleDelayChanged(widget.subtitleDelay - 0.1);
                          },
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFFF4D8D),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: const Color(0xFFFF4D8D),
                              overlayColor: const Color(0x29FF4D8D),
                            ),
                            child: Slider(
                              value: widget.subtitleDelay,
                              min: -10.0,
                              max: 10.0,
                              divisions: 200,
                              label: widget.subtitleDelay.toStringAsFixed(1),
                              onChanged: widget.onSubtitleDelayChanged,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () {
                            widget.onSubtitleDelayChanged(widget.subtitleDelay + 0.1);
                          },
                        ),
                      ],
                    ),
                    Center(
                      child: Text(
                        'Delay: ${widget.subtitleDelay.toStringAsFixed(1)}s',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Font size adjustment
                    const Text(
                      'Font Size',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFFF4D8D),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: const Color(0xFFFF4D8D),
                        overlayColor: const Color(0x29FF4D8D),
                      ),
                      child: Slider(
                        value: _fontSize,
                        min: 16.0,
                        max: 32.0,
                        divisions: 16,
                        label: _fontSize.round().toString(),
                        onChanged: (value) {
                          setState(() => _fontSize = value);
                          _updateSubtitleStyle();
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Background settings
                    Row(
                      children: [
                        Checkbox(
                          value: _showBackground,
                          onChanged: (value) {
                            setState(() => _showBackground = value ?? false);
                            _updateSubtitleStyle();
                          },
                          activeColor: const Color(0xFFFF4D8D),
                          checkColor: Colors.white,
                        ),
                        const Text(
                          'Show Background',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_showBackground) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Background Opacity',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFFF4D8D),
                          inactiveTrackColor: Colors.white24,
                          thumbColor: const Color(0xFFFF4D8D),
                          overlayColor: const Color(0x29FF4D8D),
                        ),
                        child: Slider(
                          value: _backgroundOpacity,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: '${(_backgroundOpacity * 100).round()}%',
                          onChanged: (value) {
                            setState(() => _backgroundOpacity = value);
                            _updateSubtitleStyle();
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSubtitleFile() async {
    try {
      final typeGroup = XTypeGroup(
        label: 'Subtitles',
        extensions: ['srt', 'vtt', 'ass', 'ssa'],
      );

      final file = await openFile(
        acceptedTypeGroups: [typeGroup],
      );

      if (file != null) {
        widget.onSubtitleAdded(file.path);
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
  }

  void _updateSubtitleStyle() {
    // Update subtitle styling through the player
    if (widget.player.platform is NativePlayer) {
      final nativePlayer = widget.player.platform as NativePlayer;
      
      nativePlayer.setProperty(
        'sub-scale',
        (_fontSize / 24.0).toString(), // normalize to base font size
      );

      if (_showBackground) {
        nativePlayer.setProperty(
          'sub-back-color',
          '${Colors.black.value.toRadixString(16)}',
        );
        nativePlayer.setProperty(
          'sub-back-alpha',
          (_backgroundOpacity * 255).round().toString(),
        );
      } else {
        nativePlayer.setProperty('sub-back-color', '00000000');
      }
    }
  }
} 