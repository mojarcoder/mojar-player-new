#include "flutter_window.h"

#include <optional>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::ToggleFullscreen() {
  if (is_fullscreen_) {
    return ExitFullscreen();
  } else {
    return EnterFullscreen();
  }
}

bool FlutterWindow::EnterFullscreen() {
  if (is_fullscreen_) {
    return true; // Already in fullscreen mode
  }

  HWND hwnd = GetHandle();
  if (!hwnd) {
    return false;
  }

  // Store current window info for restoration later
  windowed_style_ = GetWindowLong(hwnd, GWL_STYLE);
  windowed_ex_style_ = GetWindowLong(hwnd, GWL_EXSTYLE);
  GetWindowRect(hwnd, &windowed_rect_);

  // Get the nearest monitor
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info;
  monitor_info.cbSize = sizeof(MONITORINFO);
  GetMonitorInfo(monitor, &monitor_info);

  // Set fullscreen style (no border, etc.)
  SetWindowLong(hwnd, GWL_STYLE, windowed_style_ & ~(WS_CAPTION | WS_THICKFRAME));
  SetWindowLong(hwnd, GWL_EXSTYLE, windowed_ex_style_ &
                ~(WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE));

  // Set window to cover entire monitor
  SetWindowPos(hwnd, HWND_TOP,
               monitor_info.rcMonitor.left,
               monitor_info.rcMonitor.top,
               monitor_info.rcMonitor.right - monitor_info.rcMonitor.left,
               monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top,
               SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);

  is_fullscreen_ = true;
  return true;
}

bool FlutterWindow::ExitFullscreen() {
  if (!is_fullscreen_) {
    return true; // Already in windowed mode
  }

  HWND hwnd = GetHandle();
  if (!hwnd) {
    return false;
  }

  // Ensure we have valid windowed style values
  if (windowed_style_ == 0) {
    // Default style if we don't have stored values
    windowed_style_ = WS_OVERLAPPEDWINDOW;
  }

  // Restore the window style and position
  SetWindowLong(hwnd, GWL_STYLE, windowed_style_);
  SetWindowLong(hwnd, GWL_EXSTYLE, windowed_ex_style_);

  // Ensure we have valid window position
  if (windowed_rect_.right == 0 || windowed_rect_.bottom == 0) {
    // Use default size if we don't have stored values
    windowed_rect_.left = 100;
    windowed_rect_.top = 100;
    windowed_rect_.right = 1024 + windowed_rect_.left;
    windowed_rect_.bottom = 768 + windowed_rect_.top;
  }

  // Restore the window position and size
  SetWindowPos(hwnd, HWND_TOP,
               windowed_rect_.left,
               windowed_rect_.top,
               windowed_rect_.right - windowed_rect_.left,
               windowed_rect_.bottom - windowed_rect_.top,
               SWP_NOZORDER | SWP_FRAMECHANGED);

  // Force a redraw to ensure the window updates properly
  RedrawWindow(hwnd, NULL, NULL, RDW_INVALIDATE | RDW_UPDATENOW);

  // Set the flag after all operations are complete
  is_fullscreen_ = false;
  return true;
}

bool FlutterWindow::IsFullscreen() {
  return is_fullscreen_;
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Register method channel for platform integration
  auto channel =
      std::make_unique<flutter::MethodChannel<>>(
          flutter_controller_->engine()->messenger(),
          "com.mojarplayer.mojar_player_pro/system",
          &flutter::StandardMethodCodec::GetInstance());

  // Set up method call handler for fullscreen functions
  channel->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "enterFullscreen") {
          bool success = this->EnterFullscreen();
          result->Success(flutter::EncodableValue(success));
        } else if (call.method_name() == "exitFullscreen") {
          bool success = this->ExitFullscreen();
          result->Success(flutter::EncodableValue(success));
        } else if (call.method_name() == "toggleFullscreen") {
          bool success = this->ToggleFullscreen();
          result->Success(flutter::EncodableValue(success));
        } else if (call.method_name() == "isFullscreen") {
          bool is_full = this->IsFullscreen();
          result->Success(flutter::EncodableValue(is_full));
        } else if (call.method_name() == "ping") {
          result->Success(flutter::EncodableValue("pong"));
        } else {
          result->NotImplemented();
        }
      });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    // Handle F11 key press for fullscreen toggle
    case WM_KEYDOWN:
      if (wparam == VK_F11) {
        ToggleFullscreen();
        return 0;
      }
      // Handle ESC key press to exit fullscreen
      else if (wparam == VK_ESCAPE && is_fullscreen_) {
        ExitFullscreen();
        return 0;
      }
      break;
    // Handle double-click on title bar area for fullscreen toggle
    case WM_NCLBUTTONDBLCLK:
      if (HTCAPTION == wparam && is_fullscreen_) {
        ExitFullscreen();
        return 0;
      }
      break;
    // Handle double-click anywhere to exit fullscreen
    case WM_LBUTTONDBLCLK:
      if (is_fullscreen_) {
        ExitFullscreen();
        return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
