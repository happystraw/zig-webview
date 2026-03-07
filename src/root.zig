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
            else => fn (w: *Webview, arg: *T) void,
        };
    }

    /// Schedules a function to be invoked on the thread with the run/event loop,
    /// with a typed argument.
    ///
    /// Like `dispatchRaw`, but the callback receives a `*T` pointer instead of `?*anyopaque`,
    /// providing type safety for the user-provided argument.
    ///
    /// See also `dispatchSimple`
    pub fn dispatch(
        self: *Webview,
        comptime T: type,
        callback: DispatchCallbackType(T),
        arg: *T,
    ) Error!void {
        const S = struct {
            fn cb(w: c.webview_t, a: ?*anyopaque) callconv(.c) void {
                callback(.from(w), @ptrCast(@alignCast(a.?)));
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
            else => fn (id: [:0]const u8, req: [:0]const u8, arg: *T) void,
        };
    }

    /// Binds a function to a new global JavaScript function with a typed argument.
    ///
    /// Like `bindRaw`, but the callback receives a `*T` pointer instead of `?*anyopaque`,
    /// providing type safety for the user-provided argument.
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
                callback(std.mem.span(id), std.mem.span(req), @ptrCast(@alignCast(a.?)));
            }
        };
        return mapError(c.webview_bind(self.ptr(), name.ptr, S.cb, @ptrCast(arg)));
    }

    /// Binds a function to a new global JavaScript function without a user-provided argument.
    ///
    /// Shorthand for `bind(void, name, callback, {})`.
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

    /// Get the library's version information.
    pub fn version() Version {
        const info = c.webview_version().*;
        return .{
            .major = info.version.major,
            .minor = info.version.minor,
            .patch = info.version.patch,
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

// TODO: more tests
