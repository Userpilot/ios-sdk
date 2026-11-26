//
//  UPTooltipCardView+Sizing.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  How the tooltip card measures itself and reports that size upward.
//
//  Split out of `UPTooltipCardView.swift` only to keep that file under the
//  SwiftLint `file_length` limit; there is no other seam here.
//

import UIKit

internal extension UPTooltipCardView {

    // MARK: Sizing

    /// Measures the content and reports it upward when it has changed.
    ///
    /// Called from `layoutSubviews` rather than pushed on bind, because the
    /// measurement is only meaningful once Auto Layout has resolved a width for
    /// the text to wrap into.
    override func layoutSubviews() {
        super.layoutSubviews()
        reportPreferredContentSizeIfNeeded()
    }

    /// The size this content wants, given at most `width` to work with.
    ///
    /// Measured in two passes, and the first one matters. Asking for a fitting
    /// size at `.required` horizontal priority always returns exactly the width
    /// you passed in — so reporting that upward would pin the card to whatever
    /// width it happened to be laid out at, which is the full-width bottom
    /// fallback. The card would then never narrow to its content and would span
    /// the whole screen on iPad. So: find the *natural* width first, cap it, then
    /// measure the height at that resolved width.
    ///
    /// `ceil`'d because a fractional height leaves the last text line a
    /// sub-pixel short of its ascender and clips it at some scales.
    func measuredContentSize(fittingWidth width: CGFloat) -> CGSize {
        let available = min(width, TooltipLayoutEngine.defaultMaxWidth)

        let natural = systemLayoutSizeFitting(
            CGSize(width: available, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        let resolvedWidth = min(ceil(natural.width), available)

        let fitted = systemLayoutSizeFitting(
            CGSize(width: resolvedWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        return CGSize(width: resolvedWidth, height: ceil(fitted.height))
    }

    func reportPreferredContentSizeIfNeeded() {
        guard bounds.width > 0 else { return }

        let size = measuredContentSize(fittingWidth: bounds.width)
        guard size != reportedContentSize else { return }

        reportedContentSize = size
        onPreferredContentSizeChanged?(size)
    }
}
