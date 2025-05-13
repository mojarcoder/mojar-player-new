# 🚀 Mojar Player Pro v1.0.9 — Multi-Platform Release

Welcome to the **first official release** of **Mojar Player Pro** — a modern, pink-themed media player for **Windows**, **macOS**, **Linux**, and **Android**! 💖

🎬 Supports video + audio playback  
🎛️ Custom controls & playlist management  
🌓 Dark mode, screenshot, subtitle support & more!

---

## 📦 Downloads

### 🪟 Windows (Installer)
👉 [Download Mojar-Player-Pro-windows.exe](https://github.com/mojarcoder/mojar-player-pro/releases/download/v1.0.9/Mojar-Player-Pro-windows.exe)


### 🍎 macOS (App Bundle)
👉 [Download Mojar-player-pro-macOS.dmg](https://github.com/mojarcoder/mojar-player-pro/releases/download/v1.0.9/Mojar-player-pro-macOS.dmg)


### 🐧 Linux (DEB & AppImage)
👉 [Download MojarPlayerPro.deb](https://github.com/mojarcoder/mojar-player-pro/releases/download/v1.0.9/mojar-player-pro_1.0.8.deb)  
> 📌 .deb package for Ubuntu/Debian-based systems  
# Mojar Player Pro v1.0.9 Release

We're excited to announce the release of Mojar Player Pro v1.0.9, featuring improved Linux support, package distribution options, and various enhancements to the media playback experience.

![Mojar Player Pro](assets/images/mojar_icon.png)

## What's New in 1.0.9

### Package Improvements
- **Debian Package (.deb)**: Added proper Debian package for easier installation on Ubuntu, Debian, Linux Mint, Pop!_OS, and other Debian-based distributions
- **RPM Package (.rpm)**: Added RPM package for easier installation on Fedora, RHEL, CentOS, and other RPM-based distributions
- **Improved Dependencies**: Enhanced package dependency management to ensure proper installation
- **Fixed Launcher Script**: Corrected launcher script to properly reference the executable name

### Linux Enhancements
- **Fixed Dependencies**: Resolved issues with Linux dependencies for media playback
- **System Integration**: Added proper system integration with desktop entries and icons
- **Hardware Acceleration**: Improved hardware acceleration support on various Linux distributions
- **Comprehensive Documentation**: Added detailed documentation for Linux dependencies

### Media Playback
- **Updated Dependencies**: Updated media_kit dependencies to latest compatible versions
- **Fixed libmpv.so.2 Issue**: Resolved dependency issues with libmpv.so.2 on Linux systems
- **Performance Improvements**: Enhanced video rendering performance on Linux

### Documentation
- **Installation Instructions**: Added detailed installation instructions for different Linux distributions
- **Troubleshooting Guide**: Added troubleshooting section for common installation issues
- **Build Instructions**: Updated build instructions to include creating .deb and .rpm packages

## Installation

### System Requirements

- **Linux**: Ubuntu 20.04+, Fedora 35+, or other modern Linux distributions
- **Architecture**: x86_64 (64-bit)
- **Display Server**: X11 or Wayland
- **Dependencies**: libmpv, mpv (specific packages vary by distribution)

### Installing on Debian/Ubuntu-based Systems

1. Download the `.deb` package:
   ```
   mojar-player-pro_1.0.9_amd64.deb
   ```

2. Install required dependencies:
   ```bash
   sudo apt install libmpv-dev mpv
   ```

3. Install the package:
   ```bash
   sudo apt install ./mojar-player-pro_1.0.9_amd64.deb
   ```

4. Launch from your applications menu or run:
   ```bash
   mojar-player-pro
   ```

### Installing on Fedora/RHEL-based Systems

1. Download the `.rpm` package:
   ```
   mojar-player-pro-1.0.9-2.x86_64.rpm
   ```

2. Install required dependencies:
   ```bash
   # For Fedora
   sudo dnf install mpv mpv-libs-devel
   
   # For RHEL/CentOS
   sudo yum install epel-release
   sudo yum install mpv mpv-libs-devel
   ```

3. Install the package:
   ```bash
   # For Fedora
   sudo dnf install ./mojar-player-pro-1.0.9-2.x86_64.rpm
   
   # For RHEL/CentOS
   sudo yum install ./mojar-player-pro-1.0.9-2.x86_64.rpm
   ```

4. Launch from your applications menu or run:
   ```bash
   mojar-player-pro
   ```

## Troubleshooting

### Application Doesn't Launch After Installation

If the application doesn't launch after installing the .deb or .rpm package:

1. Check if the executable name matches in the launcher script:
   ```bash
   # Check the executable name in the installation directory
   ls -la /usr/local/lib/mojar-player-pro/
   
   # Check the launcher script
   cat /usr/local/bin/mojar-player-pro
   ```

2. Make sure the launcher script is using the correct executable name:
   ```bash
   # Edit the launcher script if needed
   sudo nano /usr/local/bin/mojar-player-pro
   
   # Make sure it contains the correct executable name:
   # ./mojar-player-pro instead of ./mojar_player_pro
   ```

3. Make sure the launcher script is executable:
   ```bash
   sudo chmod +x /usr/local/bin/mojar-player-pro
   ```

### Missing libmpv.so.2

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

### Video Playback Issues

If you experience video playback issues:

```bash
# For Debian/Ubuntu
sudo apt install ffmpeg libavcodec-extra

# For Fedora/RHEL/CentOS
sudo dnf install ffmpeg  # or sudo yum install ffmpeg

# For Arch Linux
sudo pacman -S ffmpeg
```

## Hardware Acceleration

For optimal performance, ensure hardware acceleration is properly configured:

### For Intel GPUs:
```bash
sudo apt install vainfo intel-media-va-driver
```

### For AMD GPUs:
```bash
sudo apt install vainfo mesa-va-drivers
```

### For NVIDIA GPUs:
```bash
sudo apt install vdpauinfo mesa-vdpau-drivers
```

## Known Issues

- Hardware acceleration may not work on some older graphics cards
- Some rare video codecs may require additional packages to be installed
- Desktop integration may vary slightly between different Linux desktop environments

## Feedback and Support

We value your feedback! If you encounter any issues or have suggestions for improvements, please:

1. Check the [troubleshooting section](#troubleshooting) above
2. Visit our [GitHub Issues page](https://github.com/mojarcoder/mojar-player-pro/issues) to report bugs or request features
3. Join our community forum for discussions and support

## License

Mojar Player Pro is licensed under the MIT License.

---

Thank you for using Mojar Player Pro!

### 🤖 Android (APK)
👉 [Download MojarPlayerPro-Android.apk](https://github.com/mojarcoder/mojar-player-pro/releases/download/v1.0.9/mojar-player-pro-android.apk)

> 📌 Enable "Install unknown apps" in Android settings before installing.  
> Compatible with Android 5.0+.

---

## 🛠 Installation Instructions

### Windows
1. Download the `.exe` file.
2. Run the installer and follow the steps.
3. Use the app from Start Menu or Desktop.

### macOS
1. Download and open the `.dmg` file.
2. Right-click on `Mojar Player Pro.app` → "Open".
3. Allow security prompt if needed.
4. Enjoy the app from Launchpad or Applications.

### Linux (DEB Package)
1. Download the `.deb` file
2. Install using terminal:
   ```bash
   sudo apt install ./mojar-player-pro_1.0.8.deb
   ```
   Or double-click to install with Software Center!

### Linux (AppImage)
1. Download the `.AppImage` file
2. Make it executable:
   ```bash
   chmod +x mojar_player_pro.AppImage
   ```
3. Double-click to run or use terminal:
   ```bash
   ./mojar_player_pro.AppImage
   ```

### Android
1. Download the `.apk` file to your phone.
2. Tap to install (allow from unknown sources).
3. Launch the app and enjoy!

---

## 🎮 Controls (All Platforms)

- ⏯️ Space: Play/Pause  
- ⏩ Right Arrow: Forward 10s  
- ⏪ Left Arrow: Backward 10s  
- 🔊 Up/Down Arrows: Volume  
- 🖥️ F11: Fullscreen  
- 🔁 N/P: Next/Previous  
- 🔇 M: Mute  
- 🖼️ A: Change Aspect Ratio  
- 📝 I: Media Info  
- ⛔ Esc: Exit Fullscreen or Close

---

## 🧠 Features

- Custom playback speed  
- Loop toggle  
- Screenshot button  
- Subtitle support (.srt, .vtt, .ass, .ssa)  
- Playlist drag & drop  
- Right-click context menu  
- Clean pink UI with dark mode!
- Hardware acceleration support
- Cross-platform compatibility

---

## 📞 Support

- 📧 Email: [mojarcoder@gmail.com](mailto:mojarcoder@gmail.com)  
- 🐛 Report Issues: [GitHub Issues](https://github.com/mojarcoder/mojar-player-pro/issues)  
- 💬 WhatsApp: [Click to Chat](https://wa.me/8801640641524)

---

## 🧑‍💻 Want to Contribute?

1. Fork the repo  
2. `git checkout -b feature/your-feature`  
3. Make changes, commit, push  
4. Open a Pull Request 🚀

---
## 🆕 What's New in v1.0.9
 - ✅ Play/pause with spacebar

## 🆕 What's New in v1.0.8

- 🎵 Fixed media playback restart issue
- 📱 Enhanced context menu in landscape mode
- 📂 Improved folder browsing across all platforms
- 🐛 Various bug fixes and performance improvements
- 🚀 Added Linux support with .deb and AppImage packages
- 💻 Hardware acceleration improvements
- 🎨 UI/UX enhancements
- ✅ Full screen mode
- ✅ Assets Protection

---

Thanks for supporting **Mojar Player Pro**!  
🎉 Enjoy smooth media playback on all your devices!

**Full Changelog**: https://github.com/mojarcoder/mojar-player-pro/compare/v1.0.0...v1.0.6 