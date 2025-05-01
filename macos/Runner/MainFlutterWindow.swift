import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var methodChannel: FlutterMethodChannel?
  private var isInFullScreen = false
  
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    // Set up method channel for window controls
    setupMethodChannel(flutterViewController: flutterViewController)
    
    super.awakeFromNib()
  }
  
  private func setupMethodChannel(flutterViewController: FlutterViewController) {
    self.methodChannel = FlutterMethodChannel(
      name: "com.mojarplayer.mojar_player_pro/system",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    
    self.methodChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(FlutterError(code: "WINDOW_GONE", message: "Window was deallocated", details: nil))
        return
      }
      
      switch call.method {
      case "ping":
        result("pong")
        
      case "enterFullscreen":
        if !self.styleMask.contains(.fullScreen) {
          self.toggleFullScreen(nil)
          result(true)
        } else {
          result(true) // Already in fullscreen
        }
        
      case "exitFullscreen":
        if self.styleMask.contains(.fullScreen) {
          self.toggleFullScreen(nil)
          result(true)
        } else {
          result(true) // Already not in fullscreen
        }
        
      case "toggleFullscreen":
        self.toggleFullScreen(nil)
        result(true)
        
      case "isFullscreen":
        result(self.styleMask.contains(.fullScreen))
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
