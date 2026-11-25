//
//  UIView+ScrollViews.swift
//  Userpilot SDK
//
//  Created by Userpilot on 24/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Finds the scroll views a waiting tooltip watches in its host window. Main-thread only.
//

import UIKit

internal extension UIView {

    /// Scrollable, non-hidden scroll views in this subtree, breadth first, from at most `visitLimit` views.
    func userpilotScrollViews(visitLimit: Int = 2_000) -> [UIScrollView] {
        var found: [UIScrollView] = []
        var queue: [UIView] = [self]
        var index = 0
        while index < queue.count {
            let view = queue[index]
            index += 1
            guard !view.isHidden else { continue }
            if let scrollView = view as? UIScrollView, scrollView.isScrollEnabled {
                found.append(scrollView)
            }
            queue.append(contentsOf: view.subviews.prefix(max(visitLimit - queue.count, 0)))
        }
        return found
    }
}
