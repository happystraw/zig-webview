const std = @import("std");

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

    pub fn compute(self: *const Context, id: [:0]const u8, req: [:0]const u8) void {
        self.doCompute(id, req) catch |err| self.w.respondError(id, err) catch {};
    }

    fn doCompute(self: *const Context, id: [:0]const u8, req: [:0]const u8) !void {
        _ = req;
        const gpa = std.heap.page_allocator;
        const compute_ctx = try ComputeContext.create(gpa, self.w, id);
        errdefer compute_ctx.destroy();
        const thread = try std.Thread.spawn(.{}, ComputeContext.compute, .{compute_ctx});
        thread.detach();
    }
};

const ComputeContext = struct {
    w: *Webview,
    id: [:0]u8,
    gpa: std.mem.Allocator,

    pub fn create(gpa: std.mem.Allocator, w: *Webview, id: [:0]const u8) !*ComputeContext {
        const self = try gpa.create(ComputeContext);
        errdefer gpa.destroy(self);
        self.* = .{
            .w = w,
            .id = try gpa.dupeZ(u8, id),
            .gpa = gpa,
        };
        return self;
    }

    pub fn destroy(self: *ComputeContext) void {
        self.gpa.free(self.id);
        self.gpa.destroy(self);
    }

    pub fn compute(self: *ComputeContext) void {
        defer self.destroy();
        // Simulate a slow computation.
        std.Thread.sleep(1 * std.time.ns_per_s);
        self.w.respond(self.id, .ok, "\"done\"") catch return;
    }
};

pub fn main() !void {
    var ctx: Context = .{
        .w = undefined,
        .num = 0,
    };
    const w = try Webview.create(true, null);
    defer w.destroy() catch unreachable;
    ctx.w = w;
    try w.setTitle("Bind Example");
    try w.setSize(480, 320, .none);
    try w.bind(Context, "count", Context.count, &ctx);
    try w.bind(Context, "compute", Context.compute, &ctx);
    try w.setHtml(html);
    try w.run();
}
