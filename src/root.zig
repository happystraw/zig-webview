const std = @import("std");

pub const c = @import("c.zig").c;

/// Zig binding for [webview/webview](https://github.com/webview/webview): a native window
/// with an embedded browser widget for building desktop UIs with web technologies.
///
/// Typical usage:
/// ```
/// const w = try Webview.create(false, null);
/// defer w.destroy() catch unreachable;
/// try w.setTitle("Hello");
/// try w.setSize(800, 600, .none);
/// try w.setHtml("Thanks for using webview!");
/// try w.run();
/// ```
pub const Webview = opaque {
    /// Error codes returned to callers of the API.
    pub const Error = error{
        /// Missing dependency.
        MissingDependency,
        /// Operation canceled.
        Canceled,
        /// Invalid state detected.
        InvalidState,
        /// One or more invalid arguments have been specified e.g. in a function call.
        InvalidArgument,
        /// An unspecified error occurred. A more specific error code may be needed.
        Unspecified,
        /// Signifies that something already exists.
        Duplicate,
        /// Signifies that something does not exist.
        NotFound,
    };
    inline fn mapError(err: c.webview_error_t) Error!void {
        switch (err) {
            c.WEBVIEW_ERROR_OK => {},
            c.WEBVIEW_ERROR_MISSING_DEPENDENCY => return Error.MissingDependency,
            c.WEBVIEW_ERROR_CANCELED => return Error.Canceled,
            c.WEBVIEW_ERROR_INVALID_STATE => return Error.InvalidState,
            c.WEBVIEW_ERROR_INVALID_ARGUMENT => return Error.InvalidArgument,
            c.WEBVIEW_ERROR_DUPLICATE => return Error.Duplicate,
            c.WEBVIEW_ERROR_NOT_FOUND => return Error.NotFound,
            else => return Error.Unspecified,
        }
    }

    /// Window size hints.
    pub const Hint = enum(u32) {
        /// Width and height are default size.
        none = 0,
        /// Width and height are minimum bounds.
        min = 1,
        /// Width and height are maximum bounds.
        max = 2,
        /// Window size can not be changed by a user.
        fixed = 3,
    };

    /// Native handle kind. The actual type depends on the backend.
    pub const NativeHandleKind = enum(u32) {
        /// Top-level window. GtkWindow pointer (GTK), NSWindow pointer (Cocoa)
        /// or HWND (Win32).
        ui_window = 0,
        /// Browser widget. GtkWidget pointer (GTK), NSView pointer (Cocoa) or
        /// HWND (Win32).
        ui_widget = 1,
        /// Browser controller. WebKitWebView pointer (WebKitGTK), WKWebView
        /// pointer (Cocoa/WebKit) or ICoreWebView2Controller pointer
        /// (Win32/WebView2).
        browser_controller = 2,
    };

    /// Holds the elements of a MAJOR.MINOR.PATCH version number.
    pub const Version = struct {
        /// Major version.
        major: u32,
        /// Minor version.
        minor: u32,
        /// Patch version.
        patch: u32,
    };

    /// Converts a C webview_t pointer to a *Webview.
    pub inline fn from(w: c.webview_t) *Webview {
        return @ptrCast(w.?);
    }

    /// Returns the underlying C webview_t pointer.
    pub inline fn ptr(self: *Webview) c.webview_t {
        return @ptrCast(self);
    }

    /// Creates a new webview instance.
    ///
    /// - `debug`: Enable developer tools if supported by the backend.
    /// - `window`: Optional native window handle (GtkWindow pointer, NSWindow
    ///   pointer (Cocoa) or HWND (Win32)). If non-null, the webview widget is
    ///   embedded into the given window, and the caller is expected to assume
    ///   responsibility for the window as well as application lifecycle. If
    ///   null, a new window is created and both the window and application
    ///   lifecycle are managed by the webview instance.
    ///
    /// Returns `Error.MissingDependency` if WebView2 is unavailable on Windows.
    pub fn create(debug: bool, window: ?*anyopaque) Error!*Webview {
        const w = c.webview_create(@intFromBool(debug), window);
        if (w == null) return Error.Unspecified;
        if (@intFromPtr(w) < 0) return mapError(@intFromPtr(w));
        return @ptrCast(w);
    }

    /// Destroys a webview instance and closes the native window.
    pub fn destroy(self: *Webview) Error!void {
        return mapError(c.webview_destroy(self.ptr()));
    }

    /// Runs the main loop until it's terminated.
    pub fn run(self: *Webview) Error!void {
        return mapError(c.webview_run(self.ptr()));
    }

    /// Stops the main loop. It is safe to call this function from another
    /// background thread.
    pub fn terminate(self: *Webview) Error!void {
        return mapError(c.webview_terminate(self.ptr()));
    }

    /// Schedules a function to be invoked on the thread with the run/event loop.
    ///
    /// Since library functions generally do not have thread safety guarantees,
    /// this function can be used to schedule code to execute on the main/GUI
    /// thread and thereby make that execution safe in multi-threaded applications.
    ///
    /// See also `dispatch` and `dispatchSimple`
    pub fn dispatchRaw(
        self: *Webview,
        callback: fn (w: *Webview, arg: ?*anyopaque) void,
        arg: ?*anyopaque,
    ) Error!void {
        const S = struct {
            fn cb(w: c.webview_t, a: ?*anyopaque) callconv(.c) void {
                callback(.from(w), a);
            }
        };
        return mapError(c.webview_dispatch(self.ptr(), S.cb, arg));
    }

    fn DispatchCallbackType(comptime T: type) type {
        return switch (T) {
            void => fn (w: *Webview) void,
            else => fn (ctx: *T, w: *Webview) void,
        };
    }

    /// Schedules a function to be invoked on the thread with the run/event loop,
    /// with a typed argument.
    ///
    /// Like `dispatchRaw`, but the callback signature is `fn (ctx: *T, w: *Webview) void`:
    /// `ctx` is the first parameter (typed `*T` instead of `?*anyopaque`), followed by `w`.
    ///
    /// See also `dispatchSimple`
    pub fn dispatch(
        self: *Webview,
        comptime ArgType: type,
        callback: DispatchCallbackType(ArgType),
        arg: *ArgType,
    ) Error!void {
        const S = struct {
            fn cb(w: c.webview_t, a: ?*anyopaque) callconv(.c) void {
                callback(@ptrCast(@alignCast(a.?)), .from(w));
            }
        };
        return mapError(c.webview_dispatch(self.ptr(), S.cb, @ptrCast(arg)));
    }

    /// Schedules a function to be invoked on the thread with the run/event loop,
    /// without a user-provided argument.
    pub fn dispatchSimple(
        self: *Webview,
        callback: DispatchCallbackType(void),
    ) Error!void {
        const S = struct {
            fn cb(w: c.webview_t, _: ?*anyopaque) callconv(.c) void {
                callback(.from(w));
            }
        };
        return mapError(c.webview_dispatch(self.ptr(), S.cb, null));
    }

    /// Returns the native handle of the window associated with the webview
    /// instance. The handle can be a GtkWindow pointer (GTK), NSWindow pointer
    /// (Cocoa) or HWND (Win32).
    pub fn getWindow(self: *Webview) ?*anyopaque {
        return c.webview_get_window(self.ptr());
    }

    /// Get a native handle of choice.
    pub fn getNativeHandle(self: *Webview, comptime kind: NativeHandleKind) ?*anyopaque {
        return c.webview_get_native_handle(self.ptr(), @intFromEnum(kind));
    }

    /// Updates the title of the native window.
    pub fn setTitle(self: *Webview, title: [:0]const u8) Error!void {
        return mapError(c.webview_set_title(self.ptr(), title.ptr));
    }

    /// Updates the size of the native window.
    ///
    /// Remarks:
    /// - Subsequent calls to this function may behave inconsistently across
    ///   different versions of GTK and windowing systems (X11/Wayland).
    /// - Using `Hint.max` for setting the maximum window size is not supported
    ///   with GTK 4 because X11-specific functions such as
    ///   gtk_window_set_geometry_hints were removed. This option has no effect
    ///   when using GTK 4.
    pub fn setSize(self: *Webview, width: i32, height: i32, hint: Hint) Error!void {
        return mapError(c.webview_set_size(self.ptr(), width, height, @intFromEnum(hint)));
    }

    /// Navigates webview to the given URL. URL may be a properly encoded data URI.
    ///
    /// Examples:
    /// ```
    /// try w.navigate("https://github.com/webview/webview");
    /// try w.navigate("data:text/html,%3Ch1%3EHello%3C%2Fh1%3E");
    /// try w.navigate("data:text/html;base64,PGgxPkhlbGxvPC9oMT4=");
    /// ```
    pub fn navigate(self: *Webview, url: [:0]const u8) Error!void {
        return mapError(c.webview_navigate(self.ptr(), url.ptr));
    }

    /// Load HTML content into the webview.
    ///
    /// Example: `try w.setHtml("<h1>Hello</h1>");`
    pub fn setHtml(self: *Webview, html: [:0]const u8) Error!void {
        return mapError(c.webview_set_html(self.ptr(), html.ptr));
    }

    /// Injects JavaScript code to be executed immediately upon loading a page.
    /// The code will be executed before `window.onload`.
    pub fn addInitScript(self: *Webview, js: [:0]const u8) Error!void {
        return mapError(c.webview_init(self.ptr(), js.ptr));
    }

    /// Evaluates arbitrary JavaScript code.
    ///
    /// Use bindings if you need to communicate the result of the evaluation.
    pub fn eval(self: *Webview, js: [:0]const u8) Error!void {
        return mapError(c.webview_eval(self.ptr(), js.ptr));
    }

    /// Binds a function to a new global JavaScript function.
    ///
    /// JS glue code is injected to create the JS function by the given name.
    /// The callback receives a request identifier, a request string and a
    /// user-provided argument. The request string is a JSON array of the
    /// arguments passed to the JS function.
    ///
    /// Returns `Error.Duplicate` if a binding already exists with the
    /// specified name.
    ///
    /// See also `bind` and `bindSimple`
    pub fn bindRaw(
        self: *Webview,
        name: [:0]const u8,
        callback: fn (id: [:0]const u8, req: [:0]const u8, arg: ?*anyopaque) void,
        arg: ?*anyopaque,
    ) Error!void {
        const S = struct {
            fn cb(id: [*c]const u8, req: [*c]const u8, a: ?*anyopaque) callconv(.c) void {
                callback(std.mem.span(id), std.mem.span(req), a);
            }
        };
        return mapError(c.webview_bind(self.ptr(), name.ptr, S.cb, arg));
    }

    fn BindCallbackType(comptime T: type) type {
        return switch (T) {
            void => fn (id: [:0]const u8, req: [:0]const u8) void,
            else => fn (ctx: *T, id: [:0]const u8, req: [:0]const u8) void,
        };
    }

    /// Binds a function to a new global JavaScript function with a typed argument.
    ///
    /// Like `bindRaw`, but the callback signature is `fn (ctx: *T, id: [:0]const u8, req: [:0]const u8) void`:
    /// `ctx` is the first parameter (typed `*T` instead of `?*anyopaque`), followed by `id` and `req`.
    ///
    /// Returns `Error.Duplicate` if a binding already exists with the specified name.
    ///
    /// See also `bindSimple`
    pub fn bind(
        self: *Webview,
        comptime T: type,
        name: [:0]const u8,
        callback: BindCallbackType(T),
        arg: *T,
    ) Error!void {
        const S = struct {
            fn cb(id: [*c]const u8, req: [*c]const u8, a: ?*anyopaque) callconv(.c) void {
                callback(@ptrCast(@alignCast(a.?)), std.mem.span(id), std.mem.span(req));
            }
        };
        return mapError(c.webview_bind(self.ptr(), name.ptr, S.cb, @ptrCast(arg)));
    }

    /// Binds a function to a new global JavaScript function without a user-provided argument.
    ///
    /// Returns `Error.Duplicate` if a binding already exists with the specified name.
    pub fn bindSimple(
        self: *Webview,
        name: [:0]const u8,
        callback: BindCallbackType(void),
    ) Error!void {
        const S = struct {
            fn cb(id: [*c]const u8, req: [*c]const u8, _: ?*anyopaque) callconv(.c) void {
                callback(std.mem.span(id), std.mem.span(req));
            }
        };
        return mapError(c.webview_bind(self.ptr(), name.ptr, S.cb, null));
    }

    /// Removes a binding created with `bind`.
    ///
    /// Returns `Error.NotFound` if no binding exists with the specified name.
    pub fn unbind(self: *Webview, name: [:0]const u8) Error!void {
        return mapError(c.webview_unbind(self.ptr(), name.ptr));
    }

    pub const Status = enum(i32) {
        ok = 0,
        err = 1,
        _,
    };

    /// Responds to a binding call from the JS side.
    ///
    /// This function is safe to call from another thread.
    ///
    /// - `id`: The identifier of the binding call. Pass along the value
    ///   received in the binding handler (see `bind`).
    /// - `status`: A status of zero tells the JS side that the binding call
    ///   was successful; any other value indicates an error.
    /// - `result`: The result of the binding call to be returned to the JS
    ///   side. This must either be a valid JSON value or an empty string for
    ///   the primitive JS value `undefined`.
    pub fn respond(self: *Webview, id: [:0]const u8, status: Status, result: [:0]const u8) Error!void {
        return mapError(c.webview_return(self.ptr(), id.ptr, @intFromEnum(status), result.ptr));
    }

    /// Maximizes the native window.
    pub fn maximize(self: *Webview) Error!void {
        return mapError(c.webview_window_maximize(self.ptr()));
    }

    /// Unmaximizes the native window.
    pub fn unmaximize(self: *Webview) Error!void {
        return mapError(c.webview_window_unmaximize(self.ptr()));
    }

    /// Minimizes the native window.
    pub fn minimize(self: *Webview) Error!void {
        return mapError(c.webview_window_minimize(self.ptr()));
    }

    /// Unminimizes the native window.
    pub fn unminimize(self: *Webview) Error!void {
        return mapError(c.webview_window_unminimize(self.ptr()));
    }

    /// Enters fullscreen mode.
    pub fn fullscreen(self: *Webview) Error!void {
        return mapError(c.webview_window_fullscreen(self.ptr()));
    }

    /// Exits fullscreen mode.
    pub fn unfullscreen(self: *Webview) Error!void {
        return mapError(c.webview_window_unfullscreen(self.ptr()));
    }

    /// Hides the native window.
    pub fn hide(self: *Webview) Error!void {
        return mapError(c.webview_window_hide(self.ptr()));
    }

    /// Shows the native window.
    pub fn show(self: *Webview) Error!void {
        return mapError(c.webview_window_show(self.ptr()));
    }

    /// Returns whether the native window is in fullscreen mode.
    pub fn isFullscreen(self: *Webview) Error!bool {
        var result: c_int = 0;
        try mapError(c.webview_window_is_fullscreen(self.ptr(), &result));
        return result != 0;
    }

    /// Returns whether the native window is maximized.
    pub fn isMaximized(self: *Webview) Error!bool {
        var result: c_int = 0;
        try mapError(c.webview_window_is_maximized(self.ptr(), &result));
        return result != 0;
    }

    /// Returns whether the native window is minimized.
    pub fn isMinimized(self: *Webview) Error!bool {
        var result: c_int = 0;
        try mapError(c.webview_window_is_minimized(self.ptr(), &result));
        return result != 0;
    }

    /// Returns whether the native window is visible.
    pub fn isVisible(self: *Webview) Error!bool {
        var result: c_int = 0;
        try mapError(c.webview_window_is_visible(self.ptr(), &result));
        return result != 0;
    }

    /// Get the library's version information.
    pub fn version() Version {
        const info = c.webview_version().*;
        return .{
            .major = info.version.major,
            .minor = info.version.minor,
            .patch = info.version.patch,
        };
    }

    /// A convenience wrapper around `*Webview` that pairs it with a typed context `*T`.
    ///
    /// Forwards all webview methods and enhances `bind` to accept methods of `T`
    /// with signature `fn(*T, ...) anyerror!void`, automatically calling `reject`
    /// on error instead of propagating it to the caller.
    /// ```
    pub fn Easy(comptime T: type) type {
        return struct {
            const Self = @This();

            pub const Options = struct {
                devtools: bool,
                window: ?*anyopaque,

                pub const release: Options = .{ .devtools = false, .window = null };
                pub const debug: Options = .{ .devtools = true, .window = null };
            };

            pub const Request = struct {
                /// The identifier of the binding call.
                id: [:0]const u8,
                /// Raw JSON array of JS arguments, e.g. `"[1]"` or `"[\"hello\"]"`.
                args: [:0]const u8,
                easy: *Self,

                pub fn resolve(self: Request) void {
                    self.easy.resolve(self.id);
                }
                pub fn resolveWith(self: Request, result: [:0]const u8) void {
                    self.easy.resolveWith(self.id, result);
                }
                pub fn reject(self: Request, result: [:0]const u8) void {
                    self.easy.reject(self.id, result);
                }
                pub fn rejectError(self: Request, err: anyerror) void {
                    self.easy.rejectError(self.id, err);
                }
            };

            w: *Webview,
            ctx: *T,

            pub fn init(ctx: *T, options: Options) Error!Self {
                return .{
                    .w = try .create(options.devtools, options.window),
                    .ctx = ctx,
                };
            }

            pub fn deinit(self: *Self) void {
                self.w.destroy() catch |err| {
                    std.log.scoped(.webview).err("destroy failed: {s}", .{@errorName(err)});
                };
            }

            // ── Wrapped methods ───────────────────────────────────────────────
            // Wraps `T` methods with error handling; errors are forwarded to JS.

            /// Binds a method of `T` to a JS function named after its declaration.
            ///
            /// The method must have the signature:
            ///   `fn (self: *T, req: Easy.Request) void | anyerror!void`
            ///
            /// `req.args` is a JSON array of the arguments passed from JS.
            /// Returned errors are caught and forwarded to JS via `reject`.
            ///
            /// The method is responsible for settling the JS Promise via `req`:
            ///   - `req.resolve()`              — fulfill with `undefined`
            ///   - `req.resolveWith(json)`      — fulfill with a valid JSON value string
            ///   - `req.reject(msg)`            — reject with a valid JSON value string or `""`
            ///   - `req.rejectError(err)`       — reject with an error name
            /// Omitting a settle call leaves the Promise permanently pending.
            pub fn bind(self: *Self, comptime function: std.meta.DeclEnum(T)) Error!void {
                try bindAs(self, @tagName(function), function);
            }

            /// Like `bind`, but registers the method under a custom JS name.
            pub fn bindAs(self: *Self, name: [:0]const u8, comptime function: std.meta.DeclEnum(T)) Error!void {
                const cb = @field(T, @tagName(function));
                const HandleError = struct {
                    pub fn start(easy: *Self, id: [:0]const u8, req: [:0]const u8) void {
                        @as(anyerror!void, cb(easy.ctx, .{ .id = id, .args = req, .easy = easy })) catch |err| {
                            easy.rejectError(id, err);
                        };
                    }
                };
                try self.w.bind(Self, name, HandleError.start, self);
            }

            /// Binds an arbitrary function to a JS function with the given name.
            ///
            /// Unlike `bind`/`bindAs`, the callback is not required to be a method of `T`:
            ///   `fn (req: Easy.Request) void | anyerror!void`
            ///
            /// Returned errors are caught and forwarded to JS via `reject`.
            /// See `bind` for Promise settling semantics.
            pub fn bindFn(self: *Self, name: [:0]const u8, callback: anytype) Error!void {
                const HandleError = struct {
                    pub fn start(easy: *Self, id: [:0]const u8, req: [:0]const u8) void {
                        @as(anyerror!void, callback(.{ .id = id, .args = req, .easy = easy })) catch |err| {
                            easy.rejectError(id, err);
                        };
                    }
                };
                try self.w.bind(Self, name, HandleError.start, self);
            }

            /// Responds to a JS binding call. Errors are logged via `log.err`.
            pub fn respond(self: *Self, id: [:0]const u8, status: Status, result: [:0]const u8) void {
                self.w.respond(id, status, result) catch |err| {
                    std.log.scoped(.webview).err("respond failed for request {s} (status={d}, result={s}): {s}", .{ id, @intFromEnum(status), result, @errorName(err) });
                };
            }

            /// Resolves a JS binding call with `undefined`. Errors are logged via `log.err`.
            pub fn resolve(self: *Self, id: [:0]const u8) void {
                self.respond(id, .ok, "");
            }

            /// Resolves a JS binding call with a custom JSON value.
            /// `result` must be a valid JSON value or `""`.
            /// Errors are logged via `log.err`.
            pub fn resolveWith(self: *Self, id: [:0]const u8, result: [:0]const u8) void {
                self.respond(id, .ok, result);
            }

            /// Rejects a JS binding call with a custom result.
            /// `result` must be a valid JSON value or `""`.
            /// Errors are logged via `log.err`.
            pub fn reject(self: *Self, id: [:0]const u8, result: [:0]const u8) void {
                self.respond(id, .err, result);
            }

            /// Rejects a JS binding call with an error, serializing its name as a JSON string.
            /// Errors are logged via `log.err`.
            pub fn rejectError(self: *Self, id: [:0]const u8, err: anyerror) void {
                var buf: [128]u8 = undefined;
                const result = std.fmt.bufPrintZ(&buf, "\"{s}\"", .{@errorName(err)}) catch "\"Error occurred\"";
                self.respond(id, .err, result);
            }

            // ── Forwarded methods ────────────────────────────────────────────
            // Direct wrappers around `*Webview`; errors are returned to the caller.

            pub fn run(self: *Self) Error!void {
                return self.w.run();
            }
            pub fn terminate(self: *Self) Error!void {
                return self.w.terminate();
            }
            pub fn getWindow(self: *Self) ?*anyopaque {
                return self.w.getWindow();
            }
            pub fn getNativeHandle(self: *Self, comptime kind: NativeHandleKind) ?*anyopaque {
                return self.w.getNativeHandle(kind);
            }
            pub fn setTitle(self: *Self, title: [:0]const u8) Error!void {
                return self.w.setTitle(title);
            }
            pub fn setSize(self: *Self, width: i32, height: i32, hint: Hint) Error!void {
                return self.w.setSize(width, height, hint);
            }
            pub fn navigate(self: *Self, url: [:0]const u8) Error!void {
                return self.w.navigate(url);
            }
            pub fn setHtml(self: *Self, html: [:0]const u8) Error!void {
                return self.w.setHtml(html);
            }
            pub fn addInitScript(self: *Self, js: [:0]const u8) Error!void {
                return self.w.addInitScript(js);
            }
            pub fn eval(self: *Self, js: [:0]const u8) Error!void {
                return self.w.eval(js);
            }
            pub fn unbind(self: *Self, name: [:0]const u8) Error!void {
                return self.w.unbind(name);
            }
            pub fn dispatch(self: *Self, comptime ArgType: type, callback: DispatchCallbackType(ArgType), arg: *ArgType) Error!void {
                return self.w.dispatch(ArgType, callback, arg);
            }
            pub fn dispatchSimple(self: *Self, callback: DispatchCallbackType(void)) Error!void {
                return self.w.dispatchSimple(callback);
            }
            pub fn maximize(self: *Self) Error!void {
                return self.w.maximize();
            }
            pub fn unmaximize(self: *Self) Error!void {
                return self.w.unmaximize();
            }
            pub fn minimize(self: *Self) Error!void {
                return self.w.minimize();
            }
            pub fn unminimize(self: *Self) Error!void {
                return self.w.unminimize();
            }
            pub fn fullscreen(self: *Self) Error!void {
                return self.w.fullscreen();
            }
            pub fn unfullscreen(self: *Self) Error!void {
                return self.w.unfullscreen();
            }
            pub fn hide(self: *Self) Error!void {
                return self.w.hide();
            }
            pub fn show(self: *Self) Error!void {
                return self.w.show();
            }
            pub fn isFullscreen(self: *Self) Error!bool {
                return self.w.isFullscreen();
            }
            pub fn isMaximized(self: *Self) Error!bool {
                return self.w.isMaximized();
            }
            pub fn isMinimized(self: *Self) Error!bool {
                return self.w.isMinimized();
            }
            pub fn isVisible(self: *Self) Error!bool {
                return self.w.isVisible();
            }
        };
    }
};

test "checkError: known errors" {
    const t = std.testing;
    try t.expectError(error.MissingDependency, Webview.mapError(c.WEBVIEW_ERROR_MISSING_DEPENDENCY));
    try t.expectError(error.Canceled, Webview.mapError(c.WEBVIEW_ERROR_CANCELED));
    try t.expectError(error.InvalidState, Webview.mapError(c.WEBVIEW_ERROR_INVALID_STATE));
    try t.expectError(error.InvalidArgument, Webview.mapError(c.WEBVIEW_ERROR_INVALID_ARGUMENT));
    try t.expectError(error.Duplicate, Webview.mapError(c.WEBVIEW_ERROR_DUPLICATE));
    try t.expectError(error.NotFound, Webview.mapError(c.WEBVIEW_ERROR_NOT_FOUND));
}

test "checkError: unknown code falls back to Unspecified" {
    try std.testing.expectError(error.Unspecified, Webview.mapError(c.WEBVIEW_ERROR_UNSPECIFIED));
    try std.testing.expectError(error.Unspecified, Webview.mapError(99));
}

test "version" {
    const v = Webview.version();
    try std.testing.expectEqual(0, v.major);
    try std.testing.expectEqual(12, v.minor);
    try std.testing.expectEqual(0, v.patch);
}

// TODO: more tests
