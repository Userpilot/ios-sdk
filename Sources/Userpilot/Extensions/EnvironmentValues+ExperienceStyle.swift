//
//  EnvironmentValues+ExperienceStyle.swift
//  Userpilot SDK
//
//  Created by Userpilot on 10/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Carries the experience style down the SwiftUI view tree.
//

import SwiftUI

private struct ExperienceStyleKey: EnvironmentKey {
    static let defaultValue = UPExperienceStyle()
}

extension EnvironmentValues {
    /// The theme of what is on screen (`UPExperienceStyle`). The root view sets it for each region, and each
    /// carousel page sets its own; widgets read it instead of taking colors and fonts.
    var experienceStyle: UPExperienceStyle {
        get { self[ExperienceStyleKey.self] }
        set { self[ExperienceStyleKey.self] = newValue }
    }
}
