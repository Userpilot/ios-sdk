//
//  UIView+TargetAvailability.swift
//  Userpilot SDK
//
//  Created by Userpilot on 04/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Detects an opaque view drawn above a tooltip target's centre. Main-thread only.
//

import UIKit

internal extension UIView {

    /// Whether an opaque view drawn above this view covers `point`, in window coordinates.
    ///
    /// Walks up from this view and checks the siblings drawn after each branch. Only an
    /// opaque background counts as a cover: transparent containers, images, blur and
    /// custom drawing never do, so a target that can be seen is not reported by mistake.
    /// SDK UI and the keyboard live in other windows and are never considered.
    func userpilotIsCovered(at point: CGPoint) -> Bool {
        var branch: UIView = self
        while let parent = branch.superview {
            if let index = parent.subviews.firstIndex(where: { $0 === branch }) {
                let drawnAfter = parent.subviews[parent.subviews.index(after: index)...]
                if drawnAfter.contains(where: { $0.userpilotCovers(point) }) { return true }
            }
            branch = parent
        }
        return false
    }

    /// This view, or a visible descendant, has an opaque background containing `point`.
    private func userpilotCovers(_ point: CGPoint) -> Bool {
        guard !isHidden, alpha > 0.01 else { return false }
        let containsPoint = convert(bounds, to: nil).contains(point)
        if containsPoint, userpilotHasOpaqueBackground { return true }
        // A clipping view hides any descendant drawn outside it.
        guard containsPoint || !clipsToBounds else { return false }
        return subviews.contains { $0.userpilotCovers(point) }
    }

    /// A fully opaque background colour and a combined alpha of at least 0.99.
    private var userpilotHasOpaqueBackground: Bool {
        guard let backgroundColor, backgroundColor.cgColor.alpha >= 1 else { return false }
        var alpha: CGFloat = 1
        var current: UIView? = self
        while let view = current {
            alpha *= view.alpha
            current = view.superview
        }
        return alpha >= 0.99
    }
}
