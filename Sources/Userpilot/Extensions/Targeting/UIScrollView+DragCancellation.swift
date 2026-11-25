//
//  UIScrollView+DragCancellation.swift
//  Userpilot SDK
//
//  Created by Userpilot on 24/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Ends a user's drag in progress when a tooltip reveals over the scroll view. Main-thread only.
//

import UIKit

internal extension UIScrollView {

    /// Ends the user's drag in progress, as UIKit does when a gesture is taken away, so the rest of
    /// that touch no longer scrolls. Toggling the pan recognizer cancels it; with no finger down
    /// nothing happens.
    func userpilotCancelDragInProgress() {
        guard isTracking else { return }
        panGestureRecognizer.isEnabled = false
        panGestureRecognizer.isEnabled = true
    }
}
