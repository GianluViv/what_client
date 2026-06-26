#include "flutter_window.h"

#include <winternl.h>  // PEB / RTL_USER_PROCESS_PARAMETERS / NtQueryInformationProcess

#include <fstream>
#include <optional>
#include <string>
#include <unordered_map>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Timer used to keep the WebView2 surface windows click-through.
constexpr UINT_PTR kWebviewClickThroughTimerId = 1001;

// Substring (case-insensitive) that uniquely identifies THIS app's WebView2
// processes via their command line. The webview_windows plugin gives every
// WebView2 process a user-data-dir of the form
//   ...\flutter_webview_windows\<app-name>\EBWebView
// so this never matches other apps' WebView2 processes (Teams, Search, ...).
constexpr wchar_t kWebviewUserDataMarker[] = L"flutter_webview_windows\\what_client";

// Reads the full command line of another process by walking its PEB. Returns an
// empty string on any failure (e.g. insufficient rights). This is how we tell
// *our* WebView2 processes apart from every other app's: WebView2 launches its
// msedgewebview2.exe via a broker that exits, so those processes are orphaned
// (their parent PID no longer exists) and can NOT be found by walking our own
// process tree — the command line is the only reliable signal.
std::wstring GetProcessCommandLine(DWORD pid) {
  std::wstring result;

  HANDLE process = OpenProcess(
      PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
  if (!process) {
    return result;
  }

  using NtQip_t = NTSTATUS(NTAPI*)(HANDLE, UINT, PVOID, ULONG, PULONG);
  static const auto NtQip = reinterpret_cast<NtQip_t>(GetProcAddress(
      GetModuleHandleW(L"ntdll.dll"), "NtQueryInformationProcess"));
  if (NtQip) {
    PROCESS_BASIC_INFORMATION pbi{};
    if (NtQip(process, 0 /*ProcessBasicInformation*/, &pbi, sizeof(pbi),
              nullptr) == 0 &&
        pbi.PebBaseAddress) {
      PEB peb{};
      if (ReadProcessMemory(process, pbi.PebBaseAddress, &peb, sizeof(peb),
                            nullptr) &&
          peb.ProcessParameters) {
        RTL_USER_PROCESS_PARAMETERS params{};
        if (ReadProcessMemory(process, peb.ProcessParameters, &params,
                              sizeof(params), nullptr) &&
            params.CommandLine.Buffer && params.CommandLine.Length > 0) {
          std::wstring buffer(params.CommandLine.Length / sizeof(wchar_t),
                              L'\0');
          if (ReadProcessMemory(process, params.CommandLine.Buffer, &buffer[0],
                                params.CommandLine.Length, nullptr)) {
            result = std::move(buffer);
          }
        }
      }
    }
  }

  CloseHandle(process);
  return result;
}

// Per-pid cache so we read each WebView2 process's command line only once
// instead of on every timer tick. Maps pid -> is-one-of-ours.
struct PatchContext {
  std::unordered_map<DWORD, bool>* ours_cache;
  std::wofstream* log;  // optional diagnostic
};

bool ProcessIsOurs(DWORD pid, std::unordered_map<DWORD, bool>* cache) {
  auto it = cache->find(pid);
  if (it != cache->end()) {
    return it->second;
  }
  const std::wstring cmd = GetProcessCommandLine(pid);
  const bool ours = !cmd.empty() && cmd.find(kWebviewUserDataMarker) != std::wstring::npos;
  (*cache)[pid] = ours;
  return ours;
}

BOOL CALLBACK PatchWebviewWindowProc(HWND hwnd, LPARAM lparam) {
  auto* ctx = reinterpret_cast<PatchContext*>(lparam);

  wchar_t class_name[64];
  if (GetClassNameW(hwnd, class_name, ARRAYSIZE(class_name)) == 0) {
    return TRUE;
  }
  // WebView2's host/surface windows are Chromium widgets.
  if (wcsncmp(class_name, L"Chrome_WidgetWin", 16) != 0) {
    return TRUE;
  }

  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  if (!ProcessIsOurs(pid, ctx->ours_cache)) {
    return TRUE;
  }

  LONG style = GetWindowLong(hwnd, GWL_EXSTYLE);

  if (ctx->log && ctx->log->is_open()) {
    RECT r{};
    GetWindowRect(hwnd, &r);
    *ctx->log << L"match hwnd=" << reinterpret_cast<uintptr_t>(hwnd)
              << L" pid=" << pid << L" class=" << class_name
              << L" exstyle=0x" << std::hex << style << std::dec
              << L" rect=(" << r.left << L"," << r.top << L"," << r.right
              << L"," << r.bottom << L")\n";
  }

  // Already click-through — nothing to do.
  if ((style & WS_EX_TRANSPARENT) && (style & WS_EX_LAYERED)) {
    return TRUE;
  }

  // Make the WebView2 window pass mouse events through so it can never swallow
  // clicks (e.g. the desktop right-click menu) when it is left sitting over the
  // desktop — which happens because these are top-level windows with no owner,
  // so they do not hide together with the Flutter window. WS_EX_LAYERED is
  // required for the click-through to reach windows of other processes (the
  // desktop belongs to explorer.exe); WS_EX_NOACTIVATE keeps it from stealing
  // focus. WebView2 already ships its visible content window with these exact
  // styles, so this is the WebView2-blessed, render-safe configuration — it does
  // not change size/position and does not affect WhatsApp's own input, which is
  // delivered through WebView2's composition path, not this window's hit-testing.
  const bool was_layered = (style & WS_EX_LAYERED) != 0;
  SetWindowLong(hwnd, GWL_EXSTYLE,
                style | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_NOACTIVATE);
  if (!was_layered) {
    // Keep it fully opaque (alpha 255) so adding the layered style is visually
    // a no-op for any window that was still on-screen.
    SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA);
  }
  return TRUE;
}

void MakeWebviewSurfaceClickThrough() {
  // Cache survives across ticks: reading a process command line is relatively
  // expensive and a pid's identity never changes.
  static std::unordered_map<DWORD, bool> ours_cache;

  // Lightweight diagnostic, rewritten each tick, in a guaranteed-writable spot
  // (the app cannot write to a drive root). Inspect it if this ever regresses.
  std::wofstream log;
  wchar_t temp_path[MAX_PATH];
  if (GetTempPathW(ARRAYSIZE(temp_path), temp_path) > 0) {
    std::wstring path(temp_path);
    path += L"what_client_webview_windows.log";
    log.open(path, std::ios::out | std::ios::trunc);
  }

  PatchContext ctx{&ours_cache, log.is_open() ? &log : nullptr};
  EnumWindows(PatchWebviewWindowProc, reinterpret_cast<LPARAM>(&ctx));
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

  // WebView2 leaks top-level windows that can sit over the desktop and swallow
  // clicks (notably the desktop right-click menu). Poll periodically and make
  // our WebView2 windows click-through. A timer is needed because those windows
  // are created asynchronously after startup and may be recreated.
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
