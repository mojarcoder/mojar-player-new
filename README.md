# Mojar Player Pro

A professional media player with modern interface and advanced playback capabilities.

## Installation

You can install Mojar Player Pro using the .deb package (for Debian/Ubuntu-based systems), the .rpm package (for Fedora/RHEL-based systems), or the AppImage (for any Linux distribution).

### System Requirements and Dependencies

Before installing Mojar Player Pro, ensure your system meets these requirements:

#### For Debian/Ubuntu-based systems:
```bash
# Install required dependencies
sudo apt install libmpv-dev mpv

# Optional but recommended for better performance
sudo apt install ffmpeg libavcodec-extra
```

#### For Fedora-based systems:
```bash
# Install required dependencies
sudo dnf install mpv mpv-libs-devel

# Optional but recommended for better performance
sudo dnf install ffmpeg
```

#### For RHEL/CentOS-based systems:
```bash
# Enable EPEL repository if not already enabled
sudo yum install epel-release

# Install required dependencies
sudo yum install mpv mpv-libs-devel

# Optional but recommended for better performance
sudo yum install ffmpeg
```

#### For Arch Linux-based systems:
```bash
# Install required dependencies
sudo pacman -S mpv

# Optional but recommended for better performance
sudo pacman -S ffmpeg
```

### Installing with .deb package (Debian/Ubuntu)

1. Download the `mojar-player-pro_1.0.9_amd64.deb` package
2. Install the required dependencies:
   ```bash
   sudo apt install libmpv-dev mpv
   ```
3. Open terminal and navigate to the download directory
4. Install using one of these methods:

   **Method 1:** Using the package manager (recommended):
   ```bash
   sudo apt install ./mojar-player-pro_1.0.9_amd64.deb
   ```

   **Method 2:** Using dpkg:
   ```bash
   sudo dpkg -i mojar-player-pro_1.0.9_amd64.deb
   sudo apt-get install -f  # Install any missing dependencies
   ```

After installation, you can:
- Find "Mojar Player Pro" in your applications menu
- Launch it from the terminal with `mojar-player-pro`
- Search for it in your system's application launcher

### Installing with .rpm package (Fedora/RHEL/CentOS)

1. Download the `mojar-player-pro-1.0.9-2.x86_64.rpm` package
2. Install the required dependencies:
   ```bash
   # For Fedora
   sudo dnf install mpv mpv-libs-devel

   # For RHEL/CentOS
   sudo yum install epel-release  # If not already installed
   sudo yum install mpv mpv-libs-devel
   ```
3. Open terminal and navigate to the download directory
4. Install using one of these methods:

   **Method 1:** Using dnf (Fedora - recommended):
   ```bash
   sudo dnf install ./mojar-player-pro-1.0.9-2.x86_64.rpm
   ```

   **Method 2:** Using yum (RHEL/CentOS - recommended):
   ```bash
   sudo yum install ./mojar-player-pro-1.0.9-2.x86_64.rpm
   ```

   **Method 3:** Using rpm directly (not recommended as it doesn't handle dependencies):
   ```bash
   sudo rpm -i mojar-player-pro-1.0.9-2.x86_64.rpm
   ```

After installation, you can:
- Find "Mojar Player Pro" in your applications menu
- Launch it from the terminal with `mojar-player-pro`
- Search for it in your system's application launcher

### Troubleshooting Installation Issues

#### Missing libmpv.so.2
If you encounter an error like `error while loading shared libraries: libmpv.so.2: cannot open shared object file`:
```bash
# For Debian/Ubuntu
sudo apt install libmpv-dev mpv

# For Fedora
sudo dnf install mpv mpv-libs-devel

# For RHEL/CentOS
sudo yum install mpv mpv-libs-devel

# For Arch Linux
sudo pacman -S mpv
```

#### Video Playback Issues
If you experience video playback issues:
```bash
# For Debian/Ubuntu
sudo apt install ffmpeg libavcodec-extra

# For Fedora/RHEL/CentOS
sudo dnf install ffmpeg  # or sudo yum install ffmpeg

# For Arch Linux
sudo pacman -S ffmpeg
```

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
  media_kit: ^1.1.8                     # Primary media player
  media_kit_video: ^1.2.4               # Video player support
  media_kit_libs_linux: ^1.2.1          # Linux media dependencies
  media_kit_libs_android_video: ^1.3.6  # Android video dependencies
  media_kit_libs_ios_video: ^1.1.4      # iOS video dependencies
  media_kit_libs_macos_video: ^1.1.4    # macOS video dependencies
  media_kit_libs_windows_video: ^1.0.9  # Windows video dependencies
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

5. Create a Debian package (for Linux):
   ```bash
   # First build the Linux release
   flutter build linux --release

   # Create the Debian package structure
   mkdir -p debian/DEBIAN debian/usr/local/bin debian/usr/share/applications debian/usr/share/icons/hicolor/256x256/apps debian/usr/local/lib/mojar-player-pro

   # Create control file
   echo "Package: mojar-player-pro
Version: 1.0.9
Section: multimedia
Priority: optional
Architecture: amd64
Depends: libmpv-dev, mpv
Maintainer: MojarCoder <mojarcoder@example.com>
Description: A beautiful media player application
 Mojar Player Pro is a feature-rich media player built with Flutter." > debian/DEBIAN/control

   # Copy application files
   cp -r build/linux/x64/release/bundle/* debian/usr/local/lib/mojar-player-pro/

   # Create launcher script
   echo '#!/bin/sh
cd /usr/local/lib/mojar-player-pro
./mojar_player_pro "$@"' > debian/usr/local/bin/mojar-player-pro
   chmod 755 debian/usr/local/bin/mojar-player-pro

   # Create desktop entry
   echo "[Desktop Entry]
Name=Mojar Player Pro
Comment=A beautiful media player application
Exec=/usr/local/bin/mojar-player-pro
Icon=mojar-player-pro
Terminal=false
Type=Application
Categories=AudioVideo;Player;
Keywords=Media;Player;Audio;Video;" > debian/usr/share/applications/mojar-player-pro.desktop

   # Copy icon
   cp assets/images/mojar_icon.png debian/usr/share/icons/hicolor/256x256/apps/mojar-player-pro.png

   # Build the package
   dpkg-deb --build debian mojar-player-pro_1.0.9_amd64.deb
   ```

6. Create an RPM package from the Debian package:
   ```bash
   # Install alien (tool to convert between package formats)
   sudo apt-get install alien

   # Convert the .deb package to .rpm
   # The --scripts flag preserves installation scripts
   sudo alien --to-rpm --scripts mojar-player-pro_1.0.9_amd64.deb

   # The output will be something like: mojar-player-pro-1.0.9-2.x86_64.rpm
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

#### Required System Dependencies

For the application to work properly, you need to install the following dependencies based on your distribution:

##### Debian/Ubuntu/Mint/Pop!_OS:
```bash
# Essential dependencies
sudo apt install libmpv-dev mpv

# For better codec support
sudo apt install ffmpeg libavcodec-extra

# For hardware acceleration
sudo apt install vainfo intel-media-va-driver  # For Intel GPUs
sudo apt install vainfo mesa-va-drivers        # For AMD GPUs
sudo apt install vdpauinfo mesa-vdpau-drivers  # For NVIDIA GPUs with open-source drivers
sudo apt install nvidia-vaapi-driver           # For NVIDIA GPUs with proprietary drivers
```

##### Fedora:
```bash
# Essential dependencies
sudo dnf install mpv mpv-libs-devel

# For better codec support
sudo dnf install ffmpeg

# For hardware acceleration
sudo dnf install libva-utils libva-intel-driver    # For Intel GPUs
sudo dnf install libva-utils mesa-va-drivers       # For AMD GPUs
sudo dnf install vdpauinfo mesa-vdpau-drivers      # For NVIDIA GPUs with open-source drivers
```

##### RHEL/CentOS/Rocky Linux/Alma Linux:
```bash
# Enable EPEL repository
sudo yum install epel-release

# Essential dependencies
sudo yum install mpv mpv-libs-devel

# For better codec support (may require additional repositories)
sudo yum install ffmpeg

# For hardware acceleration
sudo yum install libva-utils libva-intel-driver    # For Intel GPUs
sudo yum install libva-utils mesa-va-drivers       # For AMD GPUs
sudo yum install vdpauinfo mesa-vdpau-drivers      # For NVIDIA GPUs with open-source drivers
```

##### Arch Linux/Manjaro:
```bash
# Essential dependencies
sudo pacman -S mpv

# For better codec support
sudo pacman -S ffmpeg

# For hardware acceleration
sudo pacman -S libva-utils libva-intel-driver    # For Intel GPUs
sudo pacman -S libva-utils mesa-va-drivers       # For AMD GPUs
sudo pacman -S vdpauinfo mesa-vdpau-drivers      # For NVIDIA GPUs with open-source drivers
```

#### Troubleshooting Linux Issues

If you encounter permission issues:
```bash
# Add your user to the audio and video groups
sudo usermod -a -G audio,video $USER

# Log out and log back in for changes to take effect
```

If hardware acceleration doesn't work:
```bash
# Check if VA-API is working
vainfo

# Check if VDPAU is working
vdpauinfo
```

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

Current version: 1.0.9

### What's New in 1.0.9
- **Package Improvements:**
  - Added Debian package (.deb) for easier installation on Debian/Ubuntu-based systems
  - Added RPM package (.rpm) for easier installation on Fedora/RHEL/CentOS-based systems
  - Improved package dependencies to ensure proper installation

- **Linux Enhancements:**
  - Fixed Linux dependencies for media playback
  - Added proper system integration with desktop entries and icons
  - Improved hardware acceleration support on various Linux distributions
  - Added comprehensive documentation for Linux dependencies

- **Media Playback:**
  - Updated media_kit dependencies to latest compatible versions
  - Fixed issue with libmpv.so.2 dependency on Linux systems
  - Improved video rendering performance on Linux

- **Documentation:**
  - Added detailed installation instructions for different Linux distributions
  - Added troubleshooting section for common installation issues
  - Updated build instructions to include creating .deb and .rpm packages

### What's New in 1.0.8
- Added keyboard shortcuts for play/pause using spacebar keys
- Various bug fixes and performance improvements

### What's New in 1.0.7
- Added keyboard shortcuts for 10-second jump forward/backward using left/right arrow keys
- Added mouse wheel support for volume control
- Bug fixes and performance improvements

### What's New in 1.0.6
- Fixed media playback restart issue when playing audio/video after completion
- Enhanced context menu in landscape mode to prevent overflow
- Improved folder browsing for all platforms (iOS, Android, Windows, macOS, Linux)
- Bug fixes and performance improvements
- set minSdk 21
