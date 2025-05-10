#!/bin/bash
set -e

echo "Building .deb package for Mojar Player Pro"

# Version
VERSION="1.0.9"

# Create package directory structure
echo "Creating package directory structure..."
mkdir -p build/linux_package/DEBIAN
mkdir -p build/linux_package/usr/local/bin
mkdir -p build/linux_package/usr/local/lib/mojar-player-pro
mkdir -p build/linux_package/usr/share/applications
mkdir -p build/linux_package/usr/share/pixmaps

# Create control file
echo "Creating control file..."
cat > build/linux_package/DEBIAN/control << EOF
Package: mojar-player-pro
Version: $VERSION
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

# Create post-installation script
echo "Creating post-installation script..."
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

# Create desktop entry
echo "Creating desktop entry..."
cat > build/linux_package/usr/share/applications/mojar-player-pro.desktop << EOF
[Desktop Entry]
Type=Application
Name=Mojar Player Pro
Comment=Professional Media Player
Exec=mojar-player-pro
Icon=mojar-player-pro
Categories=AudioVideo;Player;Video;Audio;
Terminal=false
StartupNotify=true
MimeType=video/x-matroska;video/mp4;video/webm;video/quicktime;video/x-msvideo;video/x-flv;video/x-ms-wmv;audio/mpeg;audio/x-wav;audio/x-flac;
EOF

# Copy application icon
echo "Copying application icon..."
cp assets/images/mojar_icon.png build/linux_package/usr/share/pixmaps/mojar-player-pro.png

# Create wrapper script
echo "Creating wrapper script..."
cat > build/linux_package/usr/local/bin/mojar-player-pro << EOF
#!/bin/sh
exec /usr/local/lib/mojar-player-pro/mojar-player-pro "\$@"
EOF
chmod 755 build/linux_package/usr/local/bin/mojar-player-pro

# Copy the built application from bundle
echo "Copying application files from bundle..."
cp -r build/linux/x64/release/bundle/* build/linux_package/usr/local/lib/mojar-player-pro/

# Build the .deb package
echo "Building .deb package..."
dpkg-deb --build build/linux_package build/mojar-player-pro_${VERSION}_amd64.deb

# Verify the package
echo "Verifying package..."
dpkg-deb -I build/mojar-player-pro_${VERSION}_amd64.deb

echo "Package created at: build/mojar-player-pro_${VERSION}_amd64.deb"
