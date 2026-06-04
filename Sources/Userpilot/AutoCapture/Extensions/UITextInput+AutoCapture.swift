//
//  UITextInput+AutoCapture.swift
//  Userpilot
//
//  Created by Userpilot on 17/02/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UITextInput+AutoCapture provides automatic interaction tracking for UITextField
//  and UITextView text editing events using NotificationCenter observers.
//  Debounces per view: after typing pauses for `interactionDebounceInterval`, send once with latest state.
//  Ignores a new notification when `text_length` matches the last delivered event for that field.
//

import UIKit

// MARK: - UITextField Auto Capture

internal extension UITextField {

    /// Called on every `textDidChange` — debounced interaction capture for the field.
    func cacheTextFieldChanged() {
        guard Userpilot.isInitialized else { return }
        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
        let config = Userpilot.shared.config
        guard config.enableInteractionAutoCapture else { return }
        guard !shouldIgnoreInteractions() else { return }

        var payload = InteractionPayload(
            interactionType: .textFieldChanged,
            elementType: "UITextField"
        )

        payload.sourceProperties[AutoCaptureConstants.hasText] = !(text?.isEmpty ?? true)
        payload.sourceProperties[AutoCaptureConstants.textLength] = text?.count ?? 0
        payload.placeholder = placeholder

        let effectiveView = userpilotEffectiveViewForCapture()
        // SwiftUI sibling text fields otherwise resolve to identical hierarchy strings; override the
        // leaf index with a stable on-screen ordinal so they become distinct. Only when not capturing
        // through an ignore-inner-hierarchy ancestor (effectiveView === self), and only for SwiftUI —
        // UIKit sibling indices already differ, so its behavior is unchanged.
        let leafIndexOverride = (effectiveView === self && config.appFramework == .SwiftUI)
            ? UIKitViewResolver.siblingOrdinal(for: self)
            : nil
        payload.hierarchy = UIKitViewResolver.resolvePath(view: effectiveView, leafIndexOverride: leafIndexOverride)
        if effectiveView !== self {
            payload.targetClass = String(describing: type(of: effectiveView))
        } else {
            payload.accessibilityIdentifier = accessibilityIdentifier
            payload.accessibilityLabel = getAccessibilityLabelContent()
            payload.targetViewName = resolveReferenceName()
        }

        InteractionEventCache.sendDebouncedInteraction(
            payload,
            for: self,
            textLengthForDedupe: payload.sourceProperties[AutoCaptureConstants.textLength] as? Int
        )
    }
}

// MARK: - UITextView Auto Capture

internal extension UITextView {

    /// Called on every `textDidChange` — debounced interaction capture for the text view.
    func cacheTextViewChanged() {
        guard Userpilot.isInitialized else { return }
        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
        let config = Userpilot.shared.config
        guard config.enableInteractionAutoCapture else { return }
        guard !shouldIgnoreInteractions() else { return }

        var payload = InteractionPayload(
            interactionType: .textViewChanged,
            elementType: "UITextView"
        )

        payload.sourceProperties[AutoCaptureConstants.hasText] = !text.isEmpty
        payload.sourceProperties[AutoCaptureConstants.textLength] = text.count

        let effectiveView = userpilotEffectiveViewForCapture()
        // SwiftUI sibling text views otherwise resolve to identical hierarchy strings; override the
        // leaf index with a stable on-screen ordinal so they become distinct. Only when not capturing
        // through an ignore-inner-hierarchy ancestor (effectiveView === self), and only for SwiftUI —
        // UIKit sibling indices already differ, so its behavior is unchanged.
        let leafIndexOverride = (effectiveView === self && config.appFramework == .SwiftUI)
            ? UIKitViewResolver.siblingOrdinal(for: self)
            : nil
        payload.hierarchy = UIKitViewResolver.resolvePath(view: effectiveView, leafIndexOverride: leafIndexOverride)
        if effectiveView !== self {
            payload.targetClass = String(describing: type(of: effectiveView))
        } else {
            payload.accessibilityIdentifier = accessibilityIdentifier
            payload.accessibilityLabel = getAccessibilityLabelContent()
            payload.targetViewName = resolveReferenceName()
        }

        InteractionEventCache.sendDebouncedInteraction(
            payload,
            for: self,
            textLengthForDedupe: payload.sourceProperties[AutoCaptureConstants.textLength] as? Int
        )
    }
}
