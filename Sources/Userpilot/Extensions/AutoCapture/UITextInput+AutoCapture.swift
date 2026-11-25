//
//  UITextInput+AutoCapture.swift
//  Userpilot SDK
//
//  Created by Userpilot on 17/02/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
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
        // Resolve the owning Userpilot instance from the field's responder chain so
        // typed-text events follow that tenant's privacy and capture flags.
        guard let owningInstance = UserpilotRuntime.shared.instanceResolver.resolveOwner(from: self) else { return }
        guard !owningInstance.autoCaptureCoordinator.isStopped else { return }
        let config = owningInstance.config
        guard config.enableInteractionAutoCapture else { return }
        guard !shouldIgnoreInteractions() else { return }

        var payload = InteractionPayload(
            interactionType: .textFieldChanged,
            elementType: "UITextField"
        )

        payload.sourceProperties[Constants.AutoCapture.hasText] = !(text?.isEmpty ?? true)
        payload.sourceProperties[Constants.AutoCapture.textLength] = text?.count ?? 0
        payload.placeholder = placeholder
        payload.appFramework = captureFramework(config: config)

        InteractionEventCache.sendDebouncedInteraction(
            for: self,
            owner: owningInstance,
            textLengthForDedupe: payload.sourceProperties[Constants.AutoCapture.textLength] as? Int
        ) { [payload] field in
            field.completedTextInteractionPayload(payload)
        }
    }
}

// MARK: - UITextView Auto Capture

internal extension UITextView {

    /// Called on every `textDidChange` — debounced interaction capture for the text view.
    func cacheTextViewChanged() {
        // Resolve the owning Userpilot instance from the text view's responder chain.
        guard let owningInstance = UserpilotRuntime.shared.instanceResolver.resolveOwner(from: self) else { return }
        guard !owningInstance.autoCaptureCoordinator.isStopped else { return }
        let config = owningInstance.config
        guard config.enableInteractionAutoCapture else { return }
        guard !shouldIgnoreInteractions() else { return }

        var payload = InteractionPayload(
            interactionType: .textViewChanged,
            elementType: "UITextView"
        )

        payload.sourceProperties[Constants.AutoCapture.hasText] = !text.isEmpty
        payload.sourceProperties[Constants.AutoCapture.textLength] = text.count
        payload.appFramework = captureFramework(config: config)

        InteractionEventCache.sendDebouncedInteraction(
            for: self,
            owner: owningInstance,
            textLengthForDedupe: payload.sourceProperties[Constants.AutoCapture.textLength] as? Int
        ) { [payload] textView in
            textView.completedTextInteractionPayload(payload)
        }
    }
}

// MARK: - Shared text metadata

private extension UIView {
    /// Finalizes identity after each editor has read its own text/placeholder semantics and framework.
    func completedTextInteractionPayload(_ textPayload: InteractionPayload) -> InteractionPayload {
        var payload = textPayload
        let effectiveView = userpilotEffectiveViewForCapture()
        // SwiftUI siblings need their stable on-screen ordinal. An ignored inner hierarchy uses
        // its effective ancestor; UIKit retains its existing sibling indices.
        let leafIndexOverride = (effectiveView === self && payload.appFramework == .SwiftUI)
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
        return payload
    }
}
