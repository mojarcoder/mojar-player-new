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
  late AnimationController _controller;
  late Animation<double> _heartbeatAnimation;

  @override
  void initState() {
    super.initState();

    // Create animation controller for heartbeat effect
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Heartbeat animation
    _heartbeatAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Love-inspired color scheme
    const Color primaryPink = Color(0xFFFF4D8D);
    const Color lightPink = Color(0xFFFFB6C1);
    const Color darkPink = Color(0xFFE91E63);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryPink, Colors.white],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Animated heartbeat logo
              AnimatedBuilder(
                animation: _heartbeatAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _heartbeatAnimation.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Heart shape background
                        Icon(Icons.favorite, size: 150, color: darkPink),
                        // Profile image
                        CircleAvatar(
                          radius: 55,
                          backgroundImage: const AssetImage(
                            'assets/images/profile.jpg',
                          ),
                          backgroundColor: lightPink,
                          onBackgroundImageError: (_, __) {
                            return;
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Mojar Coder',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: darkPink,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Made with ♥ for music lovers',
                style: TextStyle(
                  fontSize: 18,
                  color: darkPink,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                height: 2,
                width: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, darkPink, Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Connect with me',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: darkPink,
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
              Container(
                height: 2,
                width: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, darkPink, Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Mojar Player v1.0.0',
                    style: TextStyle(fontSize: 16, color: darkPink),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.favorite, size: 16, color: darkPink),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '© 2024 Mojar Coder. All rights reserved.',
                style: TextStyle(fontSize: 14, color: darkPink),
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
    return Card(
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
    );
  }

  Future<void> _launchUrl(String url) async {
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
