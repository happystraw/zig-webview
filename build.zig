const std = @import("std");
const builtin = @import("builtin");

const WebkitGtkVersion = enum {
    @"4.0",
    @"4.1",
    @"6.0",
};

const BuildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    macos_sdk: ?[]const u8 = null,
    webkitgtk: WebkitGtkVersion = .@"4.1",
};

pub fn build(b: *std.Build) void {
    const options: BuildOptions = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .macos_sdk = b.option([]const u8, "macos-sdk", "Path to macOS SDK (optional), used on non-macOS platforms"),
        .webkitgtk = b.option(WebkitGtkVersion, "webkitgtk", "Version of WebKitGTK to link against (default: 4.1), Linux only") orelse .@"4.1",
    };

    const lib = addLibrary(b, options);
    const mod = addModule(b, options, lib);

    addTestStep(b, mod);
    addExamplesStep(b, options, mod);
    addDocStep(b, mod);
}

fn addLibrary(b: *std.Build, options: BuildOptions) *std.Build.Step.Compile {
    const upstream = b.dependency("webview", .{});
    const mod = b.createModule(.{
        .target = options.target,
        .optimize = options.optimize,
        .link_libcpp = true,
    });
    mod.addIncludePath(upstream.path("core/include"));
    mod.addCMacro("WEBVIEW_STATIC", "1");
    switch (options.target.result.os.tag) {
        .windows => {
            mod.addCSourceFile(.{ .file = upstream.path("core/src/webview.cc"), .flags = &.{"-std=c++14"} });
            mod.addIncludePath(b.path("deps/WebView2/"));
            mod.linkSystemLibrary("advapi32", .{});
            mod.linkSystemLibrary("ole32", .{});
            mod.linkSystemLibrary("shell32", .{});
            mod.linkSystemLibrary("shlwapi", .{});
            mod.linkSystemLibrary("user32", .{});
            mod.linkSystemLibrary("version", .{});
        },
        .macos => {
            tryApplyMacOsSdk(b, mod, options);
            mod.addCSourceFile(.{ .file = upstream.path("core/src/webview.cc"), .flags = &.{"-std=c++11"} });
            mod.linkFramework("WebKit", .{});
        },
        .linux => {
            mod.addCSourceFile(.{ .file = upstream.path("core/src/webview.cc"), .flags = &.{"-std=c++11"} });
            switch (options.webkitgtk) {
                .@"4.0" => {
                    mod.linkSystemLibrary("gtk+-3.0", .{});
                    mod.linkSystemLibrary("webkit2gtk-4.0", .{});
                },
                .@"4.1" => {
                    mod.linkSystemLibrary("gtk+-3.0", .{});
                    mod.linkSystemLibrary("webkit2gtk-4.1", .{});
                },
                .@"6.0" => {
                    mod.linkSystemLibrary("gtk-4", .{});
                    mod.linkSystemLibrary("webkitgtk-6.0", .{});
                },
            }
        },
        else => unreachable,
    }
    const lib = b.addLibrary(.{
        .name = "webview",
        .root_module = mod,
        .linkage = .static,
    });
    b.installArtifact(lib);
    return lib;
}

fn addModule(b: *std.Build, options: BuildOptions, lib: *std.Build.Step.Compile) *std.Build.Module {
    const webview_c = createCModule(b, options);
    const mod = b.addModule("webview", .{
        .root_source_file = b.path("src/root.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "webview_c", .module = webview_c },
        },
    });
    mod.linkLibrary(lib);
    return mod;
}

fn addTestStep(b: *std.Build, mod: *std.Build.Module) void {
    const test_step = b.step("test", "Run tests");
    const mod_test = b.addTest(.{ .root_module = mod });
    const run_mod_test = b.addRunArtifact(mod_test);
    test_step.dependOn(&run_mod_test.step);
}

fn addExamplesStep(b: *std.Build, options: BuildOptions, mod: *std.Build.Module) void {
    const examples_step = b.step("examples", "Build all examples");
    const examples = [_][]const u8{
        "basic",
        "bind",
    };
    inline for (examples) |name| {
        const example_mod = b.createModule(.{
            .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
            .target = options.target,
            .optimize = options.optimize,
            .imports = &.{
                .{ .name = "webview", .module = mod },
            },
        });
        if (options.target.result.os.tag == .macos) {
            tryApplyMacOsSdk(b, example_mod, options);
        }
        const exe = b.addExecutable(.{
            .name = name,
            .root_module = example_mod,
        });
        const install = b.addInstallArtifact(exe, .{});
        examples_step.dependOn(&install.step);
    }
}

fn addDocStep(b: *std.Build, mod: *std.Build.Module) void {
    const doc_step = b.step("doc", "Generate documentation");
    const doc_obj = b.addObject(.{
        .name = "webview",
        .root_module = mod,
    });
    const install_doc = b.addInstallDirectory(.{
        .source_dir = doc_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "doc",
    });
    doc_step.dependOn(&install_doc.step);
}

fn createCModule(b: *std.Build, options: BuildOptions) *std.Build.Module {
    const upstream = b.dependency("webview", .{});
    const c_mod = b.addTranslateC(.{
        .root_source_file = upstream.path("core/include/webview.h"),
        .target = options.target,
        .optimize = options.optimize,
    }).createModule();
    c_mod.addIncludePath(upstream.path("core/include"));
    c_mod.addCMacro("WEBVIEW_STATIC", "1");
    return c_mod;
}

fn tryApplyMacOsSdk(b: *std.Build, mod: *std.Build.Module, options: BuildOptions) void {
    if (builtin.os.tag != .macos and options.macos_sdk != null) {
        const macos_sdk_path: std.Build.LazyPath = .{ .cwd_relative = options.macos_sdk.? };
        mod.addSystemIncludePath(macos_sdk_path.path(b, "usr/include"));
        mod.addLibraryPath(macos_sdk_path.path(b, "usr/lib"));
        mod.addSystemFrameworkPath(macos_sdk_path.path(b, "System/Library/Frameworks"));
    }
}
