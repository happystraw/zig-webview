const std = @import("std");

const Webview = @import("webview").Webview;

// Run `bun run build` in view/ before building this target.
const html = @embedFile("view/dist/app.html");

const Context = struct {
    num: i64,
    w: *Webview,

    pub fn count(self: *Context, id: [:0]const u8, req: [:0]const u8) void {
        // req is a JSON array like "[1]" or "[-1]"; simply strip the brackets and parse the number.
        const direction = std.fmt.parseInt(i64, req[1 .. req.len - 1], 10) catch return;
        self.num += direction;
        var buf: [32]u8 = undefined;
        const result = std.fmt.bufPrintZ(&buf, "{d}", .{self.num}) catch return;
        self.w.respond(id, .ok, result) catch return;
    }

    pub fn reset(self: *Context, id: [:0]const u8, req: [:0]const u8) void {
        _ = req;
        self.num = 0;
        self.w.respond(id, .ok, "0") catch return;
    }
};

pub fn main() !void {
    var ctx: Context = .{
        .num = 0,
        .w = undefined,
    };

    const w = try Webview.create(true, null);
    defer w.destroy() catch unreachable;
    ctx.w = w;
    try w.setTitle("Counter");
    try w.setSize(500, 480, .none);
    try w.setHtml(html);
    try w.bind(Context, "count", Context.count, &ctx);
    try w.bind(Context, "reset", Context.reset, &ctx);
    try w.run();
}
