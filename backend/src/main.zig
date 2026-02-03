const std = @import("std");
const http = std.http;

const Item = struct {
    id: u32,
    name: []const u8,
};

var items: std.ArrayList(Item) = undefined;
var next_id: u32 = 1;
var allocator: std.mem.Allocator = undefined;
var request_count: u32 = 0;

// Use a buffered writer that we can flush
const Writer = std.io.BufferedWriter(4096, std.fs.File.Writer);

fn getWriter() Writer {
    return std.io.bufferedWriter(std.io.getStdErr().writer());
}

fn print(comptime fmt: []const u8, args: anytype) void {
    var bw = getWriter();
    bw.writer().print(fmt, args) catch {};
    bw.flush() catch {};
}

fn formatAddress(addr: std.net.Address, buf: []u8) []const u8 {
    if (addr.any.family == std.posix.AF.INET) {
        const bytes = @as(*const [4]u8, @ptrCast(&addr.in.sa.addr));
        const len = std.fmt.bufPrint(buf, "{d}.{d}.{d}.{d}:{d}", .{
            bytes[0], bytes[1], bytes[2], bytes[3],
            std.mem.bigToNative(u16, addr.in.sa.port),
        }) catch return "unknown";
        return buf[0..len.len];
    } else if (addr.any.family == std.posix.AF.INET6) {
        return std.fmt.bufPrint(buf, "[IPv6]:{d}", .{
            std.mem.bigToNative(u16, addr.in6.sa.port),
        }) catch "unknown";
    }
    return "unknown";
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    allocator = gpa.allocator();

    items = std.ArrayList(Item).init(allocator);
    defer items.deinit();

    // Add some initial items
    try addItem("First Item");
    try addItem("Second Item");

    const address = std.net.Address.parseIp("0.0.0.0", 8080) catch unreachable;
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    print("\n", .{});
    print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    print("║            🦎 ZIG CRUD SERVER STARTED 🦎                     ║\n", .{});
    print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    print("║  Listening on: http://0.0.0.0:8080                           ║\n", .{});
    print("║  Endpoints:                                                  ║\n", .{});
    print("║    GET    /api/items      - List all items                   ║\n", .{});
    print("║    POST   /api/items      - Create new item                  ║\n", .{});
    print("║    DELETE /api/items/:id  - Delete item by ID                ║\n", .{});
    print("║    GET    /health         - Health check                     ║\n", .{});
    print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    print("\n📡 Waiting for requests from frontend...\n\n", .{});

    while (true) {
        var connection = server.accept() catch |err| {
            print("❌ Accept error: {}\n", .{err});
            continue;
        };
        defer connection.stream.close();

        // Extract client IP address
        var client_ip_buf: [64]u8 = undefined;
        const client_ip = formatAddress(connection.address, &client_ip_buf);

        var read_buffer: [8192]u8 = undefined;
        var http_server = http.Server.init(connection, &read_buffer);

        while (http_server.state == .ready) {
            var request = http_server.receiveHead() catch |err| {
                if (err != error.HttpConnectionClosing) {
                    print("❌ Receive error: {}\n", .{err});
                }
                break;
            };
            handleRequest(&request, client_ip) catch |err| {
                print("❌ Handle error: {}\n", .{err});
                break;
            };
        }
    }
}

fn getTimestamp() [14]u8 {
    const ts = std.time.timestamp();
    const epoch_seconds = @as(u64, @intCast(ts));
    const seconds_per_day: u64 = 86400;
    const seconds_per_hour: u64 = 3600;
    const seconds_per_minute: u64 = 60;

    const day_seconds = epoch_seconds % seconds_per_day;
    const hours = day_seconds / seconds_per_hour;
    const minutes = (day_seconds % seconds_per_hour) / seconds_per_minute;
    const seconds = day_seconds % seconds_per_minute;

    var buf: [14]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "{d:0>2}:{d:0>2}:{d:0>2} UTC", .{ hours, minutes, seconds }) catch unreachable;
    return buf;
}

fn logRequest(method: http.Method, target: []const u8, body: ?[]const u8, status: http.Status, client_ip: []const u8) void {
    request_count += 1;
    const timestamp = getTimestamp();

    const method_str = switch (method) {
        .GET => "GET    ",
        .POST => "POST   ",
        .DELETE => "DELETE ",
        .OPTIONS => "OPTIONS",
        .PUT => "PUT    ",
        .PATCH => "PATCH  ",
        else => "UNKNOWN",
    };

    const status_emoji = switch (status) {
        .ok, .created => "✅",
        .bad_request => "⚠️ ",
        .not_found => "🔍",
        else => "❓",
    };

    const status_code: u16 = @intFromEnum(status);

    print("┌─────────────────────────────────────────────────────────────────\n", .{});
    print("│ [{s}] Request #{d}\n", .{ timestamp, request_count });
    print("│ 📍 From: {s}\n", .{client_ip});
    print("├─────────────────────────────────────────────────────────────────\n", .{});
    print("│ {s} {s} {s}\n", .{ status_emoji, method_str, target });
    print("│ Status: {d}\n", .{status_code});

    if (body) |b| {
        if (b.len > 0) {
            print("│ Body: {s}\n", .{b});
        }
    }

    print("└─────────────────────────────────────────────────────────────────\n", .{});
}

fn addItem(name: []const u8) !void {
    const name_copy = try allocator.dupe(u8, name);
    try items.append(Item{ .id = next_id, .name = name_copy });
    next_id += 1;
}

fn handleRequest(request: *http.Server.Request, client_ip: []const u8) !void {
    const target = request.head.target;
    const method = request.head.method;

    // CORS headers
    const cors_headers = [_]http.Header{
        .{ .name = "Access-Control-Allow-Origin", .value = "*" },
        .{ .name = "Access-Control-Allow-Methods", .value = "GET, POST, DELETE, OPTIONS" },
        .{ .name = "Access-Control-Allow-Headers", .value = "Content-Type" },
        .{ .name = "Content-Type", .value = "application/json" },
    };

    // Handle CORS preflight (don't log these as they're automatic browser requests)
    if (method == .OPTIONS) {
        try request.respond("", .{
            .status = .ok,
            .extra_headers = &cors_headers,
        });
        return;
    }

    // GET /api/items - List all items
    if (method == .GET and std.mem.eql(u8, target, "/api/items")) {
        var json_buf: [4096]u8 = undefined;
        var stream = std.io.fixedBufferStream(&json_buf);
        const writer = stream.writer();

        try writer.writeAll("[");
        for (items.items, 0..) |item, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{{\"id\":{d},\"name\":\"{s}\"}}", .{ item.id, item.name });
        }
        try writer.writeAll("]");

        const response = stream.getWritten();

        logRequest(method, target, null, .ok, client_ip);
        print("    📦 Returning {d} items\n\n", .{items.items.len});

        try request.respond(response, .{
            .status = .ok,
            .extra_headers = &cors_headers,
        });
        return;
    }

    // POST /api/items - Create new item
    if (method == .POST and std.mem.eql(u8, target, "/api/items")) {
        var body_buf: [1024]u8 = undefined;
        const reader = try request.reader();
        const body_len = try reader.readAll(&body_buf);
        const body = body_buf[0..body_len];

        // Simple JSON parsing for {"name": "value"}
        if (std.mem.indexOf(u8, body, "\"name\"")) |name_start| {
            const after_colon = std.mem.indexOf(u8, body[name_start..], ":") orelse {
                logRequest(method, target, body, .bad_request, client_ip);
                print("    ❌ Failed: Invalid JSON format\n\n", .{});
                try request.respond("{\"error\":\"Invalid JSON\"}", .{
                    .status = .bad_request,
                    .extra_headers = &cors_headers,
                });
                return;
            };

            const value_start = name_start + after_colon + 1;
            const quote_start = std.mem.indexOf(u8, body[value_start..], "\"") orelse {
                logRequest(method, target, body, .bad_request, client_ip);
                print("    ❌ Failed: Missing quote in JSON\n\n", .{});
                try request.respond("{\"error\":\"Invalid JSON\"}", .{
                    .status = .bad_request,
                    .extra_headers = &cors_headers,
                });
                return;
            };

            const actual_start = value_start + quote_start + 1;
            const quote_end = std.mem.indexOf(u8, body[actual_start..], "\"") orelse {
                logRequest(method, target, body, .bad_request, client_ip);
                print("    ❌ Failed: Unterminated string in JSON\n\n", .{});
                try request.respond("{\"error\":\"Invalid JSON\"}", .{
                    .status = .bad_request,
                    .extra_headers = &cors_headers,
                });
                return;
            };

            const name = body[actual_start..actual_start + quote_end];
            try addItem(name);

            var response_buf: [256]u8 = undefined;
            const response = std.fmt.bufPrint(&response_buf, "{{\"id\":{d},\"name\":\"{s}\"}}", .{ next_id - 1, name }) catch {
                try request.respond("{\"error\":\"Response error\"}", .{
                    .status = .internal_server_error,
                    .extra_headers = &cors_headers,
                });
                return;
            };

            logRequest(method, target, body, .created, client_ip);
            print("    ✨ Created new item: ID={d}, Name=\"{s}\"\n", .{ next_id - 1, name });
            print("    📊 Total items now: {d}\n\n", .{items.items.len});

            try request.respond(response, .{
                .status = .created,
                .extra_headers = &cors_headers,
            });
            return;
        }

        logRequest(method, target, body, .bad_request, client_ip);
        print("    ❌ Failed: Missing 'name' field in JSON\n\n", .{});
        try request.respond("{\"error\":\"Invalid JSON\"}", .{
            .status = .bad_request,
            .extra_headers = &cors_headers,
        });
        return;
    }

    // DELETE /api/items/:id - Delete item
    if (method == .DELETE and std.mem.startsWith(u8, target, "/api/items/")) {
        const id_str = target[11..];
        const id = std.fmt.parseInt(u32, id_str, 10) catch {
            logRequest(method, target, null, .bad_request, client_ip);
            print("    ❌ Failed: Invalid ID format\n\n", .{});
            try request.respond("{\"error\":\"Invalid ID\"}", .{
                .status = .bad_request,
                .extra_headers = &cors_headers,
            });
            return;
        };

        var found = false;
        var i: usize = 0;
        while (i < items.items.len) {
            if (items.items[i].id == id) {
                allocator.free(items.items[i].name);
                _ = items.orderedRemove(i);
                found = true;
                break;
            }
            i += 1;
        }

        if (found) {
            logRequest(method, target, null, .ok, client_ip);
            print("    🗑️  Deleted item with ID={d}\n", .{id});
            print("    📊 Total items now: {d}\n\n", .{items.items.len});
            try request.respond("{\"success\":true}", .{
                .status = .ok,
                .extra_headers = &cors_headers,
            });
        } else {
            logRequest(method, target, null, .not_found, client_ip);
            print("    🔍 Item with ID={d} not found\n\n", .{id});
            try request.respond("{\"error\":\"Not found\"}", .{
                .status = .not_found,
                .extra_headers = &cors_headers,
            });
        }
        return;
    }

    // Health check
    if (method == .GET and std.mem.eql(u8, target, "/health")) {
        logRequest(method, target, null, .ok, client_ip);
        print("    💚 Server is healthy\n\n", .{});
        try request.respond("{\"status\":\"ok\"}", .{
            .status = .ok,
            .extra_headers = &cors_headers,
        });
        return;
    }

    // 404 for unknown routes
    logRequest(method, target, null, .not_found, client_ip);
    print("    🚫 Unknown route requested\n\n", .{});
    try request.respond("{\"error\":\"Not Found\"}", .{
        .status = .not_found,
        .extra_headers = &cors_headers,
    });
}

