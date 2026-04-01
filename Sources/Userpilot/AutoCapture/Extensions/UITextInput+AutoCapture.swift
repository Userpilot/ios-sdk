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

        payload.hasText = !(text?.isEmpty ?? true)
        payload.textLength = text?.count ?? 0
        payload.placeholder = placeholder

        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: self)
        payload.elementPath = path
        if effectiveView !== self {
            payload.elementType = String(describing: type(of: effectiveView))
        } else {
            payload.accessibilityIdentifier = accessibilityIdentifier
            payload.accessibilityLabel = getAccessibilityLabelContent()
            payload.referenceName = resolveReferenceName()
        }

        InteractionEventCache.sendDebouncedInteraction(payload, for: self)
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

        payload.hasText = !text.isEmpty
        payload.textLength = text.count

        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: self)
        payload.elementPath = path
        if effectiveView !== self {
            payload.elementType = String(describing: type(of: effectiveView))
        } else {
            payload.accessibilityIdentifier = accessibilityIdentifier
            payload.accessibilityLabel = getAccessibilityLabelContent()
            payload.referenceName = resolveReferenceName()
        }

        InteractionEventCache.sendDebouncedInteraction(payload, for: self)
    }
}
