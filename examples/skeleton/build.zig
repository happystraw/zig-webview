const std = @import("std");

const webview_helper = @import("webview");

const BuildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    macos_sdk: ?[]const u8,
    webkitgtk: webview_helper.WebkitGtkVersion,
};

pub fn build(b: *std.Build) void {
    // --- Install Step ---
    const options: BuildOptions = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .macos_sdk = b.option([]const u8, "macos-sdk", "Path to macOS SDK (optional), used on non-macOS platforms"),
        .webkitgtk = b.option(webview_helper.WebkitGtkVersion, "webkitgtk", "Version of WebKitGTK to link against (default: 4.1), Linux only") orelse .@"4.1",
    };

    const exe = b.addExecutable(.{
        .name = "skeleton",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = options.target,
            .optimize = options.optimize,
        }),
    });
    const webview_dep = b.dependency("webview", .{
        .target = options.target,
        .optimize = options.optimize,
        .@"macos-sdk" = options.macos_sdk,
        .webkitgtk = options.webkitgtk,
    });
    exe.root_module.addImport("webview", webview_dep.module("webview"));
    // For cross-compilation to macOS, apply the SDK to the executable as well as the library
    webview_helper.tryApplyMacOsSdk(b, exe.root_module, .{
        .target = options.target,
        .optimize = options.optimize,
        .macos_sdk = options.macos_sdk,
        .webkitgtk = options.webkitgtk,
    });

    // Build the frontend using bun
    const bun_build_cmd = b.addSystemCommand(&[_][]const u8{ "bun", "run", "build" });
    bun_build_cmd.setCwd(b.path("src/view"));
    exe.step.dependOn(&bun_build_cmd.step);

    if (options.target.result.os.tag == .windows) {
        exe.subsystem = .Windows;
    }

    b.installArtifact(exe);

    // --- Run Step ---
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // --- Test Step ---
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
