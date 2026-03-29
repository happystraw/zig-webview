const std = @import("std");

const Webview = @import("webview").Webview;

// Run `bun run build` in view/ before building this target.
const html = @embedFile("view/dist/app.html");

const Easy = Webview.Easy(Context);

const Context = struct {
    num: i64,

    pub fn count(self: *Context, req: Easy.Request) !void {
        // req.args is a JSON array like "[1]" or "[-1]"; strip the brackets and parse.
        if (req.args.len < 3) return error.InvalidArgument;
        const direction = try std.fmt.parseInt(i64, req.args[1 .. req.args.len - 1], 10);
        self.num += direction;
        var buf: [32]u8 = undefined;
        req.resolveWith(try std.fmt.bufPrintZ(&buf, "{d}", .{self.num}));
    }

    pub fn reset(self: *Context, req: Easy.Request) !void {
        self.num = 0;
        req.resolveWith("0");
    }
};

pub fn main() !void {
    var ctx: Context = .{ .num = 0 };

    var easy: Easy = try .init(&ctx, .debug);
    defer easy.deinit();

    try easy.setTitle("Counter");
    try easy.setSize(500, 480, .none);
    try easy.setHtml(html);
    try easy.bind(.count);
    try easy.bind(.reset);
    try easy.run();
}
