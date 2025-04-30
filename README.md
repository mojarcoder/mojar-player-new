# Mojar Player Pro

A professional media player with modern interface and advanced playback capabilities.

## Installation

You can install Mojar Player Pro using either the .deb package (for Debian/Ubuntu-based systems) or the AppImage (for any Linux distribution).

### Installing with .deb package (Debian/Ubuntu)

1. Download the `mojar-player-pro_1.0.6.deb` package
2. Open terminal and navigate to the download directory
3. Install using one of these methods:

   **Method 1:** Using the package manager:
   ```bash
   sudo apt install ./mojar-player-pro_1.0.6.deb
   ```

   **Method 2:** Using dpkg:
   ```bash
   sudo dpkg -i mojar-player-pro_1.0.6.deb
   sudo apt-get install -f  # Install any missing dependencies
   ```

After installation, you can:
- Find "Mojar Player Pro" in your applications menu
- Launch it from the terminal with `mojar_player_pro`
- Search for it in your system's application launcher

### Using AppImage (Any Linux Distribution)

1. Download the `mojar_player_pro.AppImage`
2. Make it executable:
   ```bash
   chmod +x mojar_player_pro.AppImage
   ```
3. Run it:
   ```bash
   ./mojar_player_pro.AppImage
   ```

**Optional:** To integrate the AppImage with your system:
1. Move it to a permanent location:
   ```bash
   mkdir -p ~/Applications
   mv mojar_player_pro.AppImage ~/Applications/
   ```
2. Create a desktop shortcut:
   ```bash
   wget https://raw.githubusercontent.com/mojarcoder/mojar-player-pro/main/app.png -O ~/.local/share/icons/mojar-player-pro.png
   ```
   Create a desktop entry file:
   ```bash
   echo "[Desktop Entry]
   Type=Application
   Name=Mojar Player Pro
   Comment=Professional Media Player
   Exec=$HOME/Applications/mojar_player_pro.AppImage
   Icon=$HOME/.local/share/icons/mojar-player-pro.png
   Categories=AudioVideo;Player;
   Terminal=false" > ~/.local/share/applications/mojar-player-pro.desktop
   ```

## System Requirements

- Linux operating system
- x86_64 architecture
- GTK 3.0 or later
- GLib 2.0 or later

## Features

- Modern and intuitive user interface
- Support for various media formats
- Advanced playback controls
- Hardware-accelerated video playback (where available)

## Support

For issues and feature requests, please visit our [GitHub repository](https://github.com/mojarcoder/mojar-player-pro/issues).

## Dependencies

Add these dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Media playback
  media_kit: ^1.1.10                    # Primary media player
  media_kit_video: ^1.2.4               # Video player support
  media_kit_libs_video: ^1.0.4          # Video codecs
  chewie: ^1.7.5                        # Additional video player controls
  audioplayers: ^5.2.1                  # Audio playback support

  # UI and Design
  font_awesome_flutter: ^10.7.0         # Icons
  provider: ^6.1.1                      # State management
  
  # File handling
  path_provider: ^2.1.2                 # File system access
  file_selector: ^1.0.3                 # File picker dialogs
  shared_preferences: ^2.2.2            # Local storage
  
  # Platform integration
  url_launcher: ^6.2.4                  # URL handling
```

## Setup Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/mojarcoder/mojar-player-pro.git
   cd mojar-player-pro
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   # For development
   flutter run

   # For specific platform
   flutter run -d windows
   flutter run -d macos
   flutter run -d linux
   ```

4. Build for release:
   ```bash
   # For Windows
   flutter build windows

   # For macOS
   flutter build macos

   # For Linux
   flutter build linux
   ```

## Permissions

### macOS
The following permissions are required:
- Music Library Access
- File Access
- Photo Library Access (for album art)
- Microphone Access (for audio effects)

### Linux
Make sure you have the necessary permissions to access:
- Audio devices
- Video devices
- File system

### Windows
No special permissions required, but ensure you have:
- DirectX installed
- Microsoft Visual C++ Redistributable

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [media_kit](https://pub.dev/packages/media_kit) for the powerful media playback engine
- [Flutter](https://flutter.dev) for the amazing framework
- All contributors and users of this project

## Contact

- GitHub: [@mojarcoder](https://github.com/mojarcoder)
- Email: mojarcoder@gmail.com

## Version Information

Current version: 1.0.6

### What's New in 1.0.6
- Fixed media playback restart issue when playing audio/video after completion
- Enhanced context menu in landscape mode to prevent overflow
- Improved folder browsing for all platforms (iOS, Android, Windows, macOS, Linux)
- Bug fixes and performance improvements
- set minSdk 21
### What's New in 1.0.5
- Added custom album art setting feature
- Improved audio visualization with animated cassette player
- Enhanced playlist management with smooth transitions between audio and video
- Added multiple loop modes (None, One, All)
- Fixed issues when transitioning between audio and video tracks
- Various UI improvements and bug fixes
