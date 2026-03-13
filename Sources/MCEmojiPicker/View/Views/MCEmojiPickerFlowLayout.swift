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

import UIKit

/// A UICollectionViewFlowLayout subclass that injects per-row decoration views
/// matching the Figma design: each emoji row has a semi-transparent rounded card behind it.
final class MCEmojiPickerFlowLayout: UICollectionViewFlowLayout {

    // MARK: - Constants

    /// Vertical padding added above and below each emoji row card (matches Figma py-[6px]).
    private let rowVerticalPadding: CGFloat = 6

    // MARK: - Private State

    private var decorationAttributes: [UICollectionViewLayoutAttributes] = []

    // MARK: - Initializer

    override init() {
        super.init()
        register(MCEmojiRowDecorationView.self,
                 forDecorationViewOfKind: MCEmojiRowDecorationView.elementKind)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func prepare() {
        super.prepare()
        decorationAttributes = buildDecorationAttributes()
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var attrs = super.layoutAttributesForElements(in: rect) ?? []
        let visible = decorationAttributes.filter { $0.frame.intersects(rect) }
        attrs.append(contentsOf: visible)
        return attrs
    }

    override func layoutAttributesForDecorationView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        guard elementKind == MCEmojiRowDecorationView.elementKind else { return nil }
        return decorationAttributes.first {
            $0.indexPath == indexPath
        }
    }

    // MARK: - Private Helpers

    /// Groups cell layout attributes by row (same minY) and returns one decoration
    /// attribute per row, spanning the full cell area plus vertical padding.
    private func buildDecorationAttributes() -> [UICollectionViewLayoutAttributes] {
        guard let collectionView else { return [] }

        // Gather all cell attributes produced by the base layout.
        let allCellAttrs = (0..<collectionView.numberOfSections).flatMap { section in
            (0..<collectionView.numberOfItems(inSection: section)).compactMap {
                layoutAttributesForItem(at: IndexPath(item: $0, section: section))
            }
        }

        // Group cells into rows by their vertical origin (same minY → same row).
        var rowMap: [CGFloat: [UICollectionViewLayoutAttributes]] = [:]
        for attr in allCellAttrs {
            let key = attr.frame.minY
            rowMap[key, default: []].append(attr)
        }

        let contentLeft  = collectionView.contentInset.left
        let contentRight = collectionView.contentInset.right
        let collectionWidth = collectionView.bounds.width

        var result: [UICollectionViewLayoutAttributes] = []

        for (rowIndex, (_, rowAttrs)) in rowMap.sorted(by: { $0.key < $1.key }).enumerated() {
            guard let first = rowAttrs.first else { continue }

            // Card spans the full content width (inside collection view insets).
            let cardX      = contentLeft
            let cardY      = first.frame.minY - rowVerticalPadding
            let cardWidth  = collectionWidth - contentLeft - contentRight
            let cardHeight = first.frame.height + rowVerticalPadding * 2

            let decorAttr = UICollectionViewLayoutAttributes(
                forDecorationViewOfKind: MCEmojiRowDecorationView.elementKind,
                with: IndexPath(item: 0, section: rowIndex)
            )
            decorAttr.frame = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)
            // Place decoration behind cells (zIndex of cells defaults to 0).
            decorAttr.zIndex = -1
            result.append(decorAttr)
        }

        return result
    }
}
