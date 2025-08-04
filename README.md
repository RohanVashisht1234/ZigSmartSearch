# 🔍 ZigSmartSearch: High-Speed Semantic Search in Zig

**ZigSmartSearch** is a blazing-fast semantic search library written in **Zig**, built for concept-based searching across JSON datasets. Instead of relying on exact string matching, it expands queries using lemmatization and a dictionary of weighted synonyms—ideal for document repositories with rich content.

> ⭐️ Star the repo to support the project!

---

## 🌟 Features at a Glance

* **📖 Dictionary-Based Expansion**
  Understands meaning through a custom JSON dictionary of weighted related terms.

* **🧠 Lemmatized Matching**
  Uses base-form mapping to capture word variations and improve relevance.

* **📚 Document Structure Support**
  Designed for documents with `title`, `description`, and `content` fields.

* **🎯 Precision Scoring**

  * Rewards exact and phrase matches.
  * Penalizes irrelevant terms.
  * Adds bonuses for term proximity.
  * Normalized for document length fairness.

* **⚡ Built for Speed**
  Powered by Zig for low-latency searching and memory efficiency.

* **🛠 Developer Friendly**
  Debug logging, customization hooks, and extensibility for custom rules.

---

## 📁 Input Files

### `database.json`

A JSON array of documents:

```json
[
  {
    "title": "Zig Clib",
    "description": "A C library binding tool for Zig projects",
    "content": "This project simplifies binding Zig code to C libraries."
  }
]
```

### `simplified_dictionary.json`

A mapping of base terms to weighted expansions:

```json
{
  "library": "collection reusable functions code",
  "bind": "connect link wrap interface"
}
```

### `lemmatizeWordMap.zig` and `nonEmphasisWords.zig`

* `lemmatizeWordMap.zig`: Reduces words to root forms (e.g. `"binding"` → `"bind"`).
* `nonEmphasisWords.zig`: Defines stop words like "the", "is", etc.

---

## 🔧 How It Works

1. **Query Preprocessing**

   * Converts query to lowercase and splits on spaces/hyphens/newlines.
   * Removes stop words and short terms.
   * Keeps essential keywords for matching.

2. **Keyword Expansion**

   * Weights: 10 (original), 8 (lemmatized), 5/4 (dictionary expansions).
   * Max 3 expansions per word for speed-quality balance.

3. **Scoring Logic**

   * Uses strict word boundaries for matches.
   * Exact match scores:

     * Title: 70
     * Description: 60
     * Content: 50
   * Expanded match scores: scaled by weight and location.
   * Full phrase bonus: up to 90.
   * Proximity bonus: up to 20.
   * Score is normalized by document size.

4. **Top Results**

   * Returns top 10 documents.
   * Includes debug info with matched keywords and scores.

---

## 📊 Scoring Table

| Match Type      | Title     | Description | Content   |
| --------------- | --------- | ----------- | --------- |
| Exact           | 70        | 60          | 50        |
| Expanded        | 10×w      | 7×w         | 5×w       |
| Phrase Bonus    | +90       | +80         | +70       |
| Proximity Bonus | +Up to 20 | +Up to 20   | +Up to 20 |

*Note*: `w = weight` (10, 8, 5, or 4). Final scores are length-normalized.

---

## 🚀 Get Started

### 📦 Install

```bash
zig fetch --save "https://github.com/RohanVashisht1234/ZigSmartSearch/archive/refs/tags/v0.0.1.tar.gz"
```

In your `build.zig`:

```zig
const ZigSmartSearch = b.dependency("ZigSmartSearch", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("ZigSmartSearch", ZigSmartSearch.module("ZigSmartSearch"));
```

---

### 🧪 Example Usage

```zig
const ZigSmartSearch = @import("ZigSmartSearch").ZigSmartSearch;
const std = @import("std");
const database = @embedFile("database.json");

pub fn main() !void {
    var instance = try ZigSmartSearch.init(
        std.heap.c_allocator,
        database,
        ZigSmartSearch.default_config,
    );
    defer instance.deinit();

    const results = try instance.search("game");
    defer results.deinit();

    for (results.items, 0..) |result, i| {
        const title:std.json.Value = result.doc.get("title") orelse .{ .string = "" };
        const desc:std.json.Value = result.doc.get("description") orelse .{ .string = "" };
        std.debug.print("{d}. [{d:3}] {s}\n", .{ i + 1, result.score, title.string });
        std.debug.print("     {s}\n\n", .{desc.string});
    }
}
```

For testing, you can download [database.json](./example/database.json) inside your src folder.

**Example Output:**

```
Query:     bind zig library
Processed: [bind, zig, library]
Expanded:  [bind, collection, connect, functions, interface, library, link, reusable, wrap, zig]
------------------------------------------------------------
Top Matches:

1. [152] Zig Clib
     A C library binding tool for Zig projects

2. [95] Zig Foreign Interface
     Simplified bindings for Zig interoperability
```

**Debug Output (stderr):**

```
Document title: Zig Clib, score: 152, matched: [bind, library, connect, zig]
```

---

## 💡 Use Cases

* ✅ Semantic search for documentation, packages, READMEs.
* ✅ Lightweight offline alternative to vector search.
* ✅ Prototyping NLP pipelines in Zig.
* ✅ Ideal for domain-specific datasets.

---

## 🤝 Contribute

Open to improvements! Ideas for future features:

* 🔎 Fuzzy matching / typo tolerance
* 🎨 Matched term highlighting
* 🔗 Backend integration (FAISS, SQLite, etc.)
* 🧠 Expandable dictionaries for other ecosystems

PRs and issues are welcome → [ZigSmartSearch GitHub Repo](https://github.com/RohanVashisht1234/ZigSmartSearch)

---

## 📬 Feedback

Submit issues or feature requests via [GitHub Issues](https://github.com/RohanVashisht1234/ZigSmartSearch/issues).
Join the Zig community to share ideas and get support!
