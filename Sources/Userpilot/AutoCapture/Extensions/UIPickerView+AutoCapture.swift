//
//  UIPickerView+AutoCapture.swift
//  Userpilot
//
//  Created by Userpilot on 16/03/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIPickerView+AutoCapture captures UIPickerView row selections by swizzling the
//  `setDelegate:` setter. Each time a delegate is assigned, its
//  `pickerView(_:didSelectRow:inComponent:)` method is swizzled so the SDK can
//  intercept the selection without requiring any changes to the host app.
//

import UIKit

// MARK: - UIPickerView Delegate Swizzling

internal extension UIPickerView {

    /// Swizzles UIPickerView.setDelegate(_:) so every newly assigned delegate gets
    /// its `pickerView(_:didSelectRow:inComponent:)` method hooked as well.
    static func swizzleSetDelegate() {
        Swizzler.swapInstanceMethods(
            on: self,
            original: #selector(setter: UIPickerView.delegate),
            swizzled: #selector(UIPickerView.userpilot__setDelegate(_:))
        )
    }

    /// Swizzled delegate setter. Injects capture logic into the delegate then
    /// forwards the original assignment.
    @objc
    func userpilot__setDelegate(_ delegate: UIPickerViewDelegate?) {
        // Forward to the original setter first (swizzled names are exchanged)
        userpilot__setDelegate(delegate)

        guard let delegate else { return }

        // Hook the delegate's didSelectRow method so we capture selections
        Swizzler.swizzle(
            targetInstance: delegate,
            targetSelector: #selector(UIPickerViewDelegate.pickerView(_:didSelectRow:inComponent:)),
            replacementOwner: UIPickerView.self,
            // swiftlint:disable:next line_length
            placeholderSelector: #selector(UIPickerView.userpilot__pickerViewDidSelectRow_placeholder(_:didSelectRow:inComponent:)),
            swizzleSelector: #selector(UIPickerView.userpilot__pickerViewDidSelectRow(_:didSelectRow:inComponent:))
        )
    }
}

// MARK: - Delegate Placeholder & Swizzle Implementations

internal extension UIPickerView {

    /// Empty placeholder inserted when the delegate does not implement
    /// `pickerView(_:didSelectRow:inComponent:)`.
    @objc
    func userpilot__pickerViewDidSelectRow_placeholder(
        _ pickerView: UIPickerView,
        didSelectRow row: Int,
        inComponent component: Int
    ) {
        // Intentionally empty — exists only so Swizzler can exchange it.
    }

    /// Swizzle implementation: calls through to the (possibly original or placeholder)
    /// implementation then captures the selection.
    @objc
    func userpilot__pickerViewDidSelectRow(
        _ pickerView: UIPickerView,
        didSelectRow row: Int,
        inComponent component: Int
    ) {
        // Call the original (swizzled names are exchanged)
        userpilot__pickerViewDidSelectRow(pickerView, didSelectRow: row, inComponent: component)

        pickerView.capturePickerViewSelection(row: row, component: component)
    }
}

// MARK: - Capture Logic

internal extension UIPickerView {

    /// Builds and dispatches an interaction payload for a picker row selection.
    func capturePickerViewSelection(row: Int, component: Int) {
        guard Userpilot.isInitialized else { return }
        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
        let config = Userpilot.shared.config
        guard config.enableInteractionAutoCapture else { return }
        guard !shouldIgnoreInteractions() else { return }

        var payload = InteractionPayload(
            interactionType: .pickerViewChanged,
            elementType: String(describing: type(of: self))
        )

        // Row and component indexes
        payload.row = row
        payload.sourceProperties[AutoCaptureConstants.selectedIndex] = component

        // Selected title from the data source (requires UIPickerViewDelegate to implement titleForRow)
        if config.enableInteractionValueCapture,
           let title = delegate?.pickerView?(self, titleForRow: row, forComponent: component) {
            payload.sourceProperties[AutoCaptureConstants.selectedValue] =
                shouldRedactText() ? AutoCaptureConstants.reductText : title
        }

        // View path and accessibility
        let (_, path) = UIKitViewResolver.resolvePathForCapture(view: self)
        payload.elementPath = path
        payload.accessibilityIdentifier = accessibilityIdentifier
        payload.accessibilityLabel = getAccessibilityLabelContent()
        payload.targetViewName = resolveReferenceName()

        Userpilot.shared.autoCaptureEngine.handleInteractionEvent(payload)
    }
}
