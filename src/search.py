#!/usr/bin/env python3
"""
🔍 Advanced Lemmatized Dictionary-Based Semantic Search

Usage:
    python3 search.py "your query here" ./database.json

Searches a JSON database of documents using concept-based semantic matching
via lemmatization and dictionary expansion.
"""

import json
import sys
import re
from typing import Dict, List, Tuple

# ------------------------------------------------------------------------------
# 📌 Configuration
# ------------------------------------------------------------------------------
NON_EMPHASIS_WORDS = {
    "a", "an", "the", "and", "but", "if", "or", "because", "as", "until", "while",
    "of", "at", "by", "for", "with", "about", "against", "between", "into", "through",
    "during", "before", "after", "above", "below", "to", "from", "up", "down", "in", "out",
    "on", "off", "over", "under", "again", "further", "then", "once", "here", "there",
    "when", "where", "why", "how", "all", "any", "both", "each", "few", "more", "most",
    "other", "some", "such", "no", "nor", "not", "only", "own", "same", "so", "than",
    "too", "very", "can", "will", "just", "don", "should", "now", "is"
}

# ------------------------------------------------------------------------------
# 📖 Dictionary & Lemmatizer Loading
# ------------------------------------------------------------------------------
def load_dictionary(dict_path: str = "simplified_dictionary.json") -> Dict[str, str]:
    try:
        with open(dict_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"Warning: Could not load dictionary ({dict_path}): {e}")
        return {}

def load_lemmatizer(path: str = "lemmatize.tsv") -> Dict[str, str]:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return {line.split()[0]: line.split()[1] for line in f if line.strip()}
    except Exception as e:
        print(f"Warning: lemmatizer not loaded ({path}): {e}")
        return {}

LEMMATIZER = load_lemmatizer()

def lemmatize_word(word: str) -> str:
    return LEMMATIZER.get(word, word)

# ------------------------------------------------------------------------------
# 🧠 Query Processing
# ------------------------------------------------------------------------------
def preprocess_sentence(sentence: str) -> List[str]:
    cleaned = re.sub(r"[^\w\s]", " ", sentence.lower())
    return [w for w in cleaned.split() if w and w not in NON_EMPHASIS_WORDS]

def expand_words(words: List[str], dictionary: Dict[str, str]) -> List[str]:
    expanded = set()
    for word in words:
        expanded.add(word)
        expanded.add(lemmatize_word(word))
        for exp in dictionary.get(word, '').split():
            expanded.add(exp)
            expanded.add(lemmatize_word(exp))
    return list(expanded)

# ------------------------------------------------------------------------------
# 🔍 Scoring Logic
# ------------------------------------------------------------------------------
def calculate_score(doc: Dict, original: List[str], expanded: List[str]) -> int:
    score = 0
    matched = set()
    original_sentence = " ".join(original)

    title = (doc.get("title") or "").lower()
    desc = (doc.get("description") or "").lower()
    content = (doc.get("content") or "").lower()

    full_text = f"{title} {desc} {content}"

    if original_sentence and original_sentence in full_text:
        score += 90

    for word in original:
        if word in matched:
            continue
        if word in title:
            score += 70
        elif word in desc:
            score += 60
        elif word in content:
            score += 50
        matched.add(word)

    for word in expanded:
        if word in matched:
            continue
        if word in title:
            score += 10
        elif word in desc:
            score += 7
        elif word in content:
            score += 5
        matched.add(word)

    return score

# ------------------------------------------------------------------------------
# 🔎 Search Execution
# ------------------------------------------------------------------------------
def search_documents(query: str, db_path: str, dict_path: str) -> List[Tuple[Dict, int]]:
    dictionary = load_dictionary(dict_path)
    try:
        with open(db_path, 'r', encoding='utf-8') as f:
            documents = json.load(f)
    except Exception as e:
        print(f"Error reading database: {e}")
        return []

    original_words = preprocess_sentence(query)
    expanded_words = expand_words(original_words, dictionary)

    print(f"Query:     {query}")
    print(f"Processed: {original_words}")
    print(f"Expanded:  {expanded_words[:20]}{'...' if len(expanded_words) > 20 else ''}")
    print("-" * 60)

    results = []
    for doc in documents:
        score = calculate_score(doc, original_words, expanded_words)
        if score > 0:
            results.append((doc, score))

    return sorted(results, key=lambda x: x[1], reverse=True)

# ------------------------------------------------------------------------------
# ▶️ Main
# ------------------------------------------------------------------------------
def main():
    if len(sys.argv) != 3:
        print("Usage: python3 search.py \"query\" ./database.json")
        sys.exit(1)

    query = sys.argv[1]
    db_path = sys.argv[2]
    results = search_documents(query, db_path, "simplified_dictionary.json")

    if not results:
        print("No matches found.")
        return

    print(f"Top {min(10, len(results))} matches:\n")
    for i, (doc, score) in enumerate(results[:10], 1):
        print(f"{i}. [{score:3d}] {doc.get('title', 'N/A')}")
        print(f"     {doc.get('description', '')}\n")

if __name__ == "__main__":
    main()
