const std = @import("std");
const builtin = @import("builtin");

const Webview = @import("webview").Webview;

fn fail(ctx: anytype, err: anyerror) void {
    if (ctx.failure == null) ctx.failure = err;
    ctx.w.terminate() catch |terminate_err| {
        if (ctx.failure == null) ctx.failure = terminate_err;
    };
}

const LifecycleContext = struct {
    w: *Webview,
    failure: ?anyerror = null,
    raw_dispatched: bool = false,
    dispatched: bool = false,

    fn raw(w: *Webview, arg: ?*anyopaque) void {
        const self: *LifecycleContext = @ptrCast(@alignCast(arg orelse return));
        if (w != self.w) return fail(self, error.UnexpectedWebview);
        self.raw_dispatched = true;
    }

    fn simple(_: *Webview) void {}

    fn stop(self: *LifecycleContext, w: *Webview) void {
        if (w != self.w) return fail(self, error.UnexpectedWebview);
        self.dispatched = true;
        w.terminate() catch |err| fail(self, err);
    }
};

const BindingContext = struct {
    w: *Webview,
    failure: ?anyerror = null,
    started: bool = false,
    double_called: bool = false,
    finished: bool = false,

    fn start(self: *BindingContext, id: [:0]const u8, req: [:0]const u8) void {
        const js: [:0]const u8 =
            \\(async () => {
            \\  try {
            \\    const value = await window.double(21);
            \\    await window.finish(value);
            \\  } catch (_) {
            \\    await window.finish("rejected");
            \\  }
            \\})();
        ;
        if (!std.mem.eql(u8, req, "[]")) return fail(self, error.UnexpectedRequest);
        self.w.respond(id, .ok, "") catch |err| return fail(self, err);
        self.w.eval(js) catch |err| return fail(self, err);
        self.started = true;
    }

    fn double(id: [:0]const u8, req: [:0]const u8, arg: ?*anyopaque) void {
        const self: *BindingContext = @ptrCast(@alignCast(arg orelse return));
        if (!std.mem.eql(u8, req, "[21]")) return fail(self, error.UnexpectedRequest);
        self.double_called = true;
        self.w.respond(id, .ok, "42") catch |err| fail(self, err);
    }

    fn finish(self: *BindingContext, id: [:0]const u8, req: [:0]const u8) void {
        if (!std.mem.eql(u8, req, "[42]")) return fail(self, error.UnexpectedResult);
        self.w.respond(id, .ok, "") catch |err| return fail(self, err);
        self.finished = true;
        self.w.terminate() catch |err| fail(self, err);
    }

    fn removed(_: [:0]const u8, _: [:0]const u8) void {}
};

const InvalidJsonContext = struct {
    w: *Webview,
    failure: ?anyerror = null,
    rejected: bool = false,

    fn loadData(self: *InvalidJsonContext, id: [:0]const u8, req: [:0]const u8) void {
        if (!std.mem.eql(u8, req, "[]")) return fail(self, error.UnexpectedRequest);
        self.w.respond(id, .ok, "(()=>{document.body.innerHTML='gotcha';return 'hello';})()") catch |err| fail(self, err);
    }

    fn finish(self: *InvalidJsonContext, id: [:0]const u8, req: [:0]const u8) void {
        if (!std.mem.eql(u8, req, "[1]")) return fail(self, error.InvalidJsonWasAccepted);
        self.w.respond(id, .ok, "") catch |err| return fail(self, err);
        self.rejected = true;
        self.w.terminate() catch |err| fail(self, err);
    }
};

const NavigationContext = struct {
    w: *Webview,
    failure: ?anyerror = null,
    initialized: bool = false,

    fn finish(self: *NavigationContext, id: [:0]const u8, req: [:0]const u8) void {
        if (!std.mem.eql(u8, req, "[42]")) return fail(self, error.InitScriptDidNotRun);
        self.w.respond(id, .ok, "") catch |err| return fail(self, err);
        self.initialized = true;
        self.w.terminate() catch |err| fail(self, err);
    }
};

const EasyContext = struct {
    failure: ?anyerror = null,
    finished: bool = false,

    pub fn double(self: *EasyContext, req: Easy.Request) void {
        if (!std.mem.eql(u8, req.args, "[21]")) {
            self.failure = error.UnexpectedRequest;
            req.reject("\"UnexpectedRequest\"");
            return;
        }
        req.resolveWith("42");
    }

    pub fn alwaysFail(_: *EasyContext, _: Easy.Request) !void {
        return error.ExpectedFailure;
    }

    pub fn finish(self: *EasyContext, req: Easy.Request) !void {
        if (!std.mem.eql(u8, req.args, "[42,\"ExpectedFailure\"]")) {
            self.failure = error.UnexpectedResult;
        }
        req.resolve();
        self.finished = true;
        try req.easy.terminate();
    }
};

const Easy = Webview.Easy(EasyContext);

test "functional warm up WebView2" {
    if (builtin.os.tag != .windows) return;

    const w = try Webview.create(false, null);
    defer w.destroy() catch unreachable;
    try w.dispatchSimple(struct {
        fn stop(webview: *Webview) void {
            webview.terminate() catch unreachable;
        }
    }.stop);
    try w.run();
}

test "functional lifecycle and dispatch" {
    const w = try Webview.create(false, null);
    defer w.destroy() catch unreachable;

    try std.testing.expect(w.getWindow() != null);
    try std.testing.expect(w.getNativeHandle(.ui_window) != null);
    try w.setTitle("zig-webview functional test");
    try w.setSize(480, 320, .none);
    try w.setHtml("<p>setHtml works</p>");

    var ctx: LifecycleContext = .{ .w = w };
    try w.dispatchRaw(LifecycleContext.raw, &ctx);
    try w.dispatchSimple(LifecycleContext.simple);
    try w.dispatch(LifecycleContext, LifecycleContext.stop, &ctx);
    try w.run();

    if (ctx.failure) |err| return err;
    try std.testing.expect(ctx.raw_dispatched);
    try std.testing.expect(ctx.dispatched);
}

test "functional raw binding round trip and unbinding" {
    const html: [:0]const u8 =
        \\<script>
        \\window.onload = () => window.start();
        \\</script>
    ;

    const w = try Webview.create(false, null);
    defer w.destroy() catch unreachable;
    var ctx: BindingContext = .{ .w = w };

    try std.testing.expectError(error.NotFound, w.unbind("missing"));
    try w.bind(BindingContext, "start", BindingContext.start, &ctx);
    try w.bindRaw("double", BindingContext.double, &ctx);
    try std.testing.expectError(error.Duplicate, w.bindRaw("double", BindingContext.double, &ctx));
    try w.bindSimple("removed", BindingContext.removed);
    try w.unbind("removed");
    try std.testing.expectError(error.NotFound, w.unbind("removed"));
    try w.bind(BindingContext, "finish", BindingContext.finish, &ctx);
    try w.setHtml(html);
    try w.run();

    if (ctx.failure) |err| return err;
    try std.testing.expect(ctx.started);
    try std.testing.expect(ctx.double_called);
    try std.testing.expect(ctx.finished);
}

test "functional binding rejects non JSON result" {
    const html: [:0]const u8 =
        \\<script>
        \\(async () => {
        \\  try {
        \\    await window.loadData();
        \\    await window.finish(0);
        \\  } catch (_) {
        \\    await window.finish(1);
        \\  }
        \\})();
        \\</script>
    ;

    const w = try Webview.create(false, null);
    defer w.destroy() catch unreachable;
    var ctx: InvalidJsonContext = .{ .w = w };

    try w.bind(InvalidJsonContext, "loadData", InvalidJsonContext.loadData, &ctx);
    try w.bind(InvalidJsonContext, "finish", InvalidJsonContext.finish, &ctx);
    try w.setHtml(html);
    try w.run();

    if (ctx.failure) |err| return err;
    try std.testing.expect(ctx.rejected);
}

test "functional init script and navigation" {
    const w = try Webview.create(false, null);
    defer w.destroy() catch unreachable;
    var ctx: NavigationContext = .{ .w = w };

    try w.bind(NavigationContext, "finish", NavigationContext.finish, &ctx);
    try w.addInitScript("window.__zig_webview_answer = 42;");
    try w.navigate("data:text/html,%3Cscript%3Ewindow.onload%3D()%3D%3Ewindow.finish(window.__zig_webview_answer)%3C%2Fscript%3E");
    try w.run();

    if (ctx.failure) |err| return err;
    try std.testing.expect(ctx.initialized);
}

test "functional Easy binding success and error propagation" {
    const html: [:0]const u8 =
        \\<script>
        \\(async () => {
        \\  const value = await window.double(21);
        \\  try {
        \\    await window.alwaysFail();
        \\    await window.finish(value, "resolved");
        \\  } catch (err) {
        \\    await window.finish(value, err);
        \\  }
        \\})();
        \\</script>
    ;

    var ctx: EasyContext = .{};
    var easy: Easy = try .init(&ctx, .release);
    defer easy.deinit();

    try easy.bind(.double);
    try easy.bind(.alwaysFail);
    try easy.bind(.finish);
    try easy.setHtml(html);
    try easy.run();

    if (ctx.failure) |err| return err;
    try std.testing.expect(ctx.finished);
}
