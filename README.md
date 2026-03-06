# zig-webview

Zig bindings for [webview/webview](https://github.com/webview/webview) — a tiny cross-platform library for building desktop applications with web technologies using a native browser widget.

Zig API with error unions, comptime-powered typed callbacks, and JS ↔ Zig bindings via `bind` / `respond`.

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
    try w.navigate("https://example.com");
    try w.run();
}
```

## Examples

| Example | Description |
|---------|-------------|
| [basic](examples/basic.zig) | Minimal window that loads an HTML string |
| [bind](examples/bind.zig) | Counter and async compute demo using JS ↔ Zig bindings via `bind` / `respond` |

Build and run the bundled examples with:

```sh
zig build examples
./zig-out/bin/basic
./zig-out/bin/bind
```

## Cross-compilation

Cross-compilation to macOS and Windows is supported.

**Targeting macOS**

Obtain a macOS SDK (e.g. via [macosx-sdks](https://github.com/joseluisq/macosx-sdks)) and pass its path with `-Dmacos-sdk`:

```sh
zig build -Dtarget=aarch64-macos -Dmacos-sdk=/path/to/MacOSX.sdk
# or for x86_64
zig build -Dtarget=x86_64-macos -Dmacos-sdk=/path/to/MacOSX.sdk
```

**Targeting Windows**

The required WebView2 headers are already bundled in `deps/WebView2/`, so no extra setup is needed:

```sh
zig build -Dtarget=x86_64-windows
```
