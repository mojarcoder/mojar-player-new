#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Fullscreen functions
  bool ToggleFullscreen();
  bool EnterFullscreen();
  bool ExitFullscreen();
  bool IsFullscreen();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Fullscreen tracking
  bool is_fullscreen_ = false;
  RECT windowed_rect_; // Store window position/size when switching to fullscreen
  LONG windowed_style_ = 0; // Store window style when switching to fullscreen
  LONG windowed_ex_style_ = 0; // Store window extended style when switching
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
