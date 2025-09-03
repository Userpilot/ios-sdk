//
//  PaddingLabel.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 14/12/2024.
//

import UIKit

class PaddedLabel: UILabel {

    // Define padding for the label
    var textInsets = UIEdgeInsets.zero {
        didSet {
            setNeedsDisplay() // Redraw the label when padding changes
        }
    }

    override func drawText(in rect: CGRect) {
        // Apply the insets to the text drawing area
        let insetsRect = rect.inset(by: textInsets)
        super.drawText(in: insetsRect)
    }

    override var intrinsicContentSize: CGSize {
        // Adjust the intrinsic content size based on the padding
        let originalSize = super.intrinsicContentSize
        let width = originalSize.width + textInsets.left + textInsets.right
        let height = originalSize.height + textInsets.top + textInsets.bottom
        return CGSize(width: width, height: height)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        // Adjust the fitting size based on the padding
        let fittingSize = super.sizeThatFits(size)
        let width = fittingSize.width + textInsets.left + textInsets.right
        let height = fittingSize.height + textInsets.top + textInsets.bottom
        return CGSize(width: width, height: height)
    }
}
