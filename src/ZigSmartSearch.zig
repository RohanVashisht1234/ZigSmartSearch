const std = @import("std");
const json = std.json;

pub const ZigSmartSearch = struct {
    const Allocator = std.mem.Allocator;
    const NON_EMPHASIS_WORDS = @import("libs/nonEmphasisWords.zig").NON_EMPHASIS_WORDS;
    const simplified = @import("libs/simplifiedDictionary.zig");
    const lemmatizer = @import("libs/lemmatizeWordMap.zig");

    // Configuration struct for search parameters
    pub const SearchConfig = struct {
        max_expansions: u8 = 3,
        min_word_length: usize = 2,
        max_results: usize = 10,
        title_weight: u32 = 70,
        desc_weight: u32 = 60,
        content_weight: u32 = 50,
        phrase_bonus: u32 = 90,
        proximity_bonus_max: u32 = 20,
        proximity_threshold: usize = 50,
    };

    // Default configuration
    pub const default_config: SearchConfig = .{};

    // Result struct for search results
    pub const SearchResult = struct {
        doc: json.ObjectMap,
        score: u32,
    };

    allocator: Allocator,
    documents: []json.Value,
    parsed: json.Parsed([]json.Value),
    dict: std.StringHashMap([]const u8),
    lemma: std.StringHashMap([]const u8),
    config: SearchConfig,

    // Initialize the search library instance
    pub fn init(allocator: Allocator, db_content: []const u8, config: SearchConfig) !ZigSmartSearch {
        // Parse JSON database
        const parsed = try json.parseFromSlice([]json.Value, allocator, db_content, .{ .ignore_unknown_fields = true });

        // Load dictionary
        var dict = simplified.loadSimplifiedDictionary(allocator) catch |e| {
            std.debug.print("Warning: Could not load dictionary: {}\n", .{e});
            parsed.deinit();
            return error.DictionaryLoadFailed;
        };

        // Load lemmatizer
        const lemma = lemmatizer.buildLemmatizeMap(allocator) catch |e| {
            std.debug.print("Warning: lemmatizer not loaded: {}\n", .{e});
            parsed.deinit();
            dict.deinit();
            return error.LemmatizerLoadFailed;
        };

        return ZigSmartSearch{
            .allocator = allocator,
            .documents = parsed.value,
            .parsed = parsed,
            .dict = dict,
            .lemma = lemma,
            .config = config,
        };
    }

    // Clean up resources
    pub fn deinit(self: *ZigSmartSearch) void {
        self.parsed.deinit();
        self.dict.deinit();
        self.lemma.deinit();
    }

    // Check if a word is non-emphasis
    fn isNonEmphasis(word: []const u8) bool {
        for (NON_EMPHASIS_WORDS) |w| {
            if (std.mem.eql(u8, w, word)) return true;
        }
        return false;
    }

    // Preprocess input query into tokens
    fn preprocess(self: *ZigSmartSearch, input: []const u8) !std.ArrayList([]const u8) {
        var words = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            for (words.items) |w| self.allocator.free(w);
            words.deinit();
        }

        const lower = try std.ascii.allocLowerString(self.allocator, input);
        defer self.allocator.free(lower);

        var cleaned = try self.allocator.alloc(u8, lower.len);
        defer self.allocator.free(cleaned);
        for (lower, 0..) |c, i| {
            cleaned[i] = if (std.ascii.isAlphanumeric(c) or c == ' ' or c == '-') c else ' ';
        }

        var it = std.mem.tokenizeAny(u8, cleaned, " \t\n-");
        while (it.next()) |w| {
            if (w.len > self.config.min_word_length and !isNonEmphasis(w)) {
                const copy = try self.allocator.dupe(u8, w);
                try words.append(copy);
            }
        }
        return words;
    }

    // Expand words using dictionary and lemmatizer
    fn expandWords(
        self: *ZigSmartSearch,
        original: []const []const u8,
    ) !std.StringHashMap(u8) {
        var expanded = std.StringHashMap(u8).init(self.allocator);
        errdefer expanded.deinit();

        for (original) |w| {
            try expanded.put(w, 10);
            if (self.lemma.get(w)) |base| {
                try expanded.put(base, 8);
            }
            if (self.dict.get(w)) |exp| {
                var count: u8 = 0;
                var it = std.mem.tokenizeScalar(u8, exp, ' ');
                while (it.next()) |e| {
                    if (count >= self.config.max_expansions) break;
                    try expanded.put(e, 5);
                    if (self.lemma.get(e)) |base2| {
                        try expanded.put(base2, 4);
                    }
                    count += 1;
                }
            }
        }
        return expanded;
    }

    // Calculate score for a document
    fn calculateScore(
        self: *ZigSmartSearch,
        doc: json.ObjectMap,
        original: []const []const u8,
        expanded: std.StringHashMap(u8),
    ) !u32 {
        var score: u32 = 0;
        var matched = std.StringHashMap(void).init(self.allocator);
        defer matched.deinit();

        const name: json.Value = doc.get("title") orelse .{ .string = "" };
        const desc: json.Value = doc.get("description") orelse .{ .string = "" };
        const content: json.Value = doc.get("content") orelse .{ .string = "" };

        const title_lower = try std.ascii.allocLowerString(self.allocator, name.string);
        defer self.allocator.free(title_lower);
        const desc_lower = try std.ascii.allocLowerString(self.allocator, desc.string);
        defer self.allocator.free(desc_lower);
        const content_lower = try std.ascii.allocLowerString(self.allocator, content.string);
        defer self.allocator.free(content_lower);

        const wordBoundary = struct {
            fn containsWord(haystack: []const u8, needle: []const u8) bool {
                var i: usize = 0;
                while (std.mem.indexOfPos(u8, haystack, i, needle)) |pos| {
                    const is_start = pos == 0 or !std.ascii.isAlphanumeric(haystack[pos - 1]);
                    const is_end = pos + needle.len == haystack.len or !std.ascii.isAlphanumeric(haystack[pos + needle.len]);
                    if (is_start and is_end) return true;
                    i = pos + 1;
                }
                return false;
            }
        }.containsWord;

        if (original.len > 1) {
            const joined = try std.mem.join(self.allocator, " ", original);
            defer self.allocator.free(joined);
            if (std.mem.indexOf(u8, title_lower, joined) != null) {
                score += self.config.phrase_bonus;
            } else if (std.mem.indexOf(u8, desc_lower, joined) != null) {
                score += self.config.phrase_bonus - 10;
            } else if (std.mem.indexOf(u8, content_lower, joined) != null) {
                score += self.config.phrase_bonus - 20;
            }

            const full_text = try std.fmt.allocPrint(self.allocator, "{s} {s} {s}", .{ title_lower, desc_lower, content_lower });
            defer self.allocator.free(full_text);
            var positions = std.ArrayList(usize).init(self.allocator);
            defer positions.deinit();
            for (original) |word| {
                var i: usize = 0;
                while (std.mem.indexOfPos(u8, full_text, i, word)) |pos| {
                    try positions.append(pos);
                    i = pos + 1;
                }
            }
            if (positions.items.len >= 2) {
                std.mem.sortUnstable(usize, positions.items, {}, struct {
                    fn lessThan(_: void, a: usize, b: usize) bool {
                        return a < b;
                    }
                }.lessThan);
                var max_gap: usize = 0;
                for (1..positions.items.len) |i| {
                    const gap = positions.items[i] - positions.items[i - 1];
                    max_gap = @max(max_gap, gap);
                }
                if (max_gap < self.config.proximity_threshold) {
                    score += @min(self.config.proximity_bonus_max, self.config.proximity_threshold - max_gap);
                }
            }
        }

        for (original) |word| {
            if (matched.contains(word)) continue;
            if (wordBoundary(title_lower, word)) {
                score += self.config.title_weight;
            } else if (wordBoundary(desc_lower, word)) {
                score += self.config.desc_weight;
            } else if (wordBoundary(content_lower, word)) {
                score += self.config.content_weight;
            }
            try matched.put(word, {});
        }

        var it = expanded.iterator();
        while (it.next()) |entry| {
            const word = entry.key_ptr.*;
            const weight = entry.value_ptr.*;
            if (matched.contains(word)) continue;
            if (wordBoundary(title_lower, word)) {
                score += self.config.title_weight * weight / 7;
            } else if (wordBoundary(desc_lower, word)) {
                score += self.config.desc_weight * weight / 7;
            } else if (wordBoundary(content_lower, word)) {
                score += self.config.content_weight * weight / 7;
            }
            try matched.put(word, {});
        }

        const doc_length = title_lower.len + desc_lower.len + content_lower.len;
        if (doc_length > 0) {
            score = @intFromFloat(@as(f32, @floatFromInt(score)) / @log10(@as(f32, @floatFromInt(doc_length))));
        }

        return score;
    }

    // Main search function
    pub fn search(self: *ZigSmartSearch, query: []const u8) !std.ArrayList(SearchResult) {
        var original_words = try self.preprocess(query);
        defer {
            for (original_words.items) |w| self.allocator.free(w);
            original_words.deinit();
        }

        var expanded_words = try self.expandWords(original_words.items);
        defer expanded_words.deinit();

        var results = std.ArrayList(SearchResult).init(self.allocator);
        defer results.deinit();

        for (self.documents) |v| {
            const doc = v.object;
            const score = try self.calculateScore(doc, original_words.items, expanded_words);
            if (score > 0) {
                try results.append(.{ .doc = doc, .score = score });
            }
        }

        std.mem.sortUnstable(
            SearchResult,
            results.items,
            {},
            struct {
                fn lessThan(_: void, a: SearchResult, b: SearchResult) bool {
                    return a.score > b.score;
                }
            }.lessThan,
        );

        var final_results = std.ArrayList(SearchResult).init(self.allocator);
        for (results.items[0..@min(self.config.max_results, results.items.len)]) |r| {
            try final_results.append(r);
        }

        return final_results;
    }
};
