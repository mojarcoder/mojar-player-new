import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  // Register for F11 and F key events to toggle fullscreen
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      // F11 key code is 103, F key code is 3
      if event.keyCode == 103 || (event.keyCode == 3 && event.modifierFlags.isEmpty) {
        if let window = NSApp.mainWindow {
          window.toggleFullScreen(nil)
          return nil // Consume the event
        }
      }
      return event
    }
  }
}
