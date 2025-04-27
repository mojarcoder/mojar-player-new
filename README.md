# Mojar Player Pro

A modern and feature-rich media player built with Flutter that supports both audio and video playback.

## Features

- 🎵 Audio playback support (MP3, WAV, FLAC, M4A)
- 🎥 Video playback support (MP4, MKV, AVI)
- 📝 Playlist management
- 🎨 Beautiful UI with animations
- 🎛️ Audio effects and equalizer
- 📺 Video subtitle support
- 🖼️ Custom album art support
- ⚡ Fast and responsive
- 💻 Cross-platform support (Windows, macOS, Linux)

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

## System Requirements

### Windows
- Windows 10 or later
- Microsoft Visual C++ Redistributable

### macOS
- macOS 10.14 or later
- Xcode (for development)

### Linux
- Ubuntu 20.04 or later
- Required packages:
  ```bash
  sudo apt-get update
  sudo apt-get install -y \
    libmpv-dev \
    mpv \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly
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
