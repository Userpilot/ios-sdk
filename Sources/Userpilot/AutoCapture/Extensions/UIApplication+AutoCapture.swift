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

    private func captureSendAction(
        action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?
    ) {
        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
        guard Userpilot.isInitialized else { return }
        let config = Userpilot.shared.config
        guard config.enableInteractionAutoCapture else { return }
        guard !shouldIgnoreInternalTextSelectionAction(action: action, target: target) else { return }

        if let control = sender as? UIControl {
            control.captureControlInteraction(action: action, target: target, event: event)
            return
        }

        if let gestureRecognizer = sender as? UIGestureRecognizer {
            captureGestureAction(gestureRecognizer, action: action, target: target, config: config)
            return
        }

        if let view = sender as? UIView {
            captureViewAction(view: view, action: action, target: target, config: config)
            return
        }

        if let barButtonItem = sender as? UIBarButtonItem {
            captureBarButtonItemAction(
                barButtonItem, action: action, target: target, config: config)
            return
        }

        if let menuAction = sender as? UIAction {
            captureMenuAction(
                menuAction: menuAction, action: action, target: target, config: config)
            return
        }

        if let menu = sender as? UIMenu {
            captureMenuAction(menu: menu, action: action, target: target, config: config)
            return
        }

        // Any other sender (e.g. custom object)
        captureUnknownSenderAction(sender: sender, action: action, target: target, config: config)
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

    /// Captures UIAction (menu item) selection. Config only (no view/responder chain for menu items).
    private func captureMenuAction(
        menuAction: UIAction, action: Selector, target: Any?, config: Userpilot.Config
    ) {
        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: "UIAction"
        )
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.targetClass = String(describing: type(of: target))
        }
        if !config.enableInteractionTextCapture {
            payload.elementText = menuAction.title
        }
        payload.accessibilityIdentifier = menuAction.identifier.rawValue
        Userpilot.shared.autoCaptureEngine.handleInteractionEvent(payload)
    }

    /// Captures UIMenu selection (when sender is the menu itself). Config only (no view/responder chain).
    private func captureMenuAction(
        menu: UIMenu, action: Selector, target: Any?, config: Userpilot.Config
    ) {
        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: "UIMenu"
        )
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.targetClass = String(describing: type(of: target))
        }
        if !config.enableInteractionTextCapture {
            payload.elementText = menu.title
        }
        payload.accessibilityIdentifier = menu.identifier.rawValue
        Userpilot.shared.autoCaptureEngine.handleInteractionEvent(payload)
    }

    /// Builds a full interaction payload for a UIView
    /// (same properties as UIControl: path, accessibility, text, reference name).
    private func captureViewAction(
        view: UIView, action: Selector, target: Any?, config: Userpilot.Config
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
            payload.targetClass = String(describing: type(of: target))
        }
        payload.elementPath = path

        if useRedactedInner {
            payload.elementText = AutoCaptureConstants.reductText
        } else {
            payload.elementText = view.getTextContent()
            payload.accessibilityIdentifier = view.accessibilityIdentifier
            payload.accessibilityLabel = view.getAccessibilityLabelContent()
            payload.targetViewName = view.resolveReferenceName()
        }

        Userpilot.shared.autoCaptureEngine.handleInteractionEvent(payload)
    }

    /// Config only for text/label (UIBarButtonItem is not in the view responder chain).
    private func captureBarButtonItemAction(
        _ item: UIBarButtonItem,
        action: Selector,
        target: Any?,
        config: Userpilot.Config
    ) {
        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: String(describing: type(of: item))
        )
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.targetClass = String(describing: type(of: target))
        }
        if !config.enableInteractionTextCapture {
            payload.elementText = item.title
        }
        if !config.enableInteractionAccessibilityLabelCapture {
            payload.accessibilityLabel = item.accessibilityLabel
        }
        payload.accessibilityIdentifier = item.accessibilityIdentifier
        Userpilot.shared.autoCaptureEngine.handleInteractionEvent(payload)
    }

    /// Captures any sender that isn’t a UIControl, UIView, or UIBarButtonItem (e.g. UIMenu element, custom object).

    /// Captures a gesture recognizer action.
    /// Only fires on `.began` to avoid duplicate events for multi-state recognizers (.changed, .ended).
    private func captureGestureAction(
        _ gestureRecognizer: UIGestureRecognizer,
        action: Selector,
        target: Any?,
        config: Userpilot.Config
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
            payload.targetClass = String(describing: type(of: target))
        }
        payload.elementPath = path

        if useRedactedInner {
            payload.elementText = AutoCaptureConstants.reductText
        } else {
            payload.elementText = view.getTextContent()
            payload.accessibilityIdentifier = view.accessibilityIdentifier
            payload.accessibilityLabel = view.getAccessibilityLabelContent()
            payload.targetViewName = view.resolveReferenceName()
        }

        Userpilot.shared.autoCaptureEngine.handleInteractionEvent(payload)
    }

    /// Captures any sender that isn’t a UIControl, UIGestureRecognizer, UIView,
    /// or UIBarButtonItem (e.g. UIMenu element, custom object).
    private func captureUnknownSenderAction(
        sender: Any?, action: Selector, target: Any?, config: Userpilot.Config
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
            payload.targetClass = String(describing: type(of: target))
        }
        Userpilot.shared.autoCaptureEngine.handleInteractionEvent(payload)
    }
}
