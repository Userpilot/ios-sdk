//
//  UIView+LabelAttachment.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Finds label carriers and stores their attachment identity without retaining their owner.
//

import UIKit

private var labelAttachmentKey: UInt8 = 0

internal extension UIView {

    /// Tracks the writer without retaining the carrier or creating a view-hierarchy cycle.
    var userpilotLabelAttachmentID: UUID? {
        get { objc_getAssociatedObject(self, &labelAttachmentKey) as? UUID }
        set { objc_setAssociatedObject(self, &labelAttachmentKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Deepest descendant (including self) considered a good host for SwiftUI-driven tagging.
    var deepestTaggableView: UIView? {
        if isTaggable { return self }

        for subview in subviews {
            if let match = subview.deepestTaggableView {
                return match
            }
        }

        return nil
    }

    /// UIKit view kinds that meaningfully represent interactive or readable SwiftUI content.
    var isTaggable: Bool {
        self is UIControl ||
        self is UILabel ||
        self is UIImageView ||
        self is UITextView
    }
}
