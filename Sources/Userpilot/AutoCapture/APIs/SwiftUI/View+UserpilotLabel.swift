//
//  View+UserpilotLabel.swift
//  Userpilot
//
//  Created by Motasem Hamed
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  View+UserpilotLabel provides a SwiftUI modifier that attaches stable analytics metadata
//  (custom text and a logical view type) to the underlying UIKit view tree for autocapture.
//

import SwiftUI
import UIKit

// MARK: - Public API

/// Extension for attaching Userpilot-defined labels to SwiftUI views for autocapture.
///
/// SwiftUI uses protocol extensions; API is `public` (not `open`—only classes support `open`).
public extension View {

    /// Attaches a stable label and semantic view type to this view for mobile autocapture.
    ///
    /// Use this when you want autocapture events to report a specific `element_text` and a
    /// readable `element_type` (for example `"Button"` or `"Text"`) instead of relying only
    /// on private SwiftUI/UIKit class names from hit-testing.
    ///
    /// ## How it works
    ///
    /// The modifier inserts a hidden `UIViewRepresentable` in the **background** of the view.
    /// That bridge (`LabelCarrierView`) resolves a suitable UIKit host among siblings or
    /// ancestors (controls, labels, images, text views) and stores:
    ///
    /// - `userpilotLabel` — string shown as captured text when applicable
    /// - `userpilotLabelViewType` — short name derived from the SwiftUI type (e.g. `Button`)
    ///
    /// Autocapture code reads these values from ``UIView`` (see `UIView+UserpilotLabel.swift`).
    /// The carrier re-applies when the view moves in the hierarchy or lays out, and clears
    /// associated values when removed.
    ///
    /// ## Usage examples
    ///
    /// ```swift
    /// Button("Submit") { send() }
    ///     .userpilotLabel("Submit order")
    ///
    /// Text("Balance")
    ///     .userpilotLabel("Account balance label")
    ///
    /// HStack {
    ///     Image(systemName: "star")
    ///     Text("Favorite")
    /// }
    /// .onTapGesture { toggleFavorite() }
    /// .userpilotLabel("Favorite row")
    /// ```
    ///
    /// ## Important notes
    ///
    /// - Pass `nil` if you need to clear a previously applied label when content is conditional.
    /// - Target resolution prefers a **taggable** sibling under the same UIKit parent (typical
    ///   for `.background` placement), then walks up for the nearest taggable ancestor.
    /// - Logical type names are best-effort from `String(reflecting:)` of `Self`; unknown types
    ///   fall back to `String(describing: Self.self)`.
    ///
    /// - Parameter label: Optional string used as capture text when this view (or its resolved
    ///   UIKit host) participates in an interaction event.
    /// - Returns: The same view with background metadata wiring applied.
    func userpilotLabel(_ label: String?) -> some View {
        background(
            UserpilotLabelInjector(
                label: label,
                viewType: UserpilotSwiftUIViewTypeResolver.resolveType(for: Self.self)
            )
        )
    }
}

// MARK: - Private

/// Bridges SwiftUI label metadata onto UIKit via a background representable.
private struct UserpilotLabelInjector: UIViewRepresentable {

    let label: String?
    let viewType: String

    func makeUIView(context: Context) -> LabelCarrierView {
        let view = LabelCarrierView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: LabelCarrierView, context: Context) {
        uiView.setLabel(label, viewType: viewType)
    }
}

/// Hidden view that assigns `userpilotLabel` / `userpilotLabelViewType` to a resolved UIKit target.
private final class LabelCarrierView: UIView {

    private var appliedToView: UIView?
    private var label: String?
    private var viewType: String?

    func setLabel(_ label: String?, viewType: String) {
        self.label = label
        self.viewType = viewType
        applyLabelIfPossible()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyLabelIfPossible()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyLabelIfPossible()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        applyLabelIfPossible()
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        appliedToView?.userpilotLabel = nil
        appliedToView?.userpilotLabelViewType = nil
        appliedToView = nil
    }

    // MARK: - Apply label

    private func applyLabelIfPossible() {
        guard let label, let viewType else { return }

        if appliedToView?.userpilotLabel == label,
           appliedToView?.userpilotLabelViewType == viewType {
            return
        }

        guard let target = findBestTargetView() else { return }

        target.userpilotLabel = label
        target.userpilotLabelViewType = viewType
        appliedToView = target
    }

    // MARK: - Target resolution

    private func findBestTargetView() -> UIView? {
        guard let parent = superview else { return nil }

        for sibling in parent.subviews where sibling !== self {
            if let match = sibling.deepestTaggableView {
                return match
            }
        }

        var current: UIView? = parent
        while let view = current {
            if view.isTaggable {
                return view
            }
            current = view.superview
        }

        return parent
    }
}

/// Maps SwiftUI `Self` type metadata to short names for `element_type` in autocapture.
private enum UserpilotSwiftUIViewTypeResolver {
    static func resolveType<T>(for viewType: T.Type) -> String {
        let reflected = String(reflecting: viewType).lowercased()
        if reflected.contains("button") { return "Button" }
        if reflected.contains("text") { return "Text" }
        if reflected.contains("toggle") { return "Toggle" }
        if reflected.contains("navigationlink") { return "NavigationLink" }
        return String(describing: viewType)
    }
}

// MARK: - Taggable detection (SwiftUI file–local)

private extension UIView {

    /// Deepest descendant (including self) considered a good host for SwiftUI-driven tagging.
    var deepestTaggableView: UIView? {
        if isTaggable { return self }

        for subview in subviews {
            if let match = subview.deepestTaggableView {
                return match
            }
        }

        return nil
    }

    /// UIKit view kinds that meaningfully represent interactive or readable SwiftUI content.
    var isTaggable: Bool {
        self is UIControl ||
        self is UILabel ||
        self is UIImageView ||
        self is UITextView
    }
}
