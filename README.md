# zig-webview

Zig bindings for [webview/webview](https://github.com/webview/webview) — a tiny cross-platform library for building desktop applications with web technologies using a native browser widget.

Also includes cross-platform [window control](#window-control-methods) such as maximize, minimize, fullscreen, hide/show and state queries.

Idiomatic Zig API featuring error unions and comptime-powered typed callbacks.

## Requirements

Minimum Zig version: **0.15.2**.

For platform-specific requirements (WebKitGTK, WebView2, etc.), refer to the [webview/webview](https://github.com/webview/webview) documentation.

## Installation

Run the following command in your project directory to add the dependency:

```sh
zig fetch --save=webview git+https://github.com/happystraw/zig-webview
```

Then import the module in `build.zig`:

```zig
const webview_dep = b.dependency("webview", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("webview", webview_dep.module("webview"));
```

## Quick Start

```zig
const Webview = @import("webview").Webview;

pub fn main() !void {
    const w = try Webview.create(false, null);
    defer w.destroy() catch unreachable;
    try w.setTitle("Hello");
    try w.setSize(800, 600, .none);
    try w.setHtml("Thanks for using webview!");
    try w.run();
}
```

## Examples

| Example | Description |
|---------|-------------|
| [basic](examples/basic.zig) | Minimal window that loads an HTML string |
| [bind](examples/bind.zig) | Counter and async compute demo using JS ↔ Zig bindings via `bind` / `respond` |
| [window](examples/window.zig) | Window state controls demo (maximize, minimize, fullscreen, hide/show) |
| [skeleton](examples/skeleton/) | Project template with a Zig backend and a TypeScript frontend bundled by Bun |

Build and run the bundled examples with:

```sh
zig build examples
./zig-out/bin/basic
./zig-out/bin/bind
./zig-out/bin/window
```

## Cross-compilation

Cross-compilation to macOS and Windows is supported.

**Targeting macOS**

Obtain a macOS SDK (e.g. via [macosx-sdks](https://github.com/joseluisq/macosx-sdks)) and pass its path with `-Dmacos-sdk`:

```sh
zig build examples -Dtarget=aarch64-macos -Dmacos-sdk=/path/to/MacOSX.sdk
# or for x86_64
zig build examples -Dtarget=x86_64-macos -Dmacos-sdk=/path/to/MacOSX.sdk
```

**Targeting Windows**

The required WebView2 headers are already bundled in `deps/WebView2/`, so no extra setup is needed:

```sh
zig build examples -Dtarget=x86_64-windows
```

## C API to Zig API Mapping

| C Function | Zig Method |
|---|---|
| `webview_create(debug, window)` | `Webview.create(debug, window) !*Webview` |
| `webview_destroy(w)` | `w.destroy() !void` |
| `webview_run(w)` | `w.run() !void` |
| `webview_terminate(w)` | `w.terminate() !void` |
| `webview_dispatch(w, fn, arg)` | `w.dispatchRaw(callback, arg) !void` |
| `webview_dispatch(w, fn, arg)` | `w.dispatch(T, callback, arg) !void` |
| `webview_dispatch(w, fn, null)` | `w.dispatchSimple(callback) !void` |
| `webview_get_window(w)` | `w.getWindow() ?*anyopaque` |
| `webview_get_native_handle(w, kind)` | `w.getNativeHandle(kind) ?*anyopaque` |
| `webview_set_title(w, title)` | `w.setTitle(title) !void` |
| `webview_set_size(w, width, height, hint)` | `w.setSize(width, height, hint) !void` |
| `webview_navigate(w, url)` | `w.navigate(url) !void` |
| `webview_set_html(w, html)` | `w.setHtml(html) !void` |
| `webview_init(w, js)` | `w.addInitScript(js) !void` |
| `webview_eval(w, js)` | `w.eval(js) !void` |
| `webview_bind(w, name, fn, arg)` | `w.bindRaw(name, callback, arg) !void` |
| `webview_bind(w, name, fn, arg)` | `w.bind(T, name, callback, arg) !void` |
| `webview_bind(w, name, fn, null)` | `w.bindSimple(name, callback) !void` |
| `webview_unbind(w, name)` | `w.unbind(name) !void` |
| `webview_return(w, id, status, result)` | `w.respond(id, status, result) !void` |
| — | `w.respondOk(id) !void` |
| — | `w.respondError(id, err) !void` |
| `webview_version()` | `Webview.version() Version` |

## Window Control Methods

| Method | Description |
|--------|-------------|
| `w.maximize() !void` | Maximize the window |
| `w.unmaximize() !void` | Restore the window from maximized state |
| `w.minimize() !void` | Minimize the window |
| `w.unminimize() !void` | Restore the window from minimized state |
| `w.fullscreen() !void` | Enter fullscreen mode |
| `w.unfullscreen() !void` | Exit fullscreen mode |
| `w.hide() !void` | Hide the window |
| `w.show() !void` | Show the window |
| `w.isMaximized() !bool` | Query whether the window is maximized |
| `w.isMinimized() !bool` | Query whether the window is minimized |
| `w.isFullscreen() !bool` | Query whether the window is in fullscreen mode |
| `w.isVisible() !bool` | Query whether the window is visible |
