# Mojar Player

A modern media player app built with Flutter that supports both video and audio playback with a beautiful pink-themed UI.

## Features

- **Video & Audio Playback**: Supports common media formats
- **Custom Controls**: 
  - Play/Pause, Stop
  - Next/Previous track
  - 10 seconds forward/backward buttons
  - Seekbar with time display
  - Volume control
  - Playback speed control
  - Aspect ratio adjustment
  - Loop toggle
  - Playlist management
  - Screenshot functionality
- **Context Menu** (Right-click or long press):
  - Media info
  - Subtitle support (SRT, VTT, ASS, SSA formats)
  - Audio synchronization
  - Take screenshot
  - About page
- **Beautiful UI**:
  - Pink color theme
  - Modern, clean design
  - Dark mode support

## Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (latest stable version)
- Git
- Platform-specific requirements:
  - Windows: Visual Studio with C++ development tools
  - macOS: Xcode and CocoaPods

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/mojar_player_new.git
cd mojar_player_new
```

2. Install dependencies:
```bash
flutter pub get
```

## Building for Windows

1. Ensure you have the Windows development tools installed:
```bash
flutter doctor
```

2. Build the application:
```bash
flutter build windows
```

3. Run the application:
```bash
flutter run -d windows
```

The executable will be available at:
```
build/windows/runner/Release/mojar_player_new.exe
```

## Building for macOS

1. Install CocoaPods:
```bash
sudo gem install cocoapods
```

2. Install macOS dependencies:
```bash
cd macos
pod install
cd ..
```

3. Build the application:
```bash
flutter build macos
```

4. Run the application:
```bash
flutter run -d macos
```

The application will be available at:
```
build/macos/Build/Products/Release/mojar_player_new.app
```

## Usage

### Basic Controls
- Space: Play/Pause
- Right Arrow: Forward 10s
- Left Arrow: Backward 10s
- Up Arrow: Volume Up
- Down Arrow: Volume Down
- F11: Toggle Fullscreen
- N: Next Media
- P: Previous Media
- M: Toggle Mute
- O: Toggle Orientation
- A: Cycle Aspect Ratio
- I: Media Information
- Esc: Exit Fullscreen/Close Player

### Subtitle Support
1. Right-click or long-press to open the context menu
2. Select "Add Subtitles" to load a subtitle file
3. Supported formats: SRT, VTT, ASS, SSA
4. Use "Remove Subtitles" to disable them

### Playlist Management
- Add media files through the context menu
- Drag and drop files to add to playlist
- Right-click playlist items for more options
- Use shuffle and repeat controls at the bottom

## Troubleshooting

### Windows
- If you encounter permission issues, run the application as administrator
- Ensure all required Visual C++ redistributables are installed
- Check Windows Defender settings if files can't be accessed

### macOS
- If the app crashes on launch, check Console.app for error logs
- Ensure proper permissions are granted in System Preferences
- If video playback issues occur, check if codecs are properly installed

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the amazing framework
- All contributors and users of the application
- Open-source community for their valuable packages

## Contact

For any questions or support, please open an issue on GitHub or contact the maintainers.
