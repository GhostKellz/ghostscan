//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

// ghostscan.zig — Zig-native async port scanner prototype
// Fast, clean, built for GhostKellz stack CLI tooling

const std = @import("std");
const root = @import("root.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("👻 ghostscan: blazing-fast Zig port scanner\n", .{});

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    if (args.len < 2) {
        try stdout.print("Usage: ghostscan <ip|cidr> [start-port] [end-port] [--timeout ms] [--banner] [--progress]\n", .{});
        return;
    }

    var config = try root.parseArgs(args);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;
    var open_ports = std.ArrayList(root.PortResult).init(allocator);

    var ip_iter = try root.IpRangeIterator.init(config.target_ip, allocator);
    defer ip_iter.deinit();

    try stdout.print("Scanning {s}:{d}-{d}...\n", .{ config.target_ip, config.start_port, config.end_port });
    var ip_buf: [16]u8 = undefined;
    while (ip_iter.next(&ip_buf)) |ip| {
        try stdout.print("Host: {s}\n", .{ip});
        var progress = if (config.progress) try root.ProgressBar.init(stdout, config.end_port - config.start_port + 1) else null;
        defer if (progress) |p| p.deinit();
        var port = config.start_port;
        var tasks: [64]root.PortTask = undefined;
        var task_count: usize = 0;
        while (port <= config.end_port) : (port += 1) {
            tasks[task_count] = root.PortTask{
                .ip = ip,
                .port = port,
                .timeout_ms = config.timeout_ms,
                .banner = config.banner,
                .allocator = allocator,
                .result = null,
            };
            task_count += 1;
            if (task_count == tasks.len or port == config.end_port) {
                try root.scanPortsAsync(&tasks, task_count);
                for (tasks[0..task_count]) |*t| {
                    if (t.result) |r| {
                        try open_ports.append(r);
                        try stdout.print("[+] Open: {d}", .{ r.port });
                        if (r.banner) |b| try stdout.print(" Banner: {s}", .{b});
                        try stdout.print("\n", .{});
                    }
                    if (progress) |*p| p.tick();
                }
                task_count = 0;
            }
        }
    }
    try stdout.print("Scan complete. Open ports: {d}\n", .{ open_ports.items.len });
}
