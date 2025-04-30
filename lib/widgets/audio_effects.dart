import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class AudioEffects extends ChangeNotifier {
  static const List<double> _defaultEqValues = [0, 0, 0, 0, 0, 0, 0];
  static const List<String> _eqBands = [
    '60Hz',
    '150Hz',
    '400Hz',
    '1kHz',
    '2.4kHz',
    '6kHz',
    '15kHz'
  ];

  List<double> _eqValues = List.from(_defaultEqValues);
  double _bassBoost = 0.0;
  double _virtualizer = 0.0;
  double _reverb = 0.0;
  bool _isEnabled = false;
  Player? _player;

  // Equalizer band frequencies in Hz
  final List<int> _eqFrequencies = [60, 150, 400, 1000, 2400, 6000, 15000];

  void setPlayer(Player player) {
    _player = player;
    _isEnabled = true; // Enable effects by default when player is set
    applyEffects(); // Apply effects immediately
  }

  Future<void> applyEffects() async {
    if (!_isEnabled || _player == null) return;

    try {
      if (_player?.platform is NativePlayer) {
        final List<String> filters = [];

        // Add equalizer bands if any are non-zero
        if (_eqValues.any((value) => value != 0)) {
          final List<String> eqParams = [];
          for (int i = 0; i < _eqValues.length; i++) {
            if (_eqValues[i] != 0) {
              final freq = _eqFrequencies[i];
              // Increase the width for more noticeable effect
              eqParams.add(
                  'equalizer=f=$freq:width_type=h:width=2:g=${_eqValues[i]}');
            }
          }
          if (eqParams.isNotEmpty) {
            filters.addAll(eqParams);
          }
        }

        // Add bass boost with stronger effect
        if (_bassBoost > 0) {
          filters.add(
              'bass=g=${(_bassBoost / 1.5).toStringAsFixed(1)}:f=100:width_type=h:width=1');
        }

        // Add stereo widening (virtualizer) with stronger effect
        if (_virtualizer > 0) {
          filters.add(
              'stereotools=mlev=${(_virtualizer / 50).toStringAsFixed(2)}:slev=${(_virtualizer / 50).toStringAsFixed(2)}');
        }

        // Add reverb with stronger effect
        if (_reverb > 0) {
          filters.add('aecho=0.8:0.8:${(_reverb / 50 * 100).toInt()}:0.5');
        }

        // Apply the filters
        final filterString = filters.isEmpty ? 'anull' : filters.join(',');
        debugPrint('Applying audio filters: $filterString');

        // Use the correct API to set audio filters
        await (_player?.platform as NativePlayer)
            .setProperty('af', filterString);

        // Pause and resume to ensure effects are applied
        if (_player?.state.playing == true) {
          await _player?.pause();
          await Future.delayed(const Duration(milliseconds: 100));
          await _player?.play();
        }
      }
    } catch (e) {
      debugPrint('Error applying audio effects: $e');
      // Try to reset to a safe state
      await resetEffects();
    }
  }

  Future<void> resetEffects() async {
    _isEnabled = false;

    if (_player?.platform is NativePlayer) {
      await (_player?.platform as NativePlayer).setProperty('af', 'anull');
    }
  }

  Widget buildEqualizerDialog(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Text('Equalizer', style: TextStyle(color: Colors.white)),
              const Spacer(),
              Switch(
                value: _isEnabled,
                onChanged: (value) async {
                  setState(() => _isEnabled = value);
                  if (!value) {
                    await resetEffects();
                  } else {
                    await applyEffects();
                  }
                },
                activeColor: const Color(0xFFFF4D8D),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Equalizer bands
                SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_eqBands.length, (index) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _eqBands[index],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          RotatedBox(
                            quarterTurns: 3,
                            child: SizedBox(
                              width: 100,
                              child: Slider(
                                value: _eqValues[index],
                                min: -12,
                                max: 12,
                                divisions: 24,
                                onChanged: _isEnabled
                                    ? (value) async {
                                        setState(
                                            () => _eqValues[index] = value);
                                        await applyEffects();
                                      }
                                    : null,
                                activeColor: const Color(0xFFFF4D8D),
                                inactiveColor: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                          Text(
                            '${_eqValues[index].toStringAsFixed(1)}dB',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                // Presets
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPresetButton('Flat', () async {
                      setState(() => _eqValues = List.from(_defaultEqValues));
                      await applyEffects();
                    }),
                    _buildPresetButton('Rock', () async {
                      setState(() => _eqValues = [4, 3, 0, -2, -1, 2, 3]);
                      await applyEffects();
                    }),
                    _buildPresetButton('Pop', () async {
                      setState(() => _eqValues = [-1, 2, 4, 2, 0, -1, -2]);
                      await applyEffects();
                    }),
                    _buildPresetButton('Classical', () async {
                      setState(() => _eqValues = [0, 0, 0, 0, 0, -2, -4]);
                      await applyEffects();
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildAudioEffectsDialog(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Row(
            children: [
              const Text('Audio Effects',
                  style: TextStyle(color: Colors.white)),
              const Spacer(),
              Switch(
                value: _isEnabled,
                onChanged: (value) async {
                  setState(() => _isEnabled = value);
                  if (!value) {
                    await resetEffects();
                  } else {
                    await applyEffects();
                  }
                },
                activeColor: const Color(0xFFFF4D8D),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEffectSlider(
                  'Bass Boost',
                  _bassBoost,
                  0.0,
                  100.0,
                  (value) async {
                    setState(() => _bassBoost = value);
                    await applyEffects();
                  },
                ),
                _buildEffectSlider(
                  'Virtualizer',
                  _virtualizer,
                  0.0,
                  100.0,
                  (value) async {
                    setState(() => _virtualizer = value);
                    await applyEffects();
                  },
                ),
                _buildEffectSlider(
                  'Reverb',
                  _reverb,
                  0.0,
                  100.0,
                  (value) async {
                    setState(() => _reverb = value);
                    await applyEffects();
                  },
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: buildEqualizerDialog(context),
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Open Equalizer',
                    style: TextStyle(color: Color(0xFFFF4D8D)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: _isEnabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF4D8D),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildEffectSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: _isEnabled ? onChanged : null,
                activeColor: const Color(0xFFFF4D8D),
                inactiveColor: Colors.white.withOpacity(0.3),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${value.toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
