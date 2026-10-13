//
//  UIControl+AutoCapture.swift
//  Userpilot SDK
//
//  Created by Userpilot on 17/02/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  UIControl+AutoCapture provides automatic interaction tracking for UIControl subclasses
//  including buttons, switches, sliders, segmented controls, steppers, date pickers, and page controls.
//

import UIKit

/// Which capture path already handled the button tap UIKit is dispatching in this main-queue turn.
private final class ButtonTapCapture {
    var selectorCaptured = false
    var actionCaptured = false
}

private var buttonTapCaptureKey: UInt8 = 0

// MARK: - UIControl Swizzled Methods

internal extension UIControl {

    /// UIButton's closure actions bypass UIApplication's selector hook. Call UIKit once,
    /// then use the same control payload and owner gates as selector-based buttons.
    @available(iOS 14.0, *)
    @objc
    func userpilot__sendUIAction(_ action: UIAction) {
        userpilot__sendUIAction(action)

        guard self is UIButton,
              let owner = UserpilotRuntime.shared.instanceResolver.resolveOwner(from: self) else { return }
        captureUIActionDispatch(owner: owner)
    }

    /// Swizzled sendAction method that captures control events
    @objc
    func userpilot__sendAction(_ action: Selector, to target: Any?, for event: UIEvent?) {
        // Call original implementation first
        userpilot__sendAction(action, to: target, for: event)

        // Capture the interaction with action and target info
        guard let owner = UserpilotRuntime.shared.instanceResolver.resolveOwner(from: self) else { return }
        captureControlInteraction(action: action, target: target, event: event, owner: owner)
    }

    // MARK: - One capture per button tap

    /// Selector entry point used by the UIApplication.sendAction hook. One button tap can reach both
    /// hooks (a selector target and a UIAction) or several targets/actions; UIKit dispatches them all
    /// synchronously in one main-queue turn, in registration order. The first selector capture claims
    /// the tap, so the button publishes once and keeps its selector metadata.
    func captureSelectorDispatch(action: Selector, target: Any?, event: UIEvent?, owner: Userpilot) {
        if self is UIButton {
            let tap = currentButtonTap
            guard !tap.selectorCaptured else { return }
            tap.selectorCaptured = true
        }
        captureControlInteraction(action: action, target: target, event: event, owner: owner)
    }

    /// A UIAction-only button cannot also receive a selector dispatch, so it publishes immediately.
    /// With selector targets, the payload is built now (the handler may release the button), but it
    /// publishes after this turn only if no selector capture claimed the same tap.
    private func captureUIActionDispatch(owner: Userpilot) {
        let tap = currentButtonTap
        guard !tap.selectorCaptured, !tap.actionCaptured,
              let payload = controlInteractionPayload(action: nil, target: nil, owner: owner) else { return }
        tap.actionCaptured = true
        guard !allTargets.isEmpty else {
            owner.autoCaptureCoordinator.handleInteractionEvent(payload)
            return
        }
        DispatchQueue.main.async { [weak owner] in
            guard let owner, !tap.selectorCaptured else { return }
            owner.autoCaptureCoordinator.handleInteractionEvent(payload)
        }
    }

    /// Main-thread state for the tap UIKit is dispatching now; cleared on the next main-queue turn.
    private var currentButtonTap: ButtonTapCapture {
        if let tap = objc_getAssociatedObject(self, &buttonTapCaptureKey) as? ButtonTapCapture { return tap }
        let tap = ButtonTapCapture()
        objc_setAssociatedObject(self, &buttonTapCaptureKey, tap, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            objc_setAssociatedObject(self, &buttonTapCaptureKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return tap
    }

    // MARK: - Internal (used by UIApplication.sendAction swizzle to avoid duplicate capture)

    /// Captures control interaction based on control type.
    /// Both action hooks use this path. UIAction has no selector/target, so those fields stay absent.
    func captureControlInteraction(action: Selector?, target: Any?, event: UIEvent?, owner owningInstance: Userpilot) {
        guard let payload = controlInteractionPayload(action: action, target: target, owner: owningInstance) else {
            return
        }

        // Continuous controls (UISlider): debounce per view — send once after quiet period
        if self is UISlider {
            InteractionEventCache.sendDebouncedInteraction(payload, for: self, owner: owningInstance)
            return
        }

        // Send immediately for discrete controls
        owningInstance.autoCaptureCoordinator.handleInteractionEvent(payload)
    }

    /// Owner, privacy and configuration gates, then this control's payload; nil when not captured.
    private func controlInteractionPayload(
        action: Selector?, target: Any?, owner owningInstance: Userpilot
    ) -> InteractionPayload? {
        guard UserpilotRuntime.shared.instanceRegistry.isRegistered(owningInstance) else { return nil }
        guard !UIApplication.viewIsWithinSystemKeyboardChrome(self) else { return nil }
        // Per-instance stop gate: this control's tenant may have paused capture
        // via `stopAutoCapture()` while other instances keep running.
        guard !owningInstance.autoCaptureCoordinator.isStopped else { return nil }
        let config = owningInstance.config
        guard config.enableInteractionAutoCapture else { return nil }

        // Skip tap for text field/text view editing actions when configured;
        // keep only text_field_changed / text_view_changed
        if config.ignoreTapForTextInputEditingActions, self is UITextField, let action,
           Self.isTextEditingAction(action) {
            return nil
        }

        // Check if this control should be ignored
        guard !shouldIgnoreInteractions() else { return nil }

        // Create the appropriate payload based on control type
        var payload = buildInteractionPayload(config: config)

        // Add target-action info (e.g., "onBackButtonClicked:" from IBAction)
        payload.targetAction = action.map(NSStringFromSelector)
        if let target = target {
            payload.ownerTargetClass = String(describing: type(of: target))
        }
        return payload
    }

    // Builds an interaction payload based on the control type
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func buildInteractionPayload(config: Userpilot.Config) -> InteractionPayload {
        var payload: InteractionPayload

        let elementType = String(describing: type(of: self))
        let framework = captureFramework(config: config)

        // Determine interaction type and extract value based on control type
        switch self {
        case _ as UIButton:
            payload = InteractionPayload(
                interactionType: .tap,
                elementType: elementType
            )
            payload.elementText = getTextContent()

        case let switchControl as UISwitch:
            payload = InteractionPayload(
                interactionType: .switchChanged,
                elementType: elementType
            )
            if config.enableInteractionValueCapture {
                payload.sourceProperties[Constants.AutoCapture.isChecked] = switchControl.isOn
            }

        case let slider as UISlider:
            payload = InteractionPayload(
                interactionType: .sliderChanged,
                elementType: elementType
            )
            if config.enableInteractionValueCapture {
                payload.sourceProperties[Constants.AutoCapture.selectedValue] = slider.value
            }

        case let segmentedControl as UISegmentedControl:
            payload = InteractionPayload(
                interactionType: .segmentChanged,
                elementType: elementType
            )
            if config.enableInteractionValueCapture {
                payload.sourceProperties[Constants.AutoCapture.selectedIndex] = segmentedControl.selectedSegmentIndex
                let raw = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex)
                let title = resolvedInteractionText(raw)
                if let title {
                    payload.sourceProperties[Constants.AutoCapture.selectedValue] = title
                }
            }

        case let stepper as UIStepper:
            payload = InteractionPayload(
                interactionType: .stepperChanged,
                elementType: elementType
            )
            // SwiftUI's `Stepper` keeps its value in SwiftUI state and uses the backing `UIStepper`
            // only as an input proxy, so its `.value` stays at the default (0) and never reflects the
            // bound value. Drop `selected_value` for SwiftUI rather than emit a misleading 0. In UIKit
            // `UIStepper.value` is authoritative, so it's still captured there.
            if config.enableInteractionValueCapture, framework != .SwiftUI {
                payload.sourceProperties[Constants.AutoCapture.selectedValue] = stepper.value
            }

        case let datePicker as UIDatePicker:
            payload = InteractionPayload(
                interactionType: .datePickerChanged,
                elementType: elementType
            )
            if config.enableInteractionValueCapture {
                payload.sourceProperties[Constants.AutoCapture.selectedDate] =
                    ISO8601DateFormatter().string(from: datePicker.date)
            }

        case let pageControl as UIPageControl:
            payload = InteractionPayload(
                interactionType: .pageControlChanged,
                elementType: elementType
            )
            if config.enableInteractionValueCapture {
                payload.sourceProperties[Constants.AutoCapture.selectedIndex] = pageControl.currentPage
            }

        default:
            payload = InteractionPayload(
                interactionType: .tap,
                elementType: elementType
            )
            payload.elementText = getTextContent()
        }

        payload.appFramework = framework

        // Add common properties (getters return "****" when redaction/config disables capture)
        payload.accessibilityIdentifier = accessibilityIdentifier
        payload.accessibilityLabel = getAccessibilityLabelContent()

        // SwiftUI sibling sliders otherwise resolve to identical hierarchy strings; override the leaf
        // index with a stable on-screen ordinal so they become distinct (same fix as text inputs).
        // Only when not capturing through an ignore-inner-hierarchy ancestor (effectiveView === self),
        // and only for SwiftUI — UIKit sibling indices already differ. `siblingOrdinal` returns nil for
        // controls other than slider/text inputs, so buttons/switches/steppers/etc. are unaffected.
        let effectiveView = userpilotEffectiveViewForCapture()
        let leafIndexOverride = (effectiveView === self && framework == .SwiftUI)
            ? UIKitViewResolver.siblingOrdinal(for: self)
            : nil
        payload.hierarchy = UIKitViewResolver.resolvePath(view: effectiveView, leafIndexOverride: leafIndexOverride)
        if effectiveView !== self {
            payload.targetClass = String(describing: type(of: effectiveView))
            payload.elementText = ignoreInnerHierarchyTextPlaceholder()
        }

        if let userpilotLabel = resolveUserpilotLabel() {
            if let labelViewType = resolveUserpilotLabelViewType() {
                payload.targetClass = labelViewType
            }
            payload.elementText = resolvedInteractionText(userpilotLabel)
        }

        // IBOutlet reference name (e.g., "submitButton", "searchTextField")
        payload.targetViewName = resolveReferenceName()

        return payload
    }

    /// Selectors that indicate text-editing (we send text_field_changed / text_view_changed separately; skip tap).
    private static func isTextEditingAction(_ action: Selector) -> Bool {
        let name = NSStringFromSelector(action)
        return name == "textChanged:" || name == "editingChanged:" || name.hasSuffix("editingChanged:")
    }
}
