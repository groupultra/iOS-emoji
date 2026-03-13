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

protocol MCEmojiPickerViewDelegate: AnyObject {
    func didChoiceEmojiCategory(at index: Int)
    func didChoiceEmoji(_ emoji: MCEmoji?)
    func numberOfSections() -> Int
    func numberOfItems(in section: Int) -> Int
    func emoji(at indexPath: IndexPath) -> MCEmoji
    func sectionHeaderName(for section: Int) -> String
    func getCurrentSelectedEmojiCategoryIndex() -> Int
    func updateCurrentSelectedEmojiCategoryIndex(with index: Int)
    func getEmojiPickerFrame() -> CGRect
    func updateEmojiSkinTone(_ skinToneRawValue: Int, in indexPath: IndexPath)
    func feedbackImpactOccurred()
    func searchEmojis(with text: String)
}

final class MCEmojiPickerView: UIView {
    
    // MARK: - Public Properties
    
    public var selectedEmojiCategoryTintColor = Constants.defaultSelectedEmojiCategoryTintColor
    
    // MARK: - Constants
    
    private enum Constants {
        static let defaultSelectedEmojiCategoryTintColor = UIColor.systemBlue
        
        static let verticalScrollIndicatorTopInset = 8.0
        static let collectionViewContentInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        
        static let countOfEmojisInRow = 7.0
        static let collectionViewHeaderHeight = 30.0
        
        static let categoriesStackViewInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: -24)
        static let categoriesStackViewHeight: CGFloat = 52
        
        static let grabberWidth: CGFloat = 73
        static let grabberHeight: CGFloat = 4
        static let grabberTopInset: CGFloat = 11
        static let grabberColor: UIColor = .mcContentNeutralReverseTertiary

        static let searchBarHeight: CGFloat = 40
        static let searchBarTopInset: CGFloat = 32
        static let searchBarSideInset: CGFloat = 24
        static let searchBarCornerRadius: CGFloat = 12
        static let searchBarBackgroundColor: UIColor = .mcBackgroundNeutralTertiary
    }
    
    // MARK: - Private Properties
    
    private let emojiCategoryTypes: [MCEmojiCategoryType]
    
    private let grabberView: UIView = {
        let view = UIView()
        view.backgroundColor = Constants.grabberColor
        view.layer.cornerRadius = Constants.grabberHeight / 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var searchBar: UITextField = {
        let field = UITextField()
        field.backgroundColor = Constants.searchBarBackgroundColor
        field.layer.cornerRadius = Constants.searchBarCornerRadius
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Search"
        field.font = .systemFont(ofSize: 16)
        field.returnKeyType = .search
        field.clearButtonMode = .whileEditing
        field.delegate = self
        field.addTarget(self, action: #selector(searchTextDidChange), for: .editingChanged)
        
        let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        iconView.tintColor = .mcContentNeutralReverseTertiary
        iconView.contentMode = .scaleAspectFit
        iconView.frame = CGRect(x: 8, y: 0, width: 20, height: 20)
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 36, height: 20))
        container.addSubview(iconView)
        field.leftView = container
        field.leftViewMode = .always
        
        return field
    }()
    
    private let collectionView: UICollectionView = {
        let layout = MCEmojiPickerFlowLayout()
        layout.sectionHeadersPinToVisibleBounds = true
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.verticalScrollIndicatorInsets.top = Constants.verticalScrollIndicatorTopInset
        collectionView.contentInset = Constants.collectionViewContentInsets
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.keyboardDismissMode = .onDrag
        collectionView.register(
            MCEmojiCollectionViewCell.self,
            forCellWithReuseIdentifier: MCEmojiCollectionViewCell.reuseIdentifier
        )
        collectionView.register(
            MCEmojiSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: MCEmojiSectionHeader.reuseIdentifier
        )
        return collectionView
    }()
    
    private let categoriesBackgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let categoriesStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private var previewContainerView = UIView()
    private var categoryViews = [MCTouchableEmojiCategoryView]()
    private var didSetupLayout = false
    
    private weak var delegate: MCEmojiPickerViewDelegate?
    
    // MARK: - Initializers
    
    init(categoryTypes: [MCEmojiCategoryType] = MCEmojiCategoryType.allCases, delegate: MCEmojiPickerViewDelegate) {
        self.delegate = delegate
        self.emojiCategoryTypes = categoryTypes
        super.init(frame: .zero)
        setupBackgroundColor()
        setupDelegates()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life Cycle
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !didSetupLayout, bounds.width > 0 else { return }
        didSetupLayout = true
        setupCategoryViews()
        setupViewLayout()
    }
    
    // MARK: - Public Methods
    
    public func updateSelectedCategoryIcon(with categoryIndex: Int) {
        categoryViews.forEach({
            $0.updateCategoryViewState(selectedCategoryIndex: categoryIndex)
        })
    }
    
    public func reloadCollectionView() {
        collectionView.reloadData()
    }
    
    // MARK: - Private Methods
    
    private func setupBackgroundColor() {
        backgroundColor = .mcBackgroundNeutralSecondary
    }
    
    private func setupDelegates() {
        collectionView.delegate = self
        collectionView.dataSource = self

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    @objc private func handleBackgroundTap() {
        endEditing(true)
    }
    
    private func setupViewLayout() {
        categoriesBackgroundView.backgroundColor = .mcBackgroundNeutralSecondary
        
        let safeBottom = window?.safeAreaInsets.bottom
            ?? UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom }
                .first
            ?? 0
        
        addSubview(grabberView)
        addSubview(searchBar)
        addSubview(collectionView)
        addSubview(categoriesBackgroundView)
        addSubview(categoriesStackView)
        
        let searchBarBottom = Constants.searchBarTopInset + Constants.searchBarHeight + 12
        
        NSLayoutConstraint.activate([
            grabberView.topAnchor.constraint(equalTo: topAnchor, constant: Constants.grabberTopInset),
            grabberView.centerXAnchor.constraint(equalTo: centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: Constants.grabberWidth),
            grabberView.heightAnchor.constraint(equalToConstant: Constants.grabberHeight),
            
            searchBar.topAnchor.constraint(equalTo: topAnchor, constant: Constants.searchBarTopInset),
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.searchBarSideInset),
            searchBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.searchBarSideInset),
            searchBar.heightAnchor.constraint(equalToConstant: Constants.searchBarHeight),
            
            collectionView.topAnchor.constraint(equalTo: topAnchor, constant: searchBarBottom),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            categoriesBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            categoriesBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            categoriesBackgroundView.topAnchor.constraint(equalTo: categoriesStackView.topAnchor),
            categoriesBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            categoriesStackView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Constants.categoriesStackViewInsets.left
            ),
            categoriesStackView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: Constants.categoriesStackViewInsets.right
            ),
            categoriesStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -safeBottom),
            categoriesStackView.heightAnchor.constraint(equalToConstant: Constants.categoriesStackViewHeight),
        ])
        
        collectionView.contentInset.bottom = Constants.categoriesStackViewHeight + 8
        collectionView.verticalScrollIndicatorInsets.bottom = Constants.categoriesStackViewHeight + 8
    }
    
    private func setupCategoryViews() {
        guard categoryViews.isEmpty else { return }
        for categoryIndex in 0...emojiCategoryTypes.count - 1 {
            let categoryView = MCTouchableEmojiCategoryView(
                delegate: self,
                categoryIndex: categoryIndex,
                categoryType: emojiCategoryTypes[categoryIndex],
                selectedEmojiCategoryTintColor: selectedEmojiCategoryTintColor
            )
            categoryView.updateCategoryViewState(selectedCategoryIndex: .zero)
            categoryViews.append(categoryView)
            categoriesStackView.addArrangedSubview(categoryView)
        }
    }
    
    private func toggleCollectionScrollAbility(isEnabled: Bool) {
        collectionView.isScrollEnabled = isEnabled
    }
    
    private func scrollToHeader(for section: Int) {
        guard let cellFrame = collectionView.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: section))?.frame,
              let headerFrame = collectionView.collectionViewLayout.layoutAttributesForSupplementaryView(
                ofKind: UICollectionView.elementKindSectionHeader,
                at: IndexPath(item: .zero, section: section)
              )?.frame
        else { return }
        collectionView.setContentOffset(
            CGPoint(
                x:  -collectionView.contentInset.left,
                y: cellFrame.minY - headerFrame.height
            ),
            animated: false
        )
    }
    
    // MARK: - Search
    
    @objc private func searchTextDidChange() {
        delegate?.searchEmojis(with: searchBar.text ?? "")
    }
}

// MARK: - UITextFieldDelegate

extension MCEmojiPickerView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UICollectionViewDataSource

extension MCEmojiPickerView: UICollectionViewDataSource {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return delegate?.numberOfSections() ?? .zero
    }
    
    public func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return delegate?.numberOfItems(in: section) ?? .zero
    }
    
    public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: MCEmojiCollectionViewCell.reuseIdentifier,
                for: indexPath
              ) as? MCEmojiCollectionViewCell
        else { return UICollectionViewCell() }
        cell.configure(
            emoji: delegate?.emoji(at: indexPath),
            delegate: self
        )
        return cell
    }
    
    public func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let sectionHeader = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: MCEmojiSectionHeader.reuseIdentifier,
                for: indexPath
              ) as? MCEmojiSectionHeader
        else { return UICollectionReusableView() }
        sectionHeader.configure(
            with: delegate?.sectionHeaderName(
                for: indexPath.section
            ) ?? ""
        )
        return sectionHeader
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension MCEmojiPickerView: UICollectionViewDelegateFlowLayout {
    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        return CGSize(
            width: collectionView.frame.width,
            height: Constants.collectionViewHeaderHeight
        )
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let sideInsets = collectionView.contentInset.right + collectionView.contentInset.left
        let contentSize = collectionView.bounds.width - sideInsets
        return CGSize(
            width: contentSize / Constants.countOfEmojisInRow,
            height: contentSize / Constants.countOfEmojisInRow
        )
    }
    
    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        return .zero
    }
    
    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        return .zero
    }
}

// MARK: - UIScrollViewDelegate

extension MCEmojiPickerView: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let indexPathsForVisibleHeaders = collectionView.indexPathsForVisibleSupplementaryElements(
            ofKind: UICollectionView.elementKindSectionHeader
        ).sorted(by: { $0.section < $1.section })
        if let selectedEmojiCategoryIndex = indexPathsForVisibleHeaders.first?.section,
           delegate?.getCurrentSelectedEmojiCategoryIndex() != selectedEmojiCategoryIndex {
            delegate?.updateCurrentSelectedEmojiCategoryIndex(with: selectedEmojiCategoryIndex)
        }
    }
}

// MARK: - MCEmojiCollectionViewCellDelegate

extension MCEmojiPickerView: MCEmojiCollectionViewCellDelegate {
    func preview(_ emoji: MCEmoji?, in cell: MCEmojiCollectionViewCell) {
        guard let sourceView = window else { return }
        toggleCollectionScrollAbility(isEnabled: false)
        
        previewContainerView.removeFromSuperview()
        previewContainerView = MCEmojiPreviewView(
            emoji: emoji,
            sender: cell.emojiLabel,
            sourceView: sourceView
        )
        
        sourceView.addSubview(previewContainerView)
    }
    
    func choiceSkinTone(_ emoji: MCEmoji?, in cell: MCEmojiCollectionViewCell) {
        guard let sourceView = window else { return }
        toggleCollectionScrollAbility(isEnabled: false)
        delegate?.feedbackImpactOccurred()
        
        previewContainerView.removeFromSuperview()
        previewContainerView = MCEmojiSkinTonePickerContainerView(
            delegate: self,
            cell: cell,
            emoji: emoji,
            frame: sourceView.frame,
            sourceView: sourceView,
            emojiPickerFrame: delegate?.getEmojiPickerFrame() ?? .zero
        )
        
        sourceView.addSubview(previewContainerView)
    }
    
    func didSelect(_ emoji: MCEmoji?, in cell: MCEmojiCollectionViewCell) {
        if previewContainerView is MCEmojiPreviewView {
            toggleCollectionScrollAbility(isEnabled: true)
            previewContainerView.removeFromSuperview()
        }
        delegate?.didChoiceEmoji(emoji)
    }
}


// MARK: - EmojiCategoryViewDelegate

extension MCEmojiPickerView: MCEmojiCategoryViewDelegate {
    func didChoiceCategory(at index: Int) {
        scrollToHeader(for: index)
        delegate?.feedbackImpactOccurred()
        delegate?.didChoiceEmojiCategory(at: index)
    }
}

// MARK: - MCEmojiSkinTonePickerDelegate

extension MCEmojiPickerView: MCEmojiSkinTonePickerDelegate {
    func updateSkinTone(
        _ skinToneRawValue: Int,
        in cell: MCEmojiCollectionViewCell
    ) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        delegate?.updateEmojiSkinTone(skinToneRawValue, in: indexPath)
        UIView.performWithoutAnimation {
            collectionView.reloadData()
        }
    }
    
    func feedbackImpactOccurred() {
        delegate?.feedbackImpactOccurred()
    }
    
    func didEmojiSkinTonePickerDismissed() {
        toggleCollectionScrollAbility(isEnabled: true)
    }
}
