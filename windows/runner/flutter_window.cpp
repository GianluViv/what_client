#include "flutter_window.h"

#include <tlhelp32.h>

#include <optional>
#include <unordered_set>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Timer used to keep the WebView2 surface window click-through.
constexpr UINT_PTR kWebviewClickThroughTimerId = 1001;

// Collects every process id that descends (directly or indirectly) from
// |root_pid|. WebView2 runs in separate msedgewebview2.exe processes that are
// children of our process, so this lets us target only our own WebView2 windows
// and never touch windows belonging to other apps (Chrome, VS Code, ...).
std::unordered_set<DWORD> CollectDescendantPids(DWORD root_pid) {
  std::unordered_set<DWORD> descendants;

  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) {
    return descendants;
  }

  std::vector<std::pair<DWORD, DWORD>> edges;  // (pid, parent_pid)
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  if (Process32FirstW(snapshot, &entry)) {
    do {
      edges.emplace_back(entry.th32ProcessID, entry.th32ParentProcessID);
    } while (Process32NextW(snapshot, &entry));
  }
  CloseHandle(snapshot);

  std::unordered_set<DWORD> reachable = {root_pid};
  bool changed = true;
  while (changed) {
    changed = false;
    for (const auto& edge : edges) {
      if (reachable.count(edge.second) && !reachable.count(edge.first)) {
        reachable.insert(edge.first);
        descendants.insert(edge.first);
        changed = true;
      }
    }
  }
  return descendants;
}

BOOL CALLBACK PatchWebviewWindowProc(HWND hwnd, LPARAM lparam) {
  const auto* pids = reinterpret_cast<const std::unordered_set<DWORD>*>(lparam);

  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  if (pids->count(pid) == 0) {
    return TRUE;
  }

  wchar_t class_name[64];
  if (GetClassNameW(hwnd, class_name, ARRAYSIZE(class_name)) == 0) {
    return TRUE;
  }
  // WebView2's host/infrastructure window.
  if (wcsncmp(class_name, L"Chrome_WidgetWin", 16) != 0) {
    return TRUE;
  }
  // Only the top-level surface window leaks over the desktop; its children are
  // already click-through.
  if (GetParent(hwnd) != nullptr) {
    return TRUE;
  }

  LONG ex_style = GetWindowLong(hwnd, GWL_EXSTYLE);
  // Target only the layered surface window, and skip if already click-through.
  if (!(ex_style & WS_EX_LAYERED) || (ex_style & WS_EX_TRANSPARENT)) {
    return TRUE;
  }

  // Make the stray WebView2 surface window pass mouse events through so it no
  // longer swallows clicks (e.g. the desktop right-click context menu). This
  // does not change its size/position, so WhatsApp keeps rendering normally,
  // and the style survives the plugin's own resize calls.
  SetWindowLong(hwnd, GWL_EXSTYLE, ex_style | WS_EX_TRANSPARENT);
  return TRUE;
}

void MakeWebviewSurfaceClickThrough() {
  std::unordered_set<DWORD> pids = CollectDescendantPids(GetCurrentProcessId());
  if (pids.empty()) {
    return;
  }
  EnumWindows(PatchWebviewWindowProc, reinterpret_cast<LPARAM>(&pids));
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

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

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  // WebView2 renders WhatsApp off-screen into a texture, but on some machines it
  // still leaks a visible top-level layered window over the desktop that
  // swallows clicks (notably the desktop right-click menu). Poll periodically
  // and make that window click-through. A timer is needed because the WebView2
  // window is created asynchronously after startup and may be recreated.
  SetTimer(GetHandle(), kWebviewClickThroughTimerId, 1000, nullptr);

  return true;
}

void FlutterWindow::OnDestroy() {
  KillTimer(GetHandle(), kWebviewClickThroughTimerId);

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
    case WM_TIMER:
      if (wparam == kWebviewClickThroughTimerId) {
        MakeWebviewSurfaceClickThrough();
        return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
