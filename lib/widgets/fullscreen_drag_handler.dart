import 'package:flutter/material.dart';
import '../services/platform_service.dart';

class FullscreenDragHandler extends StatefulWidget {
  final VoidCallback? onExitFullscreen;
  final Widget child;

  const FullscreenDragHandler({
    super.key,
    required this.child,
    this.onExitFullscreen,
  });

  @override
  State<FullscreenDragHandler> createState() => _FullscreenDragHandlerState();
}

class _FullscreenDragHandlerState extends State<FullscreenDragHandler> {
  bool _isDragging = false;
  double _dragDistance = 0.0;
  final double _dragThreshold = 60.0; // Distance needed to trigger exit

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Drag handler at top of screen
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onVerticalDragStart: (_) {
              setState(() {
                _isDragging = true;
                _dragDistance = 0;
              });
            },
            onVerticalDragUpdate: (details) {
              if (_isDragging) {
                setState(() {
                  // Only allow downward drag
                  _dragDistance += details.delta.dy > 0 ? details.delta.dy : 0;
                });
              }
            },
            onVerticalDragEnd: (_) async {
              if (_dragDistance >= _dragThreshold) {
                // Exit fullscreen if drag distance exceeds threshold
                await PlatformService.exitFullscreen();
                if (widget.onExitFullscreen != null) {
                  widget.onExitFullscreen!();
                }
              }

              setState(() {
                _isDragging = false;
                _dragDistance = 0;
              });
            },
            child: Container(
              height: 40, // Height of drag area
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(_isDragging ? 0.5 : 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: 4,
                  width: _isDragging ? 100 : 60,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(_isDragging ? 0.8 : 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Show visual feedback during drag
        if (_isDragging)
          Positioned(
            top: _dragDistance / 2,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              alignment: Alignment.center,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fullscreen_exit,
                      color: Colors.white.withOpacity(
                          _dragDistance >= _dragThreshold ? 1.0 : 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dragDistance >= _dragThreshold
                          ? 'Release to exit fullscreen'
                          : 'Pull down to exit fullscreen',
                      style: TextStyle(
                        color: Colors.white.withOpacity(
                            _dragDistance >= _dragThreshold ? 1.0 : 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
