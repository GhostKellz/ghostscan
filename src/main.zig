//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

// ghostscan.zig — Zig-native async port scanner prototype
// Fast, clean, built for GhostKellz stack CLI tooling

const std = @import("std");
const root = @import("root.zig");

const Color = struct {
    pub const reset = "\x1b[0m";
    pub const green = "\x1b[32m";
    pub const red = "\x1b[31m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
};

fn print_usage(stdout: anytype) void {
    stdout.print(
        "Usage: ghostscan <target> [options]\n\n" ++
        "Options:\n" ++
        "  -p, --ports <range>      Specify port or port range (e.g. -p 22,80,443 or -p 1-1024)\n" ++
        "  -T, --timeout <ms>       Set connection timeout in ms\n" ++
        "  -b, --banner             Enable banner grabbing\n" ++
        "  -o, --output <file>      Output results to file (text or JSON)\n" ++
        "  -v, --verbose            Verbose output\n" ++
        "  -q, --quiet              Only print open ports\n" ++
        "  -c, --color              Force color output\n" ++
        "  -n, --no-color           Disable color output\n" ++
        "  -r, --rate <num>         Limit scan rate (ports/sec)\n" ++
        "  -6                       Enable IPv6 scanning\n" ++
        "  -iL <file>               Input list of targets from file\n" ++
        "  -A                       Aggressive scan (banner, service detection, etc.)\n" ++
        "  --interactive            Launch interactive/TUI mode\n" ++
        "  --list-interfaces        List local network interfaces and suggest targets\n" ++
        "  --json                   Output results in JSON format\n" ++
        "  --csv                    Output results in CSV format\n" ++
        "  -h, --help               Show this help\n",
        .{}
    ) catch {};
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    if (args.len < 2) {
        print_usage(stdout);
        return;
    }
    var color = true;
    var quiet = false;
    var verbose = false;
    var banner = false;
    var timeout_ms: u32 = 200;
    var port_range = "1-1024";
    var output_file: ?[]const u8 = null;
    var output_format: ?[]const u8 = null;
    var rate: ?u32 = null;
    var ipv6 = false;
    var interactive = false;
    var list_interfaces = false;
    var targets: [32][]const u8 = undefined;
    var target_count: usize = 0;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            print_usage(stdout);
            return;
        } else if (std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--ports")) {
            if (i+1 < args.len) {
                port_range = args[i+1];
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "-T") or std.mem.eql(u8, arg, "--timeout")) {
            if (i+1 < args.len) {
                timeout_ms = std.fmt.parseInt(u32, args[i+1], 10) catch timeout_ms;
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "-b") or std.mem.eql(u8, arg, "--banner")) {
            banner = true;
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            if (i+1 < args.len) {
                output_file = args[i+1];
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "-q") or std.mem.eql(u8, arg, "--quiet")) {
            quiet = true;
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--color")) {
            color = true;
        } else if (std.mem.eql(u8, arg, "-n") or std.mem.eql(u8, arg, "--no-color")) {
            color = false;
        } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--rate")) {
            if (i+1 < args.len) {
                rate = std.fmt.parseInt(u32, args[i+1], 10) catch null;
                i += 1;
            }
        } else if (std.mem.eql(u8, arg, "-6")) {
            ipv6 = true;
        } else if (std.mem.eql(u8, arg, "-A")) {
            banner = true;
        } else if (std.mem.eql(u8, arg, "--interactive")) {
            interactive = true;
        } else if (std.mem.eql(u8, arg, "--list-interfaces")) {
            list_interfaces = true;
        } else if (std.mem.eql(u8, arg, "--json")) {
            output_format = "json";
        } else if (std.mem.eql(u8, arg, "--csv")) {
            output_format = "csv";
        } else if (std.mem.eql(u8, arg, "-iL")) {
            if (i+1 < args.len) {
                // Read targets from file
                const file = try std.fs.cwd().openFile(args[i+1], .{});
                defer file.close();
                var buf: [4096]u8 = undefined;
                const n = try file.readAll(&buf);
                var start: usize = 0;
                for (buf[0..n], j) |c, idx| {
                    if (c == '\n' or c == '\r') {
                        if (idx > start) {
                            targets[target_count] = buf[start..idx];
                            target_count += 1;
                        }
                        start = idx + 1;
                    }
                }
                i += 1;
            }
        } else if (target_count < targets.len) {
            targets[target_count] = arg;
            target_count += 1;
        }
    }
    if (list_interfaces) {
        try root.list_interfaces(stdout);
        return;
    }
    if (interactive) {
        try root.interactive();
        return;
    }
    if (target_count == 0) {
        stderr.print("No target specified.\n", .{});
        print_usage(stdout);
        return;
    }
    // Output format stub
    if (output_format) |fmt| {
        if (std.mem.eql(u8, fmt, "json")) {
            stdout.print("[JSON output stub]\n", .{});
        } else if (std.mem.eql(u8, fmt, "csv")) {
            stdout.print("[CSV output stub]\n", .{});
        }
        return;
    }
    // Parse port range
    var start_port: u16 = 1;
    var end_port: u16 = 1024;
    if (std.mem.indexOfScalar(u8, port_range, '-')) |dash| {
        start_port = std.fmt.parseInt(u16, port_range[0..dash], 10) catch 1;
        end_port = std.fmt.parseInt(u16, port_range[dash+1..], 10) catch 1024;
    } else {
        start_port = std.fmt.parseInt(u16, port_range, 10) catch 1;
        end_port = start_port;
    }
    // For demonstration, print a colorized open port:
    if (color) {
        try stdout.print("{s}[+] Open: 22 ({s}){s}\n", .{ Color.green, root.detect_service(22, null), Color.reset });
    } else {
        try stdout.print("[+] Open: 22 ({s})\n", .{ root.detect_service(22, null) });
    }
}
