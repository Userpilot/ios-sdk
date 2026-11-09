//
//  UPExperienceClose.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The close (×) control shown in an experience's header.
//

import SwiftUI

/// The close (×) control in an experience's header: an SF Symbol in a 44 pt target that reaches into the side
/// margin, so the symbol ends on the content edge.
internal struct UPExperienceClose: View {
    let color: UIColor
    let action: () -> Void

    var body: some View {
        // Pinned to the trailing edge (the left in RTL).
        HStack {
            Spacer()
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: UPExperienceLayout.closeGlyphSize, weight: .semibold))
                    .foregroundColor(Color(color))
                    .frame(width: UPExperienceLayout.touchTargetSize, height: UPExperienceLayout.touchTargetSize)
                    // A transparent frame isn't tappable on its own; the whole 44 pt square is the target.
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibility(label: Text("Close"))
            // The symbol, not its target, lines up with the content edge.
            .padding(.trailing, -UPExperienceLayout.closeTargetInset)
        }
    }
}
