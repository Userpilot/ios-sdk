//
//  UIControl+AutoCapture.swift
//  Userpilot
//
//  Created by Userpilot on 17/02/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIControl+AutoCapture provides automatic interaction tracking for UIControl subclasses
//  including buttons, switches, sliders, segmented controls, steppers, date pickers, and page controls.
//

import UIKit

// MARK: - UIControl Swizzled Methods

internal extension UIControl {

    /// Swizzled sendAction method that captures control events
    @objc
    func userpilot__sendAction(_ action: Selector, to target: Any?, for event: UIEvent?) {
        // Call original implementation first
        userpilot__sendAction(action, to: target, for: event)

        // Capture the interaction with action and target info
        captureControlInteraction(action: action, target: target, event: event)
    }

    // MARK: - Internal (used by UIApplication.sendAction swizzle to avoid duplicate capture)

    /// Captures control interaction based on control type.
    /// Called from UIApplication.sendAction swizzle when sender is a UIControl.
    func captureControlInteraction(action: Selector, target: Any?, event: UIEvent?) {
        guard Userpilot.isInitialized else { return }
        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
        let config = Userpilot.shared.config
        guard config.enableInteractionAutoCapture else { return }

        // Skip tap for text field/text view editing actions when configured;
        // keep only text_field_changed / text_view_changed
        if config.ignoreTapForTextInputEditingActions, self is UITextField,
           Self.isTextEditingAction(action) {
            return
        }

        // Check if this control should be ignored
        guard !shouldIgnoreInteractions() else { return }

        // Create the appropriate payload based on control type
        var payload = buildInteractionPayload(config: config)

        // Add target-action info (e.g., "onBackButtonClicked:" from IBAction)
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.ownerTargetClass = String(describing: type(of: target))
        }

        // Continuous controls (UISlider): debounce per view — send once after quiet period
        if self is UISlider {
            InteractionEventCache.sendDebouncedInteraction(payload, for: self)
            return
        }

        // Send immediately for discrete controls
        Userpilot.shared.autoCaptureEngine.handleInteractionEvent(payload)
    }

    // Builds an interaction payload based on the control type
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func buildInteractionPayload(config: Userpilot.Config) -> InteractionPayload {
        var payload: InteractionPayload

        let elementType = String(describing: type(of: self))

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
                payload.sourceProperties[AutoCaptureConstants.isChecked] = switchControl.isOn
            }

        case let slider as UISlider:
            payload = InteractionPayload(
                interactionType: .sliderChanged,
                elementType: elementType
            )
            if config.enableInteractionValueCapture {
                payload.sourceProperties[AutoCaptureConstants.selectedValue] = slider.value
            }

        case let segmentedControl as UISegmentedControl:
            payload = InteractionPayload(
                interactionType: .segmentChanged,
                elementType: elementType
            )
            if config.enableInteractionValueCapture {
                payload.sourceProperties[AutoCaptureConstants.selectedIndex] = segmentedControl.selectedSegmentIndex
                let raw = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex)
                let title: String? = shouldRedactText() ? (raw != nil ? AutoCaptureConstants.reductText : nil) : raw
                if let title {
                    payload.sourceProperties[AutoCaptureConstants.selectedValue] = title
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
            if config.enableInteractionValueCapture, config.appFramework != .SwiftUI {
                payload.sourceProperties[AutoCaptureConstants.selectedValue] = stepper.value
            }

        case let datePicker as UIDatePicker:
            payload = InteractionPayload(
                interactionType: .datePickerChanged,
                elementType: elementType
            )
            if config.enableInteractionValueCapture {
                payload.sourceProperties[AutoCaptureConstants.selectedDate] =
                    ISO8601DateFormatter().string(from: datePicker.date)
            }

        case let pageControl as UIPageControl:
            payload = InteractionPayload(
                interactionType: .pageControlChanged,
                elementType: elementType
            )
            if config.enableInteractionValueCapture {
                payload.sourceProperties[AutoCaptureConstants.selectedIndex] = pageControl.currentPage
            }

        default:
            payload = InteractionPayload(
                interactionType: .tap,
                elementType: elementType
            )
            payload.elementText = getTextContent()
        }

        // Add common properties (getters return "****" when redaction/config disables capture)
        payload.accessibilityIdentifier = accessibilityIdentifier
        payload.accessibilityLabel = getAccessibilityLabelContent()

        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: self)
        payload.hierarchy = path
        if effectiveView !== self {
            payload.targetClass = String(describing: type(of: effectiveView))
            payload.elementText = AutoCaptureConstants.reductText
        }

        if let userpilotLabel = resolveUserpilotLabel() {
            if let labelViewType = resolveUserpilotLabelViewType() {
                payload.targetClass = labelViewType
            }
            payload.elementText = shouldRedactText()
                ? AutoCaptureConstants.reductText
                : userpilotLabel
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
