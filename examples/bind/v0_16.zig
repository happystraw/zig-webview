const std = @import("std");
const Io = std.Io;

const Webview = @import("webview").Webview;

const html: [:0]const u8 =
    \\<div>
    \\  <button id="increment">+</button>
    \\  <button id="decrement">−</button>
    \\  <span>Counter: <span id="counterResult">0</span></span>
    \\</div>
    \\<hr />
    \\<div>
    \\  <button id="compute">Compute</button>
    \\  <span>Result: <span id="computeResult">(not started)</span></span>
    \\</div>
    \\<script type="module">
    \\  const getElements = ids => Object.assign({}, ...ids.map(
    \\    id => ({ [id]: document.getElementById(id) })));
    \\  const ui = getElements([
    \\    "increment", "decrement", "counterResult", "compute",
    \\    "computeResult"
    \\  ]);
    \\  ui.increment.addEventListener("click", async () => {
    \\    ui.counterResult.textContent = await window.count(1);
    \\  });
    \\  ui.decrement.addEventListener("click", async () => {
    \\    ui.counterResult.textContent = await window.count(-1);
    \\  });
    \\  ui.compute.addEventListener("click", async () => {
    \\    ui.compute.disabled = true;
    \\    ui.computeResult.textContent = "(pending)";
    \\    ui.computeResult.textContent = await window.compute(6, 7);
    \\    ui.compute.disabled = false;
    \\  });
    \\</script>
;

const Context = struct {
    num: i64,

    w: *Webview,
    io: Io,
    gpa: std.mem.Allocator,
    group: Io.Group,

    pub fn count(self: *Context, id: [:0]const u8, req: [:0]const u8) void {
        self.doCount(id, req) catch |err| self.w.respondError(id, err) catch {};
    }

    fn doCount(self: *Context, id: [:0]const u8, req: [:0]const u8) !void {
        // req is a JSON array like "[1]" or "[-1]"; simply strip the brackets and parse the number.
        const direction = try std.fmt.parseInt(i64, req[1 .. req.len - 1], 10);
        self.num += direction;
        var buf: [32]u8 = undefined;
        const result = try std.fmt.bufPrintZ(&buf, "{d}", .{self.num});
        self.w.respond(id, .ok, result) catch return;
    }

    pub fn compute(self: *Context, id: [:0]const u8, req: [:0]const u8) void {
        _ = req;
        const id_copy = self.gpa.dupeSentinel(u8, id, 0) catch |err| return self.w.respondError(id, err) catch {};
        self.group.async(self.io, doCompute, .{ self, id_copy });
    }

    fn doCompute(self: *const Context, id: [:0]const u8) void {
        defer self.gpa.free(id);
        // Simulate a slow computation.
        self.io.sleep(.fromSeconds(1), .awake) catch {
            std.debug.print("Sleep cancelled\n", .{});
            return;
        };
        self.w.respond(id, .ok, "\"done\"") catch return;
    }

    pub fn init(w: *Webview, io: Io, gpa: std.mem.Allocator) Context {
        return .{
            .num = 0,
            .w = w,
            .io = io,
            .gpa = gpa,
            .group = .init,
        };
    }

    pub fn deinit(self: *Context) void {
        self.group.cancel(self.io);
    }
};

pub fn main(init: std.process.Init) !void {
    const w = try Webview.create(false, null);
    defer w.destroy() catch {};

    var ctx: Context = .init(w, init.io, init.gpa);
    defer ctx.deinit();
    try w.bind(Context, "count", Context.count, &ctx);
    try w.bind(Context, "compute", Context.compute, &ctx);

    try w.setTitle("Bind Example");
    try w.setSize(480, 320, .none);
    try w.setHtml(html);
    try w.run();
}
