# Mojar Player Pro v1.0.7 Release Notes

## What's New in 1.0.7
- Fixed Linux media playback issues
- Added proper Linux dependency management for media_kit
- Added keyboard shortcuts for 10-second jump forward/backward using left/right arrow keys
- Added mouse wheel support for volume control
- Bug fixes and performance improvements

## Installation Instructions

### Ubuntu/Debian-based distributions (20.04+)

1. Download the .deb package:
   ```
   mojar-player-pro_1.0.7_amd64.deb
   ```

2. Install with:
   ```bash
   sudo apt-get update
   sudo apt-get install -y libmpv2 libgstreamer-plugins-base1.0-0
   sudo dpkg -i mojar-player-pro_1.0.7_amd64.deb
   ```

3. If there are any dependency issues, run:
   ```bash
   sudo apt-get install -f
   ```

4. Launch from your applications menu or run:
   ```bash
   mojar_player_pro
   ```

### Using the Installation Script

Alternatively, you can use the installation script:

1. Make it executable:
   ```bash
   chmod +x install.sh
   ```

2. Run it:
   ```bash
   sudo ./install.sh
   ```

## System Requirements

- Linux distribution: Ubuntu 20.04 or newer (or equivalent Debian-based distro)
- Architecture: x86_64 (64-bit)
- Display server: X11 or Wayland
- Dependencies: libmpv2, libgstreamer-plugins-base1.0-0

## Troubleshooting

If the application fails to start or has playback issues:

1. Make sure dependencies are installed:
   ```bash
   sudo apt-get install -y libmpv2 libmpv-dev libgstreamer-plugins-base1.0-0
   ```

2. For video/audio codec issues, install additional codecs:
   ```bash
   sudo apt-get install ubuntu-restricted-extras
   ```

3. If the app doesn't appear in menus, refresh the desktop database:
   ```bash
   sudo update-desktop-database
   ```

## Support

For issues and feedback, please visit:
https://github.com/mojarcoder/mojar-player-pro/issues

## License

This application is licensed under the MIT License. 