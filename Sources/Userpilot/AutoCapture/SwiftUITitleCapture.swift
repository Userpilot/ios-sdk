//
//  SwiftUITitleCapture.swift
//  Userpilot
//
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Internal helpers for SwiftUI interaction title enrichment.
//

import UIKit

internal enum SwiftUITitleCapturePolicy {

    static func shouldRun(config: Userpilot.Config, sourceView: UIView) -> Bool {
        guard config.enableInteractionAutoCapture else { return false }
        guard config.enableInteractionTextCapture || config.enableInteractionAccessibilityLabelCapture else {
            return false
        }
        guard config.enableSwiftUIInteractionTitleCapture else { return false }
        guard config.appFramework == .SwiftUI || sourceView.isInsideSwiftUIHost else { return false }

        if #available(iOS 26.0, *) {
            return true
        }
        return config.enableSwiftUIInteractionTitleCaptureBelowIOS26
    }
}

internal enum SwiftUITitleResolver {

    struct Result {
        let title: String
        let viewType: String
        let sourceView: UIView
    }

    static func resolveTitle(
        at point: CGPoint,
        in window: UIWindow,
        from sourceView: UIView,
        config: Userpilot.Config
    ) -> Result? {
        guard SwiftUITitleCapturePolicy.shouldRun(config: config, sourceView: sourceView) else {
            return nil
        }

        var best: Candidate?
        let context = ScanContext(point: point, window: window, config: config)
        collectCandidates(
            from: window,
            depth: 0,
            best: &best,
            context: context
        )

        guard let best else { return nil }
        return Result(title: best.title, viewType: best.viewType, sourceView: best.view)
    }

    private struct ScanContext {
        let point: CGPoint
        let window: UIWindow
        let config: Userpilot.Config
    }

    private struct Candidate {
        let title: String
        let viewType: String
        let view: UIView
        let area: CGFloat
        let depth: Int
    }

    private static func collectCandidates(
        from view: UIView,
        depth: Int,
        best: inout Candidate?,
        context: ScanContext
    ) {
        guard !view.isHidden, view.alpha > 0.01 else { return }

        let rect = view.convert(view.bounds, to: context.window)
        if rect.contains(context.point),
           let title = title(from: view, config: context.config) {
            consider(
                Candidate(
                    title: title,
                    viewType: swiftUIViewType(for: view),
                    view: view,
                    area: max(rect.width * rect.height, 1),
                    depth: depth
                ),
                best: &best
            )
        }

        collectAccessibilityElementCandidates(
            from: view,
            depth: depth,
            best: &best,
            context: context
        )

        for subview in view.subviews {
            collectCandidates(
                from: subview,
                depth: depth + 1,
                best: &best,
                context: context
            )
        }
    }

    private static func collectAccessibilityElementCandidates(
        from view: UIView,
        depth: Int,
        best: inout Candidate?,
        context: ScanContext
    ) {
        guard context.config.enableInteractionAccessibilityLabelCapture else { return }
        guard let elements = view.accessibilityElements as? [Any] else { return }
        let screenPoint = context.window.convert(context.point, to: nil)

        for element in elements {
            let label: String?
            let frame: CGRect

            if let accessibilityElement = element as? UIAccessibilityElement {
                label = accessibilityElement.accessibilityLabel
                frame = accessibilityElement.accessibilityFrame
            } else if let elementView = element as? UIView {
                label = elementView.accessibilityLabel
                frame = elementView.convert(elementView.bounds, to: nil)
            } else {
                continue
            }

            guard let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmedLabel.isEmpty else {
                continue
            }
            guard !frame.isNull, !frame.isEmpty, frame.contains(screenPoint) else { continue }
            consider(
                Candidate(
                    title: trimmedLabel,
                    viewType: "Button",
                    view: view,
                    area: max(frame.width * frame.height, 1),
                    depth: depth + 1
                ),
                best: &best
            )
        }
    }

    private static func title(from view: UIView, config: Userpilot.Config) -> String? {
        if let label = view.resolveUserpilotLabel() {
            return view.shouldRedactText()
                ? AutoCaptureConstants.reductText
                : label
        }

        if config.enableInteractionAccessibilityLabelCapture,
           let label = view.accessibilityLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !label.isEmpty {
            return view.shouldRedactAccessibilityLabel()
                ? AutoCaptureConstants.reductText
                : label
        }

        guard config.enableInteractionTextCapture else { return nil }
        if let label = view as? UILabel,
           let text = label.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return label.shouldRedactText() ? AutoCaptureConstants.reductText : text
        }
        if let textView = view as? UITextView,
           let text = textView.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return textView.shouldRedactText() ? AutoCaptureConstants.reductText : text
        }
        return nil
    }

    private static func consider(_ candidate: Candidate, best: inout Candidate?) {
        guard !candidate.title.isEmpty else { return }
        guard let existing = best else {
            best = candidate
            return
        }

        if candidate.depth > existing.depth ||
            (candidate.depth == existing.depth && candidate.area < existing.area) {
            best = candidate
        }
    }

    private static func swiftUIViewType(for view: UIView) -> String {
        if view.resolveUserpilotLabelViewType() != nil {
            return view.resolveUserpilotLabelViewType() ?? String(describing: type(of: view))
        }
        if view.accessibilityTraits.contains(.button) {
            return "Button"
        }
        return String(describing: type(of: view))
    }
}

private extension UIResponder {
    var isInsideSwiftUIHost: Bool {
        var current: UIResponder? = self
        while let responder = current {
            let className = NSStringFromClass(type(of: responder))
            if className.contains("UIHosting") || className.contains("SwiftUI") {
                return true
            }
            current = responder.next
        }
        return false
    }
}
