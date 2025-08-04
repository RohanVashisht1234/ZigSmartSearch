const SearchLib = @import("SmartSearchLib.zig").SearchLib;
const std = @import("std");

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    const allocator = std.heap.c_allocator;

    // Load database content as a string
    const db_path = "database.json";
    var db_file = try std.fs.cwd().openFile(db_path, .{});
    defer db_file.close();

    const db_content = try db_file.readToEndAlloc(allocator, 1 << 24);
    defer allocator.free(db_content);

    // Initialize search instance
    var instance = try SearchLib.init(allocator, db_content, SearchLib.default_config);
    defer instance.deinit();

    // Perform search
    const results = try instance.search("backend");
    defer results.deinit();

    // Print results
    const stdout = std.io.getStdOut().writer();
    for (results.items, 0..) |result, i| {
        const title: std.json.Value = result.doc.get("title") orelse .{ .string = "N/A" };
        const desc: std.json.Value = result.doc.get("description") orelse .{ .string = "" };
        try stdout.print("{d}. [{d:3}] {s}\n", .{ i + 1, result.score, title.string });
        try stdout.print("     {s}\n\n", .{desc.string});
    }
}
