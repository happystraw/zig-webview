const std = @import("std");

const Webview = @import("webview").Webview;

const html: [:0]const u8 =
    \\<div>
    \\  <button id="increment">+</button>
    \\  <button id="decrement">−</button>
    \\  <span>Counter: <span id="result">0</span></span>
    \\</div>
    \\<script type="module">
    \\  const result = document.getElementById("result");
    \\  document.getElementById("increment").addEventListener("click", async () => {
    \\    result.textContent = await window.count(1);
    \\  });
    \\  document.getElementById("decrement").addEventListener("click", async () => {
    \\    result.textContent = await window.count(-1);
    \\  });
    \\</script>
;

const Easy = Webview.Easy(Context);

const Context = struct {
    num: i64,

    pub fn count(self: *Context, req: Easy.Request) !void {
        // req.args is a JSON array like "[1]" or "[-1]"; strip the brackets and parse.
        if (req.args.len < 3) return error.InvalidArgument;
        const delta = try std.fmt.parseInt(i64, req.args[1 .. req.args.len - 1], 10);
        self.num += delta;
        var buf: [32]u8 = undefined;
        req.resolveWith(try std.fmt.bufPrintZ(&buf, "{d}", .{self.num}));
    }
};

pub fn main() !void {
    var ctx: Context = .{ .num = 0 };

    var easy: Easy = try .init(&ctx, .release);
    defer easy.deinit();

    try easy.bind(.count);
    try easy.setTitle("Easy Example");
    try easy.setSize(480, 320, .none);
    try easy.setHtml(html);
    try easy.run();
}
