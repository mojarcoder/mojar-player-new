import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heartbeatAnimation;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
  }

  void _initializeAnimation() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _heartbeatAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (!_disposed && mounted) {
      _controller.repeat(reverse: true);
    }
  }

  void _handleBack(BuildContext context) {
    if (_disposed) return;
    _disposed = true;
    
    if (_controller.isAnimating) {
      _controller.stop();
    }
    _controller.dispose();
    
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_disposed) return const SizedBox.shrink();

    // Love-inspired color scheme
    const Color primaryPink = Color(0xFFFF4D8D);
    const Color lightPink = Color(0xFFFFB6C1);
    const Color darkPink = Color(0xFFE91E63);

    return WillPopScope(
      onWillPop: () async {
        if (!_disposed) {
          _disposed = true;
          if (_controller.isAnimating) {
            _controller.stop();
          }
          _controller.dispose();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xFFFF4D8D),
          elevation: 0,
          leading: BackButton(
            color: Colors.white,
            onPressed: () => _handleBack(context),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [primaryPink, Colors.white],
              stops: [0.0, 0.3],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const SizedBox(height: 20),
              // Animated heartbeat logo with RepaintBoundary
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _heartbeatAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _heartbeatAnimation.value,
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Heart shape background
                      const Icon(Icons.favorite, size: 150, color: darkPink),
                      // Profile image
                      CircleAvatar(
                        radius: 55,
                        backgroundImage: const AssetImage(
                          'assets/images/profile.jpg',
                        ),
                        backgroundColor: lightPink,
                        onBackgroundImageError: (_, __) {},
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Mojar Coder',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: darkPink,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Made with ♥ for music lovers',
                  style: TextStyle(
                    fontSize: 18,
                    color: darkPink,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: Container(
                  height: 2,
                  width: 100,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, darkPink, Colors.transparent],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Connect with me',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: darkPink,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildSocialLink(
                icon: FontAwesomeIcons.facebook,
                title: 'Facebook',
                subtitle: 'facebook.com/mojarcoder',
                url: 'https://facebook.com/mojarcoder',
                color: primaryPink,
              ),
              _buildSocialLink(
                icon: FontAwesomeIcons.youtube,
                title: 'YouTube',
                subtitle: 'youtube.com/@mojarcoder',
                url: 'https://youtube.com/@mojarcoder',
                color: primaryPink,
              ),
              _buildSocialLink(
                icon: FontAwesomeIcons.github,
                title: 'GitHub',
                subtitle: 'github.com/mojarcoder',
                url: 'https://github.com/mojarcoder',
                color: primaryPink,
              ),
              _buildSocialLink(
                icon: FontAwesomeIcons.whatsapp,
                title: 'WhatsApp',
                subtitle: '+8801640641524',
                url: 'https://wa.me/8801640641524',
                color: primaryPink,
              ),
              _buildSocialLink(
                icon: FontAwesomeIcons.envelope,
                title: 'Email',
                subtitle: 'mojarcoder@gmail.com',
                url: 'mailto:mojarcoder@gmail.com',
                color: primaryPink,
              ),
              const SizedBox(height: 30),
              Center(
                child: Container(
                  height: 2,
                  width: 100,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, darkPink, Colors.transparent],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Mojar Player Pro v1.0.6',
                    style: TextStyle(fontSize: 16, color: darkPink),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.favorite, size: 16, color: darkPink),
                ],
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  '© 2024 Mojar Coder. All rights reserved.',
                  style: TextStyle(fontSize: 14, color: darkPink),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLink({
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
    required Color color,
  }) {
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: color.withOpacity(0.3), width: 1),
        ),
        child: InkWell(
          onTap: () => _launchUrl(url),
          borderRadius: BorderRadius.circular(15),
          splashColor: color.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(icon, color: color),
              ),
              title: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              subtitle: Text(subtitle),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (_disposed) return;
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}
