const ZigSmartSearch = @import("../ZigSmartSearch.zig").ZigSmartSearch;
const std = @import("std");
const database = @embedFile("database.json");

pub fn main() !void {

    // Initialize search instance
    var instance = try ZigSmartSearch.init(
        std.heap.c_allocator,
        database,
        ZigSmartSearch.default_config,
    );
    defer instance.deinit();

    // Perform search
    const results = try instance.search("game");
    defer results.deinit();

    // Print results
    for (results.items, 0..) |result, i| {
        const title: std.json.Value = result.doc.get("title") orelse .{ .string = "" };
        const desc: std.json.Value = result.doc.get("description") orelse .{ .string = "" };
        std.debug.print("{d}. [{d:3}] {s}\n", .{ i + 1, result.score, title.string });
        std.debug.print("     {s}\n\n", .{desc.string});
    }
}
