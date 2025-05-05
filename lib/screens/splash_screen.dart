import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Main animations
  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Heartbeat animation
  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

  // Floating hearts animations
  late AnimationController _floatingHeartsController;
  final List<HeartParticle> _heartParticles = [];

  @override
  void initState() {
    super.initState();

    // Main animation controller
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeInOut),
      ),
    );

    // Heartbeat animation controller
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _heartbeatAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut),
    );

    // Floating hearts animation
    _floatingHeartsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Create random heart particles
    _generateHeartParticles();

    // Start main animation
    _mainController.forward();

    // Navigate to next screen after delay
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => widget.nextScreen,
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              const begin = 0.0;
              const end = 1.0;
              const curve = Curves.easeInOut;

              var tween = Tween(
                begin: begin,
                end: end,
              ).chain(CurveTween(curve: curve));
              var fadeAnimation = animation.drive(tween);

              return FadeTransition(opacity: fadeAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  void _generateHeartParticles() {
    final rnd = math.Random();
    for (int i = 0; i < 15; i++) {
      _heartParticles.add(
        HeartParticle(
          initialPosition: Offset(
            rnd.nextDouble() * 400 - 200,
            rnd.nextDouble() * 400 - 200,
          ),
          size: rnd.nextDouble() * 20 + 10,
          velocity: Offset(rnd.nextDouble() * 2 - 1, -2 - rnd.nextDouble() * 2),
          color:
              HSLColor.fromAHSL(
                rnd.nextDouble() * 0.5 + 0.3,
                rnd.nextDouble() * 30 + 330,
                0.8,
                0.7 + rnd.nextDouble() * 0.3,
              ).toColor(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _heartbeatController.dispose();
    _floatingHeartsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Love-inspired colors
    const Color primaryPink = Color(0xFFFF4D8D);
    const Color lightPink = Color(0xFFFFB6C1);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryPink, lightPink.withOpacity(0.7)],
          ),
        ),
        child: Stack(
          children: [
            // Floating heart particles
            AnimatedBuilder(
              animation: _floatingHeartsController,
              builder: (context, child) {
                return CustomPaint(
                  painter: HeartParticlesPainter(
                    particles: _heartParticles,
                    progress: _floatingHeartsController.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile image with heart background
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Hero(
                        tag: 'profileImage',
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Animated heart background
                            AnimatedBuilder(
                              animation: _heartbeatAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _heartbeatAnimation.value,
                                  child: Icon(
                                    Icons.favorite,
                                    size: 180,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                );
                              },
                            ),
                            // Profile image
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(60),
                                child: _buildProfileImage(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Mojar ',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Player Pro',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        
                        SizedBox(width: 5),
                        Icon(Icons.favorite, color: Colors.white, size: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Made with love by Mojar Coder',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'v1.0.8',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    // Use the profile image if it exists, otherwise show a placeholder
    return Image.asset(
      'assets/images/profile.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(color: Colors.grey.shade300);
      },
    );
  }
}

// Class to represent a floating heart particle
class HeartParticle {
  Offset initialPosition;
  Offset velocity;
  double size;
  Color color;

  HeartParticle({
    required this.initialPosition,
    required this.velocity,
    required this.size,
    required this.color,
  });

  Offset getPosition(double progress) {
    // Apply simple physics for movement
    return initialPosition + velocity * progress * 100;
  }

  double getOpacity(double progress) {
    // Fade out as it rises
    return 1.0 - progress;
  }
}

// CustomPainter for drawing floating heart particles
class HeartParticlesPainter extends CustomPainter {
  final List<HeartParticle> particles;
  final double progress;

  HeartParticlesPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final position = particle.getPosition(progress);
      final opacity = particle.getOpacity(progress);

      // Only draw if within bounds and visible
      if (opacity > 0 &&
          position.dx >= -100 &&
          position.dx <= size.width + 100 &&
          position.dy >= -100 &&
          position.dy <= size.height + 100) {
        final center = Offset(size.width / 2, size.height / 2) + position;

        // Draw heart shape
        final paint =
            Paint()
              ..color = particle.color.withOpacity(opacity)
              ..style = PaintingStyle.fill;

        final path = Path();
        final heartSize = particle.size;

        // Draw heart shape using bezier curves
        path.moveTo(center.dx, center.dy + heartSize * 0.3);
        path.cubicTo(
          center.dx,
          center.dy,
          center.dx - heartSize * 0.4,
          center.dy - heartSize * 0.2,
          center.dx - heartSize * 0.5,
          center.dy - heartSize * 0.5,
        );
        path.cubicTo(
          center.dx - heartSize * 0.6,
          center.dy - heartSize * 0.7,
          center.dx - heartSize * 0.4,
          center.dy - heartSize * 0.9,
          center.dx,
          center.dy - heartSize * 0.5,
        );
        path.cubicTo(
          center.dx + heartSize * 0.4,
          center.dy - heartSize * 0.9,
          center.dx + heartSize * 0.6,
          center.dy - heartSize * 0.7,
          center.dx + heartSize * 0.5,
          center.dy - heartSize * 0.5,
        );
        path.cubicTo(
          center.dx + heartSize * 0.4,
          center.dy - heartSize * 0.2,
          center.dx,
          center.dy,
          center.dx,
          center.dy + heartSize * 0.3,
        );

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
