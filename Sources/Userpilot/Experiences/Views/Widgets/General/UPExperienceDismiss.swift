//
//  UPExperienceDismiss.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The close (×) control shown in an experience's header.
//

import SwiftUI

internal struct UPExperienceDismiss: View {
    let color: UIColor
    let action: () -> Void

    var body: some View {
        // Pinned to the trailing edge (the left in RTL).
        HStack {
            Spacer()
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(color))
                    .frame(width: 44, height: 44)
                    // A transparent frame isn't tappable on its own; the whole 44 pt square is the target.
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibility(label: Text("Close"))
        }
    }
}
