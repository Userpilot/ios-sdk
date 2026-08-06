//
//  UIApplication+AutoCapture.swift
//  Userpilot
//
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIApplication+AutoCapture swizzles sendAction(_:to:from:for:) to capture actions
//  that go through the responder chain: UIBarButtonItem, UIMenu, and UIControl (buttons,
//  switches, etc.). This single point avoids duplicate events vs. swizzling UIControl alone.
//

import UIKit

// MARK: - UIApplication SendAction Swizzling

extension UIApplication {

    /// Swizzles sendAction to intercept all target–action invocations (UIBarButtonItem, UIMenu, UIControl, etc.)
    static func swizzleSendAction() {
        guard self === UIApplication.self else { return }

        Swizzler.swapInstanceMethods(
            on: self,
            original: #selector(UIApplication.sendAction(_:to:from:for:)),
            swizzled: #selector(UIApplication.userpilot__sendAction(_:to:from:for:))
        )
    }

    /// Swizzled sendAction: captures the action then forwards to the original implementation.
    @objc
    func userpilot__sendAction(
        _ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?
    ) -> Bool {
        // Call original first so app behavior is unchanged
        let result = userpilot__sendAction(action, to: target, from: sender, for: event)

        captureSendAction(action: action, to: target, from: sender, for: event)

        return result
    }

    // MARK: - Private Capture

    // Length and branching come from one if-let per UIKit sender shape (UIControl,
    // UIGestureRecognizer, UIView, UIBarButtonItem, UIAction, UIMenu, unknown).
    // Each branch is a straight-line delegation; splitting would just move the
    // dispatch table out of line without simplifying anything.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func captureSendAction(
        action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?
    ) {
        guard Userpilot.isInitialized else { return }
        guard !shouldIgnoreInternalTextSelectionAction(action: action, target: target) else {
            return
        }

        // Resolve the owning Userpilot instance from the sender so privacy / capture
        // flags follow that tenant's config rather than the host app's. Senders without
        // a responder context (UIBarButtonItem, UIAction, UIMenu) fall back to the
        // default instance via the resolver's default fallback.
        let senderResponder: UIResponder? = (sender as? UIView)
            ?? (sender as? UIGestureRecognizer)?.view
        guard let owningInstance = InstanceResolver.shared.target(forSource: senderResponder) else {
            return
        }
        // Per-instance stop gate: resolve the owner first so a paused tenant's
        // actions are dropped while other instances keep capturing.
        guard !owningInstance.autoCaptureCoordinator.isStopped else { return }
        let config = owningInstance.config
        guard config.enableInteractionAutoCapture else { return }

        if let control = sender as? UIControl {
            guard !Self.viewIsWithinSystemKeyboardChrome(control) else { return }
            control.captureControlInteraction(action: action, target: target, event: event)
            return
        }

        if let gestureRecognizer = sender as? UIGestureRecognizer {
            if let host = gestureRecognizer.view, Self.viewIsWithinSystemKeyboardChrome(host) {
                return
            }
            captureGestureAction(
                gestureRecognizer,
                action: action,
                target: target,
                config: config,
                owningInstance: owningInstance
            )
            return
        }

        if let view = sender as? UIView {
            guard !Self.viewIsWithinSystemKeyboardChrome(view) else { return }
            captureViewAction(
                view: view,
                action: action,
                target: target,
                config: config,
                owningInstance: owningInstance
            )
            return
        }

        if let barButtonItem = sender as? UIBarButtonItem {
            captureBarButtonItemAction(
                barButtonItem,
                action: action,
                target: target,
                config: config,
                owningInstance: owningInstance
            )
            return
        }

        if let menuAction = sender as? UIAction {
            captureMenuAction(
                menuAction: menuAction,
                action: action,
                target: target,
                config: config,
                owningInstance: owningInstance
            )
            return
        }

        if let menu = sender as? UIMenu {
            captureMenuAction(
                menu: menu,
                action: action,
                target: target,
                config: config,
                owningInstance: owningInstance
            )
            return
        }

        // Any other sender (e.g. custom object)
        captureUnknownSenderAction(
            sender: sender,
            action: action,
            target: target,
            config: config,
            owningInstance: owningInstance
        )
    }

    /// Drops UIKit text-selection internals (e.g. copy/paste caret gestures on UITextView)
    /// because they can include sensitive editor text in a generic tap payload.
    private func shouldIgnoreInternalTextSelectionAction(action: Selector, target: Any?) -> Bool {
        let actionName = NSStringFromSelector(action)
        if actionName == "_handleMultiTapGesture:" {
            return true
        }
        guard let target else { return false }
        let targetClass = String(describing: type(of: target))
        if targetClass.contains("UITextSelectionInteraction") {
            return true
        }
        return false
    }

    /// System keyboard / input-accessory view hierarchy (keys, keyplanes, `UIKeyboardImpl`, …).
    private static func typeNameIndicatesSystemKeyboardChrome(_ name: String) -> Bool {
        if name.hasPrefix("UIKB") { return true }
        if name.hasPrefix("TUIKB") { return true }
        if name.contains("TUIKeyplane") || name.contains("TUIKeyboard") { return true }
        if name.contains("UIKeyboardImpl") || name.contains("UIKeyboardLayout") { return true }
        if name.contains("UIKeyboardAutomatic") { return true }
        if name.contains("UIInputSet") || name.contains("_UIKB") { return true }
        if name.contains("UICompatibilityInputView") { return true }
        return false
    }

    private static func viewIsWithinSystemKeyboardChrome(_ view: UIView) -> Bool {
        var current: UIView? = view
        while let currentView = current {
            if typeNameIndicatesSystemKeyboardChrome(String(describing: type(of: currentView))) {
                return true
            }
            current = currentView.superview
        }
        return false
    }

    /// Captures UIAction (menu item) selection. Config only (no view/responder chain for menu items).
    private func captureMenuAction(
        menuAction: UIAction,
        action: Selector,
        target: Any?,
        config: Userpilot.Config,
        owningInstance: Userpilot
    ) {
        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: "UIAction"
        )
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.ownerTargetClass = String(describing: type(of: target))
        }
        if config.enableInteractionTextCapture {
            payload.elementText = menuAction.title
        }
        payload.accessibilityIdentifier = menuAction.identifier.rawValue
        owningInstance.autoCaptureCoordinator.handleInteractionEvent(payload)
    }

    /// Captures UIMenu selection (when sender is the menu itself). Config only (no view/responder chain).
    private func captureMenuAction(
        menu: UIMenu,
        action: Selector,
        target: Any?,
        config: Userpilot.Config,
        owningInstance: Userpilot
    ) {
        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: "UIMenu"
        )
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.ownerTargetClass = String(describing: type(of: target))
        }
        if config.enableInteractionTextCapture {
            payload.elementText = menu.title
        }
        payload.accessibilityIdentifier = menu.identifier.rawValue
        owningInstance.autoCaptureCoordinator.handleInteractionEvent(payload)
    }

    /// Builds a full interaction payload for a UIView
    /// (same properties as UIControl: path, accessibility, text, reference name).
    private func captureViewAction(
        view: UIView,
        action: Selector,
        target: Any?,
        config: Userpilot.Config,
        owningInstance: Userpilot
    ) {
        guard !view.shouldIgnoreInteractions() else { return }

        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: view)
        let useRedactedInner = (effectiveView !== view)

        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: String(describing: type(of: effectiveView))
        )
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.ownerTargetClass = String(describing: type(of: target))
        }
        payload.hierarchy = path

        if useRedactedInner {
            payload.elementText = view.ignoreInnerHierarchyTextPlaceholder()
        } else {
            payload.elementText = view.getTextContent()
            payload.accessibilityIdentifier = view.accessibilityIdentifier
            payload.accessibilityLabel = view.getAccessibilityLabelContent()
            payload.targetViewName = view.resolveReferenceName()
        }

        owningInstance.autoCaptureCoordinator.handleInteractionEvent(payload)
    }

    /// Config only for text/label (UIBarButtonItem is not in the view responder chain).
    private func captureBarButtonItemAction(
        _ item: UIBarButtonItem,
        action: Selector,
        target: Any?,
        config: Userpilot.Config,
        owningInstance: Userpilot
    ) {
        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: String(describing: type(of: item))
        )
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.ownerTargetClass = String(describing: type(of: target))
        }
        if config.enableInteractionTextCapture {
            payload.elementText = item.title
        }
        if config.enableInteractionAccessibilityLabelCapture {
            payload.accessibilityLabel = item.accessibilityLabel
        }
        payload.accessibilityIdentifier = item.accessibilityIdentifier
        owningInstance.autoCaptureCoordinator.handleInteractionEvent(payload)
    }

    /// Captures any sender that isn’t a UIControl, UIView, or UIBarButtonItem (e.g. UIMenu element, custom object).

    /// Captures a gesture recognizer action.
    /// Only fires on `.began` to avoid duplicate events for multi-state recognizers (.changed, .ended).
    private func captureGestureAction(
        _ gestureRecognizer: UIGestureRecognizer,
        action: Selector,
        target: Any?,
        config: Userpilot.Config,
        owningInstance: Userpilot
    ) {
        guard gestureRecognizer.state == .began else { return }
        guard let view = gestureRecognizer.view else { return }
        guard !view.shouldIgnoreInteractions() else { return }

        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: view)
        let useRedactedInner = (effectiveView !== view)

        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: String(describing: type(of: effectiveView))
        )
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.ownerTargetClass = String(describing: type(of: target))
        }
        payload.hierarchy = path

        if useRedactedInner {
            payload.elementText = view.ignoreInnerHierarchyTextPlaceholder()
        } else {
            payload.elementText = view.getTextContent()
            payload.accessibilityIdentifier = view.accessibilityIdentifier
            payload.accessibilityLabel = view.getAccessibilityLabelContent()
            payload.targetViewName = view.resolveReferenceName()
        }

        owningInstance.autoCaptureCoordinator.handleInteractionEvent(payload)
    }

    /// Captures any sender that isn’t a UIControl, UIGestureRecognizer, UIView,
    /// or UIBarButtonItem (e.g. UIMenu element, custom object).
    private func captureUnknownSenderAction(
        sender: Any?,
        action: Selector,
        target: Any?,
        config: Userpilot.Config,
        owningInstance: Userpilot
    ) {
        let elementType: String
        if let sender = sender {
            elementType = String(describing: type(of: sender))
        } else {
            elementType = "Unknown"
        }

        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: elementType
        )
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.ownerTargetClass = String(describing: type(of: target))
        }
        owningInstance.autoCaptureCoordinator.handleInteractionEvent(payload)
    }
}
