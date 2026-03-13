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

/// Protocol for the `MCEmojiPickerViewModel`.
protocol MCEmojiPickerViewModelProtocol {
    var showEmptyEmojiCategories: Bool { get set }
    var emojiCategories: [MCEmojiCategory] { get }
    var selectedEmoji: Observable<MCEmoji?> { get set }
    var selectedEmojiCategoryIndex: Observable<Int> { get set }
    var searchText: String { get set }
    func clearSelectedEmoji()
    func numberOfSections() -> Int
    func numberOfItems(in section: Int) -> Int
    func emoji(at indexPath: IndexPath) -> MCEmoji
    func sectionHeaderName(for section: Int) -> String
    func updateEmojiSkinTone(_ skinToneRawValue: Int, in indexPath: IndexPath) -> MCEmoji
}

final class MCEmojiPickerViewModel: MCEmojiPickerViewModelProtocol {
    
    // MARK: - Public Properties
    
    public var selectedEmoji = Observable<MCEmoji?>(value: nil)
    public var selectedEmojiCategoryIndex = Observable<Int>(value: 0)
    public var showEmptyEmojiCategories = false
    
    public var searchText: String = "" {
        didSet {
            rebuildFilteredCategories()
        }
    }
    
    public var emojiCategories: [MCEmojiCategory] {
        if searchText.isEmpty {
            return allEmojiCategories.filter({ showEmptyEmojiCategories || $0.emojis.count > 0 })
        }
        return filteredCategories
    }
    
    // MARK: - Private Properties
    
    private var allEmojiCategories = [MCEmojiCategory]()
    private var filteredCategories = [MCEmojiCategory]()
    
    // MARK: - Initializers

    /// - Parameter locale: BCP-47 language tag used to select the keyword file.
    ///   Pass `Localize.currentLanguage()` from the host app.
    ///   Defaults to the system-preferred language when `nil`.
    init(locale: String? = nil) {
        allEmojiCategories = MCUnicodeManager(locale: locale).getEmojisForCurrentIOSVersion()
        selectedEmoji.bind { emoji in
            emoji?.incrementUsageCount()
        }
    }

    /// Initializer that accepts a pre-built unicodeManager (used in tests).
    init(unicodeManager: MCUnicodeManagerProtocol) {
        allEmojiCategories = unicodeManager.getEmojisForCurrentIOSVersion()
        selectedEmoji.bind { emoji in
            emoji?.incrementUsageCount()
        }
    }
    
    // MARK: - Public Methods
    
    public func clearSelectedEmoji() {
        selectedEmoji.value = nil
    }
    
    public func numberOfSections() -> Int {
        return emojiCategories.count
    }
    
    public func numberOfItems(in section: Int) -> Int {
        return emojiCategories[section].emojis.count
    }
    
    public func emoji(at indexPath: IndexPath) -> MCEmoji {
        return emojiCategories[indexPath.section].emojis[indexPath.row]
    }
    
    public func sectionHeaderName(for section: Int) -> String {
        return emojiCategories[section].categoryName
    }
    
    public func updateEmojiSkinTone(_ skinToneRawValue: Int, in indexPath: IndexPath) -> MCEmoji {
        let categoryType: MCEmojiCategoryType = emojiCategories[indexPath.section].type
        let allCategoriesIndex: Int = allEmojiCategories.firstIndex { $0.type == categoryType } ?? 0

        // When search is active, emojiCategories is a filtered subset.
        // indexPath.row refers to the filtered list, NOT allEmojiCategories,
        // so we must match by emojiKeys to find the correct position in the full list.
        let filteredEmoji = emojiCategories[indexPath.section].emojis[indexPath.row]
        guard let allEmojiIndex = allEmojiCategories[allCategoriesIndex].emojis.firstIndex(where: {
            $0.emojiKeys == filteredEmoji.emojiKeys
        }) else {
            return filteredEmoji
        }

        allEmojiCategories[allCategoriesIndex].emojis[allEmojiIndex].set(skinToneRawValue: skinToneRawValue)
        return allEmojiCategories[allCategoriesIndex].emojis[allEmojiIndex]
    }
    
    // MARK: - Private Methods
    
    private func rebuildFilteredCategories() {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            filteredCategories = []
            return
        }
        
        filteredCategories = allEmojiCategories.compactMap { category in
            let matched = category.emojis.filter { emoji in
                if emoji.searchTags.isEmpty {
                    // Fallback for emojis without injected tags (should not happen in practice)
                    return emoji.searchKey.lowercased().contains(query)
                }
                return emoji.searchTags.contains { $0.hasPrefix(query) }
            }
            guard !matched.isEmpty else { return nil }
            return MCEmojiCategory(type: category.type, emojis: matched)
        }
    }
}
