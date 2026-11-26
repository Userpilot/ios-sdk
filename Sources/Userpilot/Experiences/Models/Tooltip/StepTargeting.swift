//
//  StepTargeting.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  A tooltip step's target; resolution owns native visibility and recovery.
//

import Foundation

/// A tooltip step's target: render config the Flow projection builds from the step's `target`, never a wire
/// model. Target selection never guesses a missing selector; the retry ladder is
/// `Constants.Theme.tooltipRetryIntervals`.
internal struct StepTargeting {
    /// A missing or unusable selector fails resolution.
    let selector: ElementSelector?
}
