//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

pub const PortResult = struct {
    ip: []const u8,
    port: u16,
    banner: ?[]u8 = null,
};

pub const PortTask = struct {
    ip: []const u8,
    port: u16,
    timeout_ms: u32,
    banner: bool,
    allocator: *std.mem.Allocator,
    result: ?PortResult = null,
};

pub fn parseArgs(args: [][]u8) !struct {
    target_ip: []const u8,
    start_port: u16,
    end_port: u16,
    timeout_ms: u32,
    banner: bool,
    progress: bool,
} {
    var start_port: u16 = 1;
    var end_port: u16 = 1024;
    var timeout_ms: u32 = 200;
    var banner = false;
    var progress = false;
    if (args.len >= 3) start_port = try std.fmt.parseInt(u16, args[2], 10);
    if (args.len >= 4) end_port = try std.fmt.parseInt(u16, args[3], 10);
    var i: usize = 4;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--timeout") and i+1 < args.len) {
            timeout_ms = try std.fmt.parseInt(u32, args[i+1], 10);
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--banner")) {
            banner = true;
        } else if (std.mem.eql(u8, args[i], "--progress")) {
            progress = true;
        }
    }
    return .{
        .target_ip = args[1],
        .start_port = start_port,
        .end_port = end_port,
        .timeout_ms = timeout_ms,
        .banner = banner,
        .progress = progress,
    };
}

pub fn scanPortsAsync(tasks: []PortTask, count: usize) !void {
    var asyncs: [64]@Frame(scanPort) = undefined;
    for (tasks[0..count]) |*t, i| {
        asyncs[i] = async scanPort(t);
    }
    for (tasks[0..count]) |*t, i| {
        await asyncs[i];
    }
}

pub fn scanPort(task: *PortTask) void {
    const std = @import("std");
    var address = std.net.Address.parseIp4(task.ip, task.port) catch return;
    var socket = std.net.StreamSocket.create(.ipv4, .tcp) catch return;
    defer socket.close();
    if (socket.connect(address)) |err| {
        return;
    }
    var banner: ?[]u8 = null;
    if (task.banner) {
        var buf: [64]u8 = undefined;
        if (socket.readTimeout(&buf, task.timeout_ms)) |n| {
            banner = task.allocator.alloc(u8, n) catch null;
            if (banner) |b| std.mem.copy(u8, b, buf[0..n]);
        } else |_| {}
    }
    task.result = PortResult{
        .ip = task.ip,
        .port = task.port,
        .banner = banner,
    };
}

pub const IpRangeIterator = struct {
    // Placeholder: implement CIDR or start-end IP range iteration
    // For now, just yield the input IP once
    ip: []const u8,
    done: bool = false,
    allocator: *std.mem.Allocator,
    pub fn init(ip: []const u8, allocator: *std.mem.Allocator) !IpRangeIterator {
        return IpRangeIterator{ .ip = ip, .allocator = allocator };
    }
    pub fn next(self: *IpRangeIterator, buf: []u8) ?[]const u8 {
        if (self.done) return null;
        self.done = true;
        std.mem.copy(u8, buf, self.ip);
        return buf[0..self.ip.len];
    }
    pub fn deinit(self: *IpRangeIterator) void {}
};

pub const ProgressBar = struct {
    stdout: anytype,
    total: usize,
    current: usize = 0,
    pub fn init(stdout: anytype, total: usize) !*ProgressBar {
        return &ProgressBar{ .stdout = stdout, .total = total };
    }
    pub fn tick(self: *ProgressBar) void {
        self.current += 1;
        if (self.current % 10 == 0 or self.current == self.total) {
            self.stdout.print("Progress: {d}/{d}\r", .{ self.current, self.total }) catch {};
        }
    }
    pub fn deinit(self: *ProgressBar) void {
        self.stdout.print("\n", .{}) catch {};
    }
};

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

// ghostscan_lib placeholder for future library code
// This can be expanded for modularity, e.g. async scanning, utils, etc.

pub fn interactive() !void {
    // Minimal TUI stub: print a table header and wait for user input
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\nTUI Mode (prototype)\n", .{});
    try stdout.print("Target        Port   State   Service\n", .{});
    try stdout.print("-----------------------------------\n", .{});
    // In a real TUI, this would update live and handle keyboard input
    // For now, just wait for Enter to exit
    var buf: [8]u8 = undefined;
    _ = try std.io.getStdIn().read(&buf);
}

pub fn detect_service(port: u16, banner: ?[]const u8) []const u8 {
    // Simple port-to-service mapping
    return switch (port) {
        21 => "ftp",
        22 => "ssh",
        23 => "telnet",
        25 => "smtp",
        53 => "dns",
        80 => "http",
        110 => "pop3",
        143 => "imap",
        443 => "https",
        3306 => "mysql",
        5432 => "postgres",
        6379 => "redis",
        8080 => "http-alt",
        else => banner orelse "?",
    };
}

pub fn example() void {
    // Placeholder function
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
