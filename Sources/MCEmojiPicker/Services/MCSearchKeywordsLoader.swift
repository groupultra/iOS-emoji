// The MIT License (MIT)
//
// Copyright © 2022 Ivan Izyumkin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

/// Loads CLDR-based emoji search keywords for a given locale.
///
/// Only ONE language file is loaded at runtime — the one that best matches
/// the provided locale. This keeps memory usage minimal regardless of how
/// many language files are bundled.
///
/// File naming convention: `searchKeywords_{locale}.json`
/// Each file maps emoji characters to arrays of search keywords.
struct MCSearchKeywordsLoader {

    // MARK: - Public Interface

    /// Loads keywords for the specified locale, with BCP-47 cascade fallback.
    ///
    /// Resolution order (e.g. locale = "zh-Hans"):
    ///   1. `searchKeywords_zh-Hans.json`  ← exact match
    ///   2. `searchKeywords_zh.json`       ← base language
    ///   3. `searchKeywords_en.json`       ← final fallback
    ///
    /// - Parameter locale: BCP-47 language tag, e.g. `"zh-Hans"`, `"en"`, `"fr-CA"`.
    ///   Pass `Localize.currentLanguage()` (or equivalent) from the host app.
    /// - Returns: Dictionary mapping emoji character strings to keyword arrays,
    ///   or empty dictionary if no matching file is found.
    static func loadKeywords(for locale: String) -> [String: [String]] {
        for candidate in localeCandidates(for: locale) {
            if let dict = tryLoad(locale: candidate) {
                return dict
            }
        }
        return [:]
    }

    // MARK: - Private Helpers

    /// Generates a list of candidate locale strings from most specific to least.
    /// Always ends with "en" as the final fallback.
    ///
    /// "zh-Hans-CN" → ["zh-Hans-CN", "zh-Hans", "zh", "en"]
    private static func localeCandidates(for locale: String) -> [String] {
        // Normalize underscore separators (e.g. "zh_Hans" → "zh-Hans")
        let normalized = locale.replacingOccurrences(of: "_", with: "-")
        var candidates: [String] = []
        var parts = normalized.components(separatedBy: "-")
        while !parts.isEmpty {
            candidates.append(parts.joined(separator: "-"))
            parts.removeLast()
        }
        if !candidates.contains("en") {
            candidates.append("en")
        }
        return candidates
    }

    /// Attempts to load and decode a keyword JSON file for the given locale string.
    private static func tryLoad(locale: String) -> [String: [String]]? {
        guard let url = Bundle.module.url(
            forResource: "searchKeywords_\(locale)",
            withExtension: "json"
        ) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: [String]].self, from: data)
    }
}
