//
//  View+ExperienceText.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Experience text size and font modifiers for SwiftUI views.
//

import SwiftUI

extension View {
    /// Applied once per SwiftUI root: authored sizes when scaling is off, the capped user size when on.
    func experienceTextSize(scalingEnabled: Bool) -> some View {
        transformEnvironment(\.sizeCategory) { $0 = ExperienceFonts.textSize($0, scalingEnabled: scalingEnabled) }
    }

    /// Theme family at the resolved size; re-evaluates when the size category changes.
    func experienceFont(_ family: String?, size: CGFloat, bold: Bool = false, italic: Bool = false) -> some View {
        UPExperienceFont(label: self, family: family, size: size, bold: bold, italic: italic)
    }
}

/// A wrapper view rather than a ViewModifier: the SDK's own `Content` and `Environment` types shadow SwiftUI's.
private struct UPExperienceFont<Label: View>: View {
    @SwiftUI.Environment(\.sizeCategory) private var sizeCategory
    let label: Label
    let family: String?
    let size: CGFloat
    let bold: Bool
    let italic: Bool

    var body: some View {
        label.font(Font(ExperienceFonts.font(
            family: family, size: size, bold: bold, italic: italic, category: sizeCategory)))
    }
}
