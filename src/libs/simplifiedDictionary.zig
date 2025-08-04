const std = @import("std");
const json = std.json;
const json_text = @embedFile("./data/simplified_dictionary.json");

pub fn loadSimplifiedDictionary(
    allocator: std.mem.Allocator,
) !std.StringHashMap([]const u8) {
    var parsed = try json.parseFromSlice(json.Value, allocator, json_text, .{});
    defer parsed.deinit();

    var map = std.StringHashMap([]const u8).init(allocator);

    const obj = parsed.value.object;

    var it = obj.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        const val = entry.value_ptr.*.string;
        try map.put(key, val);
    }

    return map;
}

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var dict = try loadSimplifiedDictionary(allocator);

    if (dict.get("run")) |val| {
        std.debug.print("run → {s}\n", .{val});
    } else {
        std.debug.print("run not found\n", .{});
    }
}
