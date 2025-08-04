const std = @import("std");
const tsv = @embedFile("./data/lemmatize.tsv");

pub fn buildLemmatizeMap(allocator: std.mem.Allocator) !std.StringHashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(allocator);
    var lines = std.mem.tokenizeScalar(u8, tsv, '\n');

    while (lines.next()) |line| {
        var parts = std.mem.tokenizeScalar(u8, line, '\t');
        const key = parts.next() orelse continue;
        const value = parts.next() orelse continue;

        // Only insert if key is not already present
        if (!map.contains(key)) {
            try map.put(key, value);
        }
    }

    return map;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var map = try buildLemmatizeMap(allocator);

    if (map.get("abandon")) |val| {
        try std.io.getStdOut().writer().print("abandon → {s}\n", .{val});
    } else {
        try std.io.getStdOut().writer().print("abandon not found\n", .{});
    }
}
