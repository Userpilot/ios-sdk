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
        guard Userpilot.isInitialized else { return }
        // Resolve the owning Userpilot instance from the field's responder chain so
        // typed-text events follow that tenant's privacy and capture flags.
        guard let owningInstance = InstanceResolver.shared.target(forSource: self) else { return }
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

        completeTextInteractionPayload(&payload, config: config)

        InteractionEventCache.sendDebouncedInteraction(
            payload,
            for: self,
            textLengthForDedupe: payload.sourceProperties[Constants.AutoCapture.textLength] as? Int
        )
    }
}

// MARK: - UITextView Auto Capture

internal extension UITextView {

    /// Called on every `textDidChange` — debounced interaction capture for the text view.
    func cacheTextViewChanged() {
        guard Userpilot.isInitialized else { return }
        // Resolve the owning Userpilot instance from the text view's responder chain.
        guard let owningInstance = InstanceResolver.shared.target(forSource: self) else { return }
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

        completeTextInteractionPayload(&payload, config: config)

        InteractionEventCache.sendDebouncedInteraction(
            payload,
            for: self,
            textLengthForDedupe: payload.sourceProperties[Constants.AutoCapture.textLength] as? Int
        )
    }
}

// MARK: - Shared text metadata

private extension UIView {
    /// Finalizes identity after each editor has read its own text/placeholder semantics.
    func completeTextInteractionPayload(_ payload: inout InteractionPayload, config: Userpilot.Config) {
        let effectiveView = userpilotEffectiveViewForCapture()
        // SwiftUI siblings need their stable on-screen ordinal. An ignored inner hierarchy uses
        // its effective ancestor; UIKit retains its existing sibling indices.
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
    }
}
