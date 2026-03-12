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

public protocol MCEmojiPickerDelegate: AnyObject {
    func didGetEmoji(emoji: String)
}

public final class MCEmojiPickerViewController: UIViewController {
    
    // MARK: - Public Properties
    
    public weak var delegate: MCEmojiPickerDelegate?
    
    public var isDismissAfterChoosing: Bool = true

    /// 为 false 时不渲染半透明遮罩（由外部调用方自行提供暗化背景）
    public var showsDimBackground: Bool = true

    /// emoji picker 开始退场动画时调用（用于同步外部过渡动画）
    public var onWillDismiss: (() -> Void)?

    /// emoji picker 完全从视图层级移除后调用（用于外部清理）
    public var onDismiss: (() -> Void)?

    public var selectedEmojiCategoryTintColor: UIColor? {
        didSet {
            guard let selectedEmojiCategoryTintColor = selectedEmojiCategoryTintColor else { return }
            emojiPickerView.selectedEmojiCategoryTintColor = selectedEmojiCategoryTintColor
        }
    }
    
    public var feedBackGeneratorStyle: UIImpactFeedbackGenerator.FeedbackStyle? = .light {
        didSet {
            guard let feedBackGeneratorStyle = feedBackGeneratorStyle else {
                generator = nil
                return
            }
            generator = UIImpactFeedbackGenerator(style: feedBackGeneratorStyle)
        }
    }
    
    /// Container height for the bottom sheet (default 530, matching Figma).
    public var sheetHeight: CGFloat = 530
    
    // MARK: - UI
    
    private let dimView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        return view
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(
            light: .white,
            dark: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
        )
        view.layer.cornerRadius = 24
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        return view
    }()
    
    // MARK: - Private Properties
    
    private var generator: UIImpactFeedbackGenerator? = UIImpactFeedbackGenerator(style: .light)
    private var viewModel: MCEmojiPickerViewModel = MCEmojiPickerViewModel()
    private var containerBottomConstraint: NSLayoutConstraint!
    private lazy var emojiPickerView: MCEmojiPickerView = {
        let categories = viewModel.emojiCategories.map { $0.type }
        return MCEmojiPickerView(categoryTypes: categories, delegate: self)
    }()
    
    // MARK: - Initializers
    
    public init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        bindViewModel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life Cycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        if !showsDimBackground {
            dimView.backgroundColor = .clear
        }
        setupUI()
        setupKeyboardObservers()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animateIn()
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.post(name: .MCEmojiPickerDidDisappear, object: nil)
        onDismiss?()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        view.addSubview(dimView)
        view.addSubview(containerView)
        containerView.addSubview(emojiPickerView)
        
        emojiPickerView.translatesAutoresizingMaskIntoConstraints = false
        dimView.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerBottomConstraint,
            containerView.heightAnchor.constraint(equalToConstant: sheetHeight),
            
            emojiPickerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            emojiPickerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            emojiPickerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            emojiPickerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDimTap))
        dimView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    
    @objc private func handleDimTap() {
        dismissWithAnimation()
    }
    
    private func dismissWithAnimation() {
        view.endEditing(true)
        onWillDismiss?()
        animateOut {
            self.dismiss(animated: false)
        }
    }
    
    // MARK: - Keyboard
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = notification.userInfo,
              let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }
        
        containerBottomConstraint.constant = -71
        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curveValue << 16)) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info = notification.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }
        
        containerBottomConstraint.constant = 0
        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curveValue << 16)) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Private Methods
    
    private func bindViewModel() {
        viewModel.selectedEmoji.bind { [unowned self] emoji in
            guard let emoji = emoji else { return }
            feedbackImpactOccurred()
            delegate?.didGetEmoji(emoji: emoji.string)
            if isDismissAfterChoosing {
                dismissWithAnimation()
            }
        }
        viewModel.selectedEmojiCategoryIndex.bind { [unowned self] categoryIndex in
            self.emojiPickerView.updateSelectedCategoryIcon(with: categoryIndex)
        }
    }
    
    // MARK: - Animations
    
    private func animateIn() {
        let initialTransform = CGAffineTransform(translationX: 0, y: sheetHeight)
        containerView.transform = initialTransform
        dimView.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.containerView.transform = .identity
            self.dimView.alpha = 1
        }
    }
    
    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: self.sheetHeight)
            self.dimView.alpha = 0
        }) { _ in
            completion()
        }
    }
}

// MARK: - EmojiPickerViewDelegate

extension MCEmojiPickerViewController: MCEmojiPickerViewDelegate {
    func didChoiceEmojiCategory(at index: Int) {
        updateCurrentSelectedEmojiCategoryIndex(with: index)
    }
    
    func numberOfSections() -> Int {
        viewModel.numberOfSections()
    }
    
    func numberOfItems(in section: Int) -> Int {
        viewModel.numberOfItems(in: section)
    }
    
    func emoji(at indexPath: IndexPath) -> MCEmoji {
        viewModel.emoji(at: indexPath)
    }
    
    func sectionHeaderName(for section: Int) -> String {
        viewModel.sectionHeaderName(for: section)
    }
    
    func getCurrentSelectedEmojiCategoryIndex() -> Int {
        viewModel.selectedEmojiCategoryIndex.value
    }
    
    func updateCurrentSelectedEmojiCategoryIndex(with index: Int) {
        viewModel.selectedEmojiCategoryIndex.value = index
    }
    
    func getEmojiPickerFrame() -> CGRect {
        containerView.frame
    }
    
    func updateEmojiSkinTone(_ skinToneRawValue: Int, in indexPath: IndexPath) {
        viewModel.selectedEmoji.value = viewModel.updateEmojiSkinTone(
            skinToneRawValue,
            in: indexPath
        )
    }
    
    func feedbackImpactOccurred() {
        generator?.impactOccurred()
    }
    
    func didChoiceEmoji(_ emoji: MCEmoji?) {
        viewModel.selectedEmoji.value = emoji
    }
    
    func searchEmojis(with text: String) {
        viewModel.searchText = text
        emojiPickerView.reloadCollectionView()
    }
}
