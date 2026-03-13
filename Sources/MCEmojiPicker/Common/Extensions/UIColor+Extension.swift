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

extension UIColor {
    /// Background color for `MCEmojiPickerView`.
    ///
    /// This is a standard color from UIKit - `.systemGroupedBackground`.
    static let popoverBackgroundColor = UIColor(
        light:  UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0),
        dark: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
    )
    /// Background color for `MCEmojiSkinTonePickerBackgroundView` and `MCEmojiPreviewView`.
    ///
    /// The colors were taken from similar iOS elements.
    static let previewAndSkinToneBackgroundViewColor = UIColor(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        dark: UIColor(red: 0.45, green: 0.45, blue: 0.46, alpha: 1.0)
    )
}

// MARK: - Intent Design Token Colors
// Values align with App's IMColorKey defaultColor for each semantic token.
extension UIColor {
    /// Matches App's backgroundNeutralSecondary — sheet / panel background.
    static let mcBackgroundNeutralSecondary = UIColor(
        light: .white,
        dark: UIColor(red: 70/255.0, green: 67/255.0, blue: 63/255.0, alpha: 1.0) // #46433F
    )
    /// Matches App's backgroundNeutralTertiary — search bar background.
    static let mcBackgroundNeutralTertiary = UIColor(
        light: UIColor(red: 246/255.0, green: 243/255.0, blue: 242/255.0, alpha: 1.0), // #F6F3F2
        dark: UIColor(red: 46/255.0, green: 44/255.0, blue: 40/255.0, alpha: 1.0) // #2E2C28
    )
    /// Matches App's contentNeutralTertiary — section header text.
    static let mcContentNeutralTertiary = UIColor(
        light: UIColor(red: 137/255.0, green: 135/255.0, blue: 133/255.0, alpha: 1.0), // #898785
        dark: UIColor(red: 199/255.0, green: 197/255.0, blue: 196/255.0, alpha: 1.0) // #C7C5C4
    )
    /// Matches App's contentNeutralReverseTertiary — grabber, search icon.
    static let mcContentNeutralReverseTertiary = UIColor(
        light: UIColor(red: 199/255.0, green: 197/255.0, blue: 196/255.0, alpha: 1.0), // #C7C5C4
        dark: UIColor(red: 105/255.0, green: 101/255.0, blue: 99/255.0, alpha: 1.0) // #696563
    )
    /// Matches App's extensionReverse80SecondaryOverlay — emoji row card background.
    static let mcExtensionReverse80SecondaryOverlay = UIColor(
        light: UIColor(white: 1.0, alpha: 0.8),
        dark: UIColor(white: 0.0, alpha: 0.8)
    )
}

extension UIColor {
    /// Adds support for dark and light interface style modes.
    convenience init(light: UIColor, dark: UIColor) {
        if #available(iOS 13.0, *) {
            self.init(dynamicProvider: { trait in
                trait.userInterfaceStyle == .dark ? dark : light
            })
        } else {
            self.init(cgColor: light.cgColor)
        }
    }
}
