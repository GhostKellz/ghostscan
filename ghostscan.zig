// ghostscan.zig — Zig-native async port scanner
// Fast, clean, built for GhostKellz stack CLI tooling

const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("👻 ghostscan: blazing-fast Zig port scanner\n", .{});

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    if (args.len < 2) {
        try stdout.print("Usage: ghostscan <ip> [start-port] [end-port]\n", .{});
        return;
    }

    const target_ip = args[1];
    const start_port = if (args.len >= 3) try std.fmt.parseInt(u16, args[2], 10) else 1;
    const end_port = if (args.len >= 4) try std.fmt.parseInt(u16, args[3], 10) else 1024;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    var open_ports = std.ArrayList(u16).init(allocator);

    try stdout.print("Scanning {s}:{d}-{d}...\n", .{ target_ip, start_port, end_port });

    var port: u16 = start_port;
    while (port <= end_port) : (port += 1) {
        const address = try std.net.Address.parseIp4(target_ip, port);
        const socket = std.net.StreamSocket.create(.ipv4, .tcp);

        if (socket) |s| {
            const result = s.connect(address);
            if (result == null) {
                try open_ports.append(port);
                try stdout.print("[+] Open: {d}\n", .{ port });
            }
            s.close();
        }
    }

    try stdout.print("Scan complete. Open ports: {any}\n", .{ open_ports });
}

