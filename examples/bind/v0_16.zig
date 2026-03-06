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
    w: *Webview,
    count: i64,
    io: Io,
    gpa: std.mem.Allocator,
};

fn count(id: [:0]const u8, req: [:0]const u8, ctx: *Context) void {
    // req is a JSON array like "[1]" or "[-1]"; strip the brackets and parse.
    const direction = std.fmt.parseInt(i64, req[1 .. req.len - 1], 10) catch return;
    ctx.count += direction;
    var buf: [32]u8 = undefined;
    const result = std.fmt.bufPrintZ(&buf, "{d}", .{ctx.count}) catch return;
    ctx.w.respond(id, .ok, result) catch return;
}

const ComputeContext = struct {
    w: *Webview,
    id: [:0]u8,
    io: Io,
    gpa: std.mem.Allocator,

    pub fn create(io: Io, gpa: std.mem.Allocator, w: *Webview, id: [:0]const u8) !*ComputeContext {
        const self = try gpa.create(ComputeContext);
        errdefer gpa.destroy(self);
        self.* = .{
            .w = w,
            .id = try gpa.dupeZ(u8, id),
            .io = io,
            .gpa = gpa,
        };
        return self;
    }

    pub fn destroy(self: *ComputeContext) void {
        self.gpa.free(self.id);
        self.gpa.destroy(self);
    }
};

fn doCompute(ctx: *ComputeContext) void {
    defer ctx.destroy();
    // Simulate a slow computation.
    ctx.io.sleep(.fromSeconds(1), .awake) catch return;
    ctx.w.respond(ctx.id, .ok, "42") catch return;
}

fn compute(id: [:0]const u8, req: [:0]const u8, ctx: *Context) void {
    _ = req;
    const params = ComputeContext.create(ctx.io, ctx.gpa, ctx.w, id) catch return;
    // TODO: use new Io API?
    const thread = std.Thread.spawn(.{}, doCompute, .{params}) catch {
        params.destroy();
        return;
    };
    thread.detach();
}

pub fn main(init: std.process.Init) !void {
    var ctx: Context = .{
        .w = undefined,
        .count = 0,
        .io = init.io,
        .gpa = init.gpa,
    };
    const w = try Webview.create(false, null);
    defer w.destroy() catch {};
    ctx.w = w;
    try w.setTitle("Bind Example");
    try w.setSize(480, 320, .none);
    try w.bind(Context, "count", count, &ctx);
    try w.bind(Context, "compute", compute, &ctx);
    try w.setHtml(html);
    try w.run();
}
