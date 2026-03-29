const std = @import("std");
const Webview = @import("webview").Webview;

const html: [:0]const u8 =
    \\<style>
    \\  body { font-family: sans-serif; padding: 20px; }
    \\  button { margin: 4px; padding: 6px 12px; }
    \\</style>
    \\<h3>Window Controls</h3>
    \\<div>
    \\  <button onclick="maximize()">Maximize</button>
    \\  <button onclick="unmaximize()">Restore</button>
    \\  <button onclick="minimize()">Minimize</button>
    \\  <button onclick="minimizeAndRestore()">Minimize (3s)</button>
    \\  <button onclick="fullscreen()">Fullscreen</button>
    \\  <button onclick="unfullscreen()">Exit Fullscreen</button>
    \\  <button onclick="hideAndShow()">Hide (3s)</button>
    \\  <button onclick="queryState()">Query State</button>
    \\</div>
    \\<pre id="state"></pre>
    \\<script>
    \\  async function hideAndShow() {
    \\    await hide();
    \\    setTimeout(() => show(), 3000);
    \\  }
    \\  async function minimizeAndRestore() {
    \\    await minimize();
    \\    setTimeout(() => unminimize(), 3000);
    \\  }
    \\  async function queryState() {
    \\    const s = await getState();
    \\    document.getElementById("state").textContent =
    \\      `maximized: ${s.maximized}\nminimized: ${s.minimized}\nfullscreen: ${s.fullscreen}\nvisible: ${s.visible}`;
    \\  }
    \\</script>
;

const Easy = Webview.Easy(Context);

const Context = struct {
    pub fn maximize(_: *Context, req: Easy.Request) !void {
        try req.easy.maximize();
        req.resolve();
    }
    pub fn unmaximize(_: *Context, req: Easy.Request) !void {
        try req.easy.unmaximize();
        req.resolve();
    }
    pub fn minimize(_: *Context, req: Easy.Request) !void {
        try req.easy.minimize();
        req.resolve();
    }
    pub fn unminimize(_: *Context, req: Easy.Request) !void {
        try req.easy.unminimize();
        req.resolve();
    }
    pub fn fullscreen(_: *Context, req: Easy.Request) !void {
        try req.easy.fullscreen();
        req.resolve();
    }
    pub fn unfullscreen(_: *Context, req: Easy.Request) !void {
        try req.easy.unfullscreen();
        req.resolve();
    }
    pub fn hide(_: *Context, req: Easy.Request) !void {
        try req.easy.hide();
        req.resolve();
    }
    pub fn show(_: *Context, req: Easy.Request) !void {
        try req.easy.show();
        req.resolve();
    }
    pub fn getState(_: *Context, req: Easy.Request) !void {
        const maximized = try req.easy.isMaximized();
        const minimized = try req.easy.isMinimized();
        const fs = try req.easy.isFullscreen();
        const visible = try req.easy.isVisible();
        var buf: [128]u8 = undefined;
        const result = try std.fmt.bufPrintZ(&buf,
            \\{{"maximized":{s},"minimized":{s},"fullscreen":{s},"visible":{s}}}
        , .{
            if (maximized) "true" else "false",
            if (minimized) "true" else "false",
            if (fs) "true" else "false",
            if (visible) "true" else "false",
        });
        req.resolveWith(result);
    }
};

pub fn main() !void {
    var ctx: Context = .{};
    var easy: Easy = try .init(&ctx, .debug);
    defer easy.deinit();

    try easy.bind(.maximize);
    try easy.bind(.unmaximize);
    try easy.bind(.minimize);
    try easy.bind(.unminimize);
    try easy.bind(.fullscreen);
    try easy.bind(.unfullscreen);
    try easy.bind(.hide);
    try easy.bind(.show);
    try easy.bind(.getState);

    try easy.setTitle("Window Example");
    try easy.setSize(480, 320, .none);
    try easy.setHtml(html);
    try easy.run();
}
