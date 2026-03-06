const Webview = @import("webview").Webview;

pub fn main() !void {
    const w = try Webview.create(false, null);
    defer w.destroy() catch unreachable;
    try w.setTitle("Basic Example");
    try w.setSize(480, 320, .none);
    try w.setHtml("Thanks for using webview!");
    try w.run();
}
