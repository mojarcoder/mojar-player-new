import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:io';

import 'screens/splash_screen.dart';
import 'screens/folder_browser_screen.dart';
import 'screens/about_screen.dart';
import 'screens/player_screen.dart';
import 'services/folder_browser_service.dart';
import 'services/platform_service.dart';
import 'widgets/shortcut_item.dart';

// Love-inspired color scheme
const Color primaryPink = Color(0xFFFF4D8D);
const Color lightPink = Color(0xFFFFB6C1);
const Color darkPink = Color(0xFFE91E63);

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize platform services first
  await PlatformService.initialize();

  // Initialize media_kit
  MediaKit.ensureInitialized();

  // Request permissions at startup
  final folderService = FolderBrowserService();
  await folderService.checkPermissions();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mojar Player Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryPink),
        useMaterial3: true,
      ),
      home: const SplashScreen(nextScreen: HomeScreen()),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final FolderBrowserService _folderService = FolderBrowserService();
  bool _isLoading = false;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final bool _isPlaying = false;
  late AnimationController _controller;
  late Animation<double> _heartbeatAnimation;
  bool _isFullscreen = false;

  // Social media URLs
  final Uri _facebookUrl = Uri.parse('https://facebook.com/mojarcoder');
  final Uri _youtubeUrl = Uri.parse('https://youtube.com/@mojarcoder');
  final Uri _githubUrl = Uri.parse('https://github.com/mojarcoder');
  final Uri _whatsappUrl = Uri.parse('https://wa.me/8801640641524');
  final Uri _emailUrl = Uri.parse('mailto:mojarcoder@gmail.com');

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

    // Check fullscreen state when page is loaded
    _checkFullscreenState();
  }

  // Check the current fullscreen state
  Future<void> _checkFullscreenState() async {
    try {
      _isFullscreen = await PlatformService.isFullscreen();
      setState(() {});
    } catch (e) {
      debugPrint('Error checking fullscreen state: $e');
    }
  }

  // Function to exit fullscreen
  Future<void> _exitFullscreen() async {
    try {
      bool success = await PlatformService.exitFullscreen();
      if (success) {
        setState(() {
          _isFullscreen = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to exit fullscreen')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error exiting fullscreen: $e');
    }
  }

  // Function to launch URLs
  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${url.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mojar Player Pro',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryPink,
        elevation: 0,
        actions: [
          // Add keyboard shortcuts button
          IconButton(
            icon: const Icon(Icons.keyboard, size: 20),
            onPressed: _showKeyboardShortcuts,
            tooltip: 'Keyboard Shortcuts',
            color: Colors.white,
          ),
          // Add exit fullscreen button if in fullscreen mode
          if (_isFullscreen)
            IconButton(
              icon: const Icon(Icons.fullscreen_exit),
              onPressed: _exitFullscreen,
              tooltip: 'Exit Fullscreen (ESC)',
              color: Colors.white,
            ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.folder, size: 20),
            onPressed: _browseLocalFolders,
            tooltip: 'Browse Folders',
            color: Colors.white,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            ),
            tooltip: 'About',
            color: Colors.white,
          ),
        ],
      ),
      // Add keyboard listener for ESC key to exit fullscreen
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape &&
                _isFullscreen) {
              _exitFullscreen();
            } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
              _toggleFullscreen();
            }
          }
        },
        child: GestureDetector(
          // Add double-tap to exit fullscreen
          onDoubleTap: () {
            if (_isFullscreen) {
              _exitFullscreen();
            }
          },
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: primaryPink),
                )
              : _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [primaryPink, Colors.white],
                          stops: [0.0, 0.3],
                        ),
                      ),
                      child: Center(
                        child: GestureDetector(
                          onLongPress: () => _showContextMenu(context),
                          onSecondaryTap: () => _showContextMenu(context),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 20),
                                // Animated heartbeat logo
                                AnimatedBuilder(
                                  animation: _heartbeatAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _heartbeatAnimation.value,
                                      child: Hero(
                                        tag: 'profileImage',
                                        child: CircleAvatar(
                                          radius: 60,
                                          backgroundColor: lightPink,
                                          backgroundImage: const AssetImage(
                                            'assets/images/profile.jpg',
                                          ),
                                          onBackgroundImageError: (_, __) {},
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Mojar Player Pro',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: darkPink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Play your media files with ease',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: darkPink,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  height: 2,
                                  width: 100,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        darkPink,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildActionButton(
                                      icon: Icons.folder_open,
                                      label: 'Open Media',
                                      onPressed: _openFile,
                                    ),
                                    const SizedBox(width: 20),
                                    _buildActionButton(
                                      icon: Icons.folder,
                                      label: 'Browse Folders',
                                      onPressed: _browseLocalFolders,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 30),
                                const Text(
                                  'Connect with us',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: darkPink,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildSocialLinks(),
                                const SizedBox(height: 20),
                                Container(
                                  height: 2,
                                  width: 100,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        darkPink,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Mojar Player Pro v1.0.7',
                                      style: TextStyle(
                                          fontSize: 16, color: darkPink),
                                    ),
                                    SizedBox(width: 5),
                                    Icon(Icons.favorite,
                                        size: 16, color: darkPink),
                                  ],
                                ),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialButton(
          FontAwesomeIcons.facebook,
          Colors.blue[800] ?? Colors.blue,
          () => _launchUrl(_facebookUrl),
          'Facebook',
        ),
        _socialButton(
          FontAwesomeIcons.youtube,
          Colors.red,
          () => _launchUrl(_youtubeUrl),
          'YouTube',
        ),
        _socialButton(
          FontAwesomeIcons.github,
          Colors.black87,
          () => _launchUrl(_githubUrl),
          'GitHub',
        ),
        _socialButton(
          FontAwesomeIcons.whatsapp,
          Colors.green,
          () => _launchUrl(_whatsappUrl),
          'WhatsApp',
        ),
        _socialButton(
          FontAwesomeIcons.envelope,
          Colors.orange[700] ?? Colors.orange,
          () => _launchUrl(_emailUrl),
          'Email',
        ),
      ],
    );
  }

  Widget _socialButton(
    IconData icon,
    Color color,
    VoidCallback onTap,
    String tooltip,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 1),
            ),
            child: Center(child: FaIcon(icon, size: 20, color: color)),
          ),
        ),
      ),
    );
  }

  // Show context menu for media options
  void _showContextMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Open Media File'),
            onTap: () {
              Navigator.pop(context);
              _openFile();
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Browse Folders'),
            onTap: () {
              Navigator.pop(context);
              _browseLocalFolders();
            },
          ),
        ),
      ],
    );
  }

  Future<void> _browseLocalFolders() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const FolderBrowserScreen()),
    );

    if (result != null) {
      await _initializePlayer(result);
    }
  }

  Future<void> _initializePlayer(String path) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayerScreen(videoPath: path)),
    );
  }

  Future<void> _openFile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check permissions using our service
      bool hasPermission = await _folderService.checkPermissions();

      if (!hasPermission) {
        if (mounted) {
          _showPermissionDeniedDialog();
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Use our service to pick media files
      final selectedFiles = await _folderService.pickMediaFiles();

      if (selectedFiles.isNotEmpty) {
        final path = selectedFiles.first;
        debugPrint('Selected file: $path');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected: ${_folderService.getFileName(path)}'),
            ),
          );
        }

        // Initialize player with the selected file
        await _initializePlayer(path);
      } else {
        debugPrint('No file selected');
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Storage access permission is required to select media files. Please grant the permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Function to toggle fullscreen
  Future<void> _toggleFullscreen() async {
    try {
      bool success = false;
      if (_isFullscreen) {
        success = await PlatformService.exitFullscreen();
      } else {
        success = await PlatformService.enterFullscreen();
      }

      if (success && mounted) {
        setState(() {
          _isFullscreen = !_isFullscreen;
        });
      }
    } catch (e) {
      debugPrint('Error toggling fullscreen: $e');
    }
  }

  // Show keyboard shortcuts guide
  void _showKeyboardShortcuts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keyboard Shortcuts',
            style: TextStyle(color: primaryPink)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShortcutItem(keyName: 'F', description: 'Toggle fullscreen'),
              ShortcutItem(keyName: 'ESC', description: 'Exit fullscreen'),
              ShortcutItem(
                  keyName: 'Double-click', description: 'Exit fullscreen'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: primaryPink)),
          ),
        ],
      ),
    );
  }
}
