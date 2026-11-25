//
//  View+UserpilotTarget.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Adds stable targeting identity through a UIView marker behind a SwiftUI view.
//  The marker provides a native anchor where an accessibility element alone
//  may have no backing UIView.
//

import SwiftUI
import UIKit

// MARK: - Public API

public extension View {

    /// Gives this view a stable Userpilot identity so an anchored tooltip can be targeted at it.
    ///
    /// Builder capture records the identifier as the view's `userpilot_id`, and a
    /// tooltip whose selector has that `userpilot_id` anchors to it. The identifier
    /// is matched exactly and carries the highest weight in target resolution, so
    /// it wins over every incidental match (an accessibility label that happens to
    /// be identical, say) combined. It works without autocapture.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// Button("Save") { save() }
    ///     .userpilotTarget("save-profile")
    ///
    /// Image(systemName: "bell")
    ///     .userpilotTarget("notifications-bell")
    ///
    /// // Analytics text and tooltip identity on one view
    /// Button("Save") { save() }
    ///     .userpilotLabel("Save profile")
    ///     .userpilotTarget("save-profile")
    /// ```
    ///
    /// ## Choosing identifiers
    ///
    /// - Make them unique on the screen. Two views sharing an identifier are
    ///   indistinguishable to the SDK, and an ambiguous target is treated as a
    ///   failure rather than resolved arbitrarily — the tooltip will not show.
    /// - Keep them stable across releases. A renamed identifier breaks any
    ///   published tooltip pointing at it, the same way a renamed
    ///   `accessibilityIdentifier` would.
    /// - Prefer describing the element's role (`"save-profile"`) over its
    ///   current wording, so copy changes and translations do not invalidate it.
    /// - Keep personal data out of them.
    ///
    /// ## Notes
    ///
    /// - Targeting only: it sends no analytics text and text privacy settings do not
    ///   affect it. Naming a view in interaction events uses ``SwiftUI/View/userpilotLabel(_:)``.
    /// - An empty or whitespace-only identifier attaches nothing.
    /// - The marker is added as a background, so it takes exactly the size of
    ///   the view it modifies and the tooltip anchors to that frame.
    ///
    /// - Parameter identifier: Stable, unique identity for this view. A blank value attaches nothing.
    /// - Returns: The same view, targetable by Userpilot.
    func userpilotTarget(_ identifier: String) -> some View {
        background(UserpilotTargetMarker(identifier: identifier.attachableIdentity))
    }
}

private extension String {

    /// The identifier as given, or nil when blank so the modifier attaches nothing.
    var attachableIdentity: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

// MARK: - Bridge

/// Invisible bridge that plants a `UserpilotTargetView` behind the modified view.
private struct UserpilotTargetMarker: UIViewRepresentable {

    let identifier: String?

    func makeUIView(context: Context) -> UserpilotTargetView {
        UserpilotTargetView(identifier: identifier)
    }

    func updateUIView(_ uiView: UserpilotTargetView, context: Context) {
        uiView.userpilotID = identifier
    }
}

// MARK: - Marker View

/// Carries a Userpilot target identity in the UIKit tree, for the targeting
/// traversal to read.
///
/// Identity stays on this marker because `.background(...)` gives it the
/// modified view's frame. Forwarding identity to a guessed sibling or ancestor
/// could anchor the tooltip to a different rectangle.
internal final class UserpilotTargetView: UIView {

    /// The author-supplied target identity. Read by the targeting traversal.
    var userpilotID: String?

    /// Creates the marker.
    ///
    /// Interaction is disabled so the marker never intercepts a touch meant for
    /// the view it is sitting behind.
    init(identifier: String?) {
        self.userpilotID = identifier
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
