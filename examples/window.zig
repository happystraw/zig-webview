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

const Context = struct {
    w: *Webview,

    pub fn maximize(self: *Context, id: [:0]const u8, _: [:0]const u8) void {
        self.w.maximize() catch {};
        self.w.respondOk(id) catch {};
    }
    pub fn unmaximize(self: *Context, id: [:0]const u8, _: [:0]const u8) void {
        self.w.unmaximize() catch {};
        self.w.respondOk(id) catch {};
    }
    pub fn minimize(self: *Context, id: [:0]const u8, _: [:0]const u8) void {
        self.w.minimize() catch {};
        self.w.respondOk(id) catch {};
    }
    pub fn unminimize(self: *Context, id: [:0]const u8, _: [:0]const u8) void {
        self.w.unminimize() catch {};
        self.w.respondOk(id) catch {};
    }
    pub fn fullscreen(self: *Context, id: [:0]const u8, _: [:0]const u8) void {
        self.w.fullscreen() catch {};
        self.w.respondOk(id) catch {};
    }
    pub fn unfullscreen(self: *Context, id: [:0]const u8, _: [:0]const u8) void {
        self.w.unfullscreen() catch {};
        self.w.respondOk(id) catch {};
    }
    pub fn hide(self: *Context, id: [:0]const u8, _: [:0]const u8) void {
        self.w.hide() catch {};
        self.w.respondOk(id) catch {};
    }
    pub fn show(self: *Context, id: [:0]const u8, _: [:0]const u8) void {
        self.w.show() catch {};
        self.w.respondOk(id) catch {};
    }
    pub fn getState(self: *Context, id: [:0]const u8, _: [:0]const u8) void {
        const maximized = self.w.isMaximized() catch false;
        const minimized = self.w.isMinimized() catch false;
        const fs = self.w.isFullscreen() catch false;
        const visible = self.w.isVisible() catch false;
        var buf: [128]u8 = undefined;
        const result = std.fmt.bufPrintZ(&buf,
            \\{{"maximized":{s},"minimized":{s},"fullscreen":{s},"visible":{s}}}
        , .{
            if (maximized) "true" else "false",
            if (minimized) "true" else "false",
            if (fs) "true" else "false",
            if (visible) "true" else "false",
        }) catch return;
        self.w.respond(id, .ok, result) catch {};
    }
};

pub fn main() !void {
    const w = try Webview.create(true, null);
    defer w.destroy() catch {};

    var ctx: Context = .{ .w = w };
    try w.bind(Context, "maximize", Context.maximize, &ctx);
    try w.bind(Context, "unmaximize", Context.unmaximize, &ctx);
    try w.bind(Context, "minimize", Context.minimize, &ctx);
    try w.bind(Context, "unminimize", Context.unminimize, &ctx);
    try w.bind(Context, "fullscreen", Context.fullscreen, &ctx);
    try w.bind(Context, "unfullscreen", Context.unfullscreen, &ctx);
    try w.bind(Context, "hide", Context.hide, &ctx);
    try w.bind(Context, "show", Context.show, &ctx);
    try w.bind(Context, "getState", Context.getState, &ctx);

    try w.setTitle("Window Example");
    try w.setSize(480, 320, .none);
    try w.setHtml(html);
    try w.run();
}
