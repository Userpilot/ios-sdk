//
//  UPExperienceLayout.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Shared spacing and text sizes for the experience renderer.
//

import CoreGraphics

/// Shared element rhythm; native card margins remain separate from authored content.
internal enum UPExperienceLayout {
    static let spacing: CGFloat = 16
    static let buttonHeight: CGFloat = 50
    /// Text that used the system's default font: inputs, chips and placeholders.
    static let bodySize: CGFloat = 16
    /// Text that used `.footnote`: scale labels and character counters.
    static let footnoteSize: CGFloat = 13
}
