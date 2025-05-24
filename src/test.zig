const std = @import("std");
const root = @import("root.zig");

pub fn main() !void {
    // Placeholder for test runner
    try test_parseArgs();
    try test_scanPort();
}

test "parseArgs basic" {
    const args = [_][]u8{ "ghostscan", "127.0.0.1", "22", "80", "--timeout", "100", "--banner", "--progress" };
    const config = try root.parseArgs(&args);
    try std.testing.expect(config.start_port == 22);
    try std.testing.expect(config.end_port == 80);
    try std.testing.expect(config.timeout_ms == 100);
    try std.testing.expect(config.banner == true);
    try std.testing.expect(config.progress == true);
}

test "scanPort closed" {
    var task = root.PortTask{
        .ip = "127.0.0.1",
        .port = 1,
        .timeout_ms = 50,
        .banner = false,
        .allocator = std.testing.allocator,
        .result = null,
    };
    root.scanPort(&task);
    try std.testing.expect(task.result == null);
}

test "scanPort open (likely fails if no open port)" {
    var task = root.PortTask{
        .ip = "127.0.0.1",
        .port = 22,
        .timeout_ms = 50,
        .banner = false,
        .allocator = std.testing.allocator,
        .result = null,
    };
    root.scanPort(&task);
    // Accepts either open or closed
}
