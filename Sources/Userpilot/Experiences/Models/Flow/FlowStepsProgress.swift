//
//  FlowStepsProgress.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The progress rule the Flow step renderers share: the tooltip card, the carousel and the slideout.
//

import Foundation

/// A Flow step's place in its progress view, shared by the tooltip card, carousel and slideout. Built from the
/// server's `steps_count` and the step's `position - 1`, either of which can be bad data.
internal struct FlowStepsProgress {
    /// The whole Flow's `steps_count`, as the server sent it.
    let stepsCount: Int

    /// The step's `position - 1`, as the server sent it.
    let stepIndex: Int

    /// A single step has no sequence to display and a bad count none to draw, whatever the theme enables.
    var isShown: Bool {
        stepsCount > 1
    }

    /// The step's 0-based index, kept inside the drawn steps.
    var index: Int {
        min(max(stepIndex, 0), max(stepsCount - 1, 0))
    }
}
