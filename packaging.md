# Building Packages for Mojar Player Pro

This document outlines the process of building installation packages for Mojar Player Pro.

## Building the .deb Package

The Debian package (.deb) is created for use on Debian, Ubuntu, and related distributions.

### Prerequisites

- Debian-based Linux distribution (e.g., Ubuntu, Debian)
- `dpkg-deb` tool (standard on Debian systems)
- Flutter SDK

### Build Steps

1. Build the Flutter Linux release:
   ```bash
   flutter build linux --release
   ```

2. Create the package directory structure:
   ```bash
   mkdir -p build/linux_package/DEBIAN
   mkdir -p build/linux_package/usr/local/bin
   mkdir -p build/linux_package/usr/local/lib/mojar_player_pro
   mkdir -p build/linux_package/usr/share/applications
   mkdir -p build/linux_package/usr/share/pixmaps
   ```

3. Create the control file:
   ```bash
   cat > build/linux_package/DEBIAN/control << EOF
   Package: mojar-player-pro
   Version: 1.0.7
   Section: multimedia
   Priority: optional
   Architecture: amd64
   Depends: libc6, libgtk-3-0, libmpv2, libgstreamer-plugins-base1.0-0
   Maintainer: Mojar Coder <mojarcoder@gmail.com>
   Description: Mojar Player Pro
    A professional media player with modern interface and advanced playback
    capabilities. Full support for various media formats, hardware-accelerated
    video playback, and features like playlist management, subtitle support,
    and multiple audio track selection.
   EOF
   ```

4. Create the post-installation script:
   ```bash
   cat > build/linux_package/DEBIAN/postinst << EOF
   #!/bin/bash
   set -e
   
   # Update icon cache
   if [ -d /usr/share/icons/hicolor ]; then
     if which gtk-update-icon-cache >/dev/null 2>&1; then
       gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1
     fi
   fi
   
   # Update desktop database
   if which update-desktop-database >/dev/null 2>&1; then
     update-desktop-database -q
   fi
   
   exit 0
   EOF
   chmod 755 build/linux_package/DEBIAN/postinst
   ```

5. Create desktop entry:
   ```bash
   cat > build/linux_package/usr/share/applications/mojar-player-pro.desktop << EOF
   [Desktop Entry]
   Type=Application
   Name=Mojar Player Pro
   Comment=Professional Media Player
   Exec=mojar_player_pro
   Icon=mojar-player-pro
   Categories=AudioVideo;Player;Video;Audio;
   Terminal=false
   StartupNotify=true
   MimeType=video/x-matroska;video/mp4;video/webm;video/quicktime;video/x-msvideo;video/x-flv;video/x-ms-wmv;audio/mpeg;audio/x-wav;audio/x-flac;
   EOF
   ```

6. Copy the application icon:
   ```bash
   cp assets/images/mojar_icon.png build/linux_package/usr/share/pixmaps/mojar-player-pro.png
   ```

7. Create wrapper script:
   ```bash
   cat > build/linux_package/usr/local/bin/mojar_player_pro << EOF
   #!/bin/sh
   exec /usr/local/lib/mojar_player_pro/mojar_player_pro "\$@"
   EOF
   chmod 755 build/linux_package/usr/local/bin/mojar_player_pro
   ```

8. Copy the built application:
   ```bash
   cp -r build/linux/x64/release/bundle/* build/linux_package/usr/local/lib/mojar_player_pro/
   ```

9. Build the .deb package:
   ```bash
   dpkg-deb --build build/linux_package build/mojar-player-pro_1.0.7_amd64.deb
   ```

10. Verify the package:
    ```bash
    dpkg-deb -I build/mojar-player-pro_1.0.7_amd64.deb
    ```

## Installation

### Using the .deb Package

The .deb package can be installed using:

```bash
sudo dpkg -i mojar-player-pro_1.0.7_amd64.deb
sudo apt-get install -f  # Install any missing dependencies
```

### Using the installation script

For convenience, an installation script is provided:

```bash
sudo ./install.sh
```

## Troubleshooting

- If the application fails to start due to missing libraries, try:
  ```bash
  sudo apt-get install -f
  ```

- If "libmpv" is missing:
  ```bash
  sudo apt install libmpv2 libmpv-dev
  ```

- For missing icon display issues:
  ```bash
  sudo gtk-update-icon-cache -f /usr/share/icons/hicolor
  ``` 