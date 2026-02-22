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

    // MARK: - Private Methods

    /// Captures control interaction based on control type
    private func captureControlInteraction(action: Selector, target: Any?, event: UIEvent?) {
        // Check if SDK is initialized and interaction capture is enabled
        guard Userpilot.isInitialized else { return }
        let config = Userpilot.shared.config
        guard config.enableInteractionAutocapture else { return }

        // Check if this control should be ignored
        guard !shouldIgnoreInteractions() else { return }

        // Create the appropriate payload based on control type
        var payload = buildInteractionPayload(config: config)

        // Add target-action info (e.g., "onBackButtonClicked:" from IBAction)
        payload.targetAction = NSStringFromSelector(action)
        if let target = target {
            payload.targetClass = String(describing: type(of: target))
        }

        // Cache continuous controls (UISlider) — flushed on screen change
        if self is UISlider {
            InteractionEventCache.upsert(payload, for: self)
            return
        }

        // Send immediately for discrete controls
        Userpilot.shared.uiKitAutoCaptureEngine.handleInteraction(payload)
    }

    // Builds an interaction payload based on the control type
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func buildInteractionPayload(config: Userpilot.Config) -> InteractionPayload {
        var payload: InteractionPayload

        let elementType = String(describing: type(of: self))

        // Determine interaction type and extract value based on control type
        switch self {
        case let button as UIButton:
            payload = InteractionPayload(
                interactionType: .tap,
                elementType: elementType
            )
            if !config.disableInteractionTextCapture && !shouldRedactText() {
                payload.elementText = button.title(for: .normal)
                    ?? button.currentTitle
                    ?? button.titleLabel?.text
            }

        case let switchControl as UISwitch:
            payload = InteractionPayload(
                interactionType: .switchChanged,
                elementType: elementType
            )
            payload.boolValue = switchControl.isOn

        case let slider as UISlider:
            payload = InteractionPayload(
                interactionType: .sliderChanged,
                elementType: elementType
            )
            payload.floatValue = slider.value

        case let segmentedControl as UISegmentedControl:
            payload = InteractionPayload(
                interactionType: .segmentChanged,
                elementType: elementType
            )
            payload.intValue = segmentedControl.selectedSegmentIndex
            if !config.disableInteractionTextCapture && !shouldRedactText() {
                payload.stringValue = segmentedControl.titleForSegment(
                    at: segmentedControl.selectedSegmentIndex
                )
            }

        case let stepper as UIStepper:
            payload = InteractionPayload(
                interactionType: .stepperChanged,
                elementType: elementType
            )
            payload.doubleValue = stepper.value

        case let datePicker as UIDatePicker:
            payload = InteractionPayload(
                interactionType: .datePickerChanged,
                elementType: elementType
            )
            payload.dateValue = datePicker.date

        case let pageControl as UIPageControl:
            payload = InteractionPayload(
                interactionType: .pageControlChanged,
                elementType: elementType
            )
            payload.intValue = pageControl.currentPage

        default:
            payload = InteractionPayload(
                interactionType: .tap,
                elementType: elementType
            )
            if !config.disableInteractionTextCapture && !shouldRedactText() {
                payload.elementText = getTextContent()
            }
        }

        // Add common properties
        payload.accessibilityIdentifier = accessibilityIdentifier
        if !config.disableInteractionAccessibilityLabelCapture && !shouldRedactAccessibilityLabel() {
            payload.accessibilityLabel = accessibilityLabel
        }
        payload.elementPath = UIKitViewResolver.resolvePath(view: self)

        // IBOutlet reference name (e.g., "submitButton", "searchTextField")
        payload.referenceName = resolveReferenceName()

        return payload
    }
}
