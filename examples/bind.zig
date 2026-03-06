const builtin = @import("builtin");

pub const main = if (builtin.zig_version.major == 0 and builtin.zig_version.minor < 16)
    @import("bind/v0_15.zig").main
else
    @import("bind/v0_16.zig").main;
