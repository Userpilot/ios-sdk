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
        // Resolve the owning Userpilot instance for this picker view.
        guard let owningInstance = InstanceResolver.shared.target(forSource: self) else { return }
        guard !owningInstance.autoCaptureCoordinator.isStopped else { return }
        let config = owningInstance.config
        guard config.enableInteractionAutoCapture else { return }
        guard !shouldIgnoreInteractions() else { return }

        var payload = InteractionPayload(
            interactionType: .pickerViewChanged,
            elementType: String(describing: type(of: self))
        )

        // Row index
        payload.sourceProperties[Constants.AutoCapture.selectedIndex] = row

        // Selected title from the delegate. UIKit hosts typically implement
        // `pickerView(_:titleForRow:forComponent:)`; SwiftUI's `UIKitWheelPicker` instead
        // implements `viewForRow:forComponent:reusing:` with a custom view (usually a
        // `UILabel`), and may also use `attributedTitleForRow:forComponent:`. Try all three
        // so `selected_value` is populated for both UIKit and SwiftUI pickers.
        if config.enableInteractionValueCapture,
           let title = userpilotResolvedSelectedTitle(forRow: row, component: component) {
            payload.sourceProperties[Constants.AutoCapture.selectedValue] =
                shouldRedactText() ? Constants.AutoCapture.reductText : title
        }

        // View path and accessibility
        let (_, path) = UIKitViewResolver.resolvePathForCapture(view: self)
        payload.hierarchy = path
        payload.accessibilityIdentifier = accessibilityIdentifier
        payload.accessibilityLabel = getAccessibilityLabelContent()
        payload.targetViewName = resolveReferenceName()

        owningInstance.autoCaptureCoordinator.handleInteractionEvent(payload)
    }

    /// Resolves the title for the picked row, trying every API SwiftUI / UIKit may expose it on.
    ///
    /// Resolution order:
    /// 1. `pickerView(_:titleForRow:forComponent:)`            - standard UIKit (and SwiftUI menu picker).
    /// 2. `pickerView(_:attributedTitleForRow:forComponent:)`  - UIKit attributed strings.
    /// 3. `pickerView(_:viewForRow:forComponent:reusing:)`     - UIKit custom-view delegates.
    /// 4. `UIPickerView.view(forRow:forComponent:)`            - the picker's own currently-rendered view; SwiftUI's
    ///    `UIKitPickerView` exposes the row content here even when the coordinator does not implement the delegate.
    /// 5. Internal picker table visible cell                    - SwiftUI wheel picker fallback.
    /// 6. `accessibilityValue`                                 - SwiftUI sets this on the picker view to the selected
    ///    option for VoiceOver; final fallback when no view-level text is available.
    func userpilotResolvedSelectedTitle(forRow row: Int, component: Int) -> String? {
        if let delegate = delegate {
            if let title = delegate.pickerView?(self, titleForRow: row, forComponent: component),
               let value = Self.nonEmpty(title) {
                return value
            }

            if let attributed = delegate.pickerView?(self, attributedTitleForRow: row, forComponent: component),
               let value = Self.nonEmpty(attributed.string) {
                return value
            }

            if let view = delegate.pickerView?(self, viewForRow: row, forComponent: component, reusing: nil),
               let text = Self.userpilotExtractPickerRowText(from: view) {
                return text
            }
        }

        if let rowView = self.view(forRow: row, forComponent: component),
           let text = Self.userpilotExtractPickerRowText(from: rowView) {
            return text
        }

        if let text = resolveVisibleSelectedRowTitle(row: row, component: component) {
            return text
        }

        if let value = Self.nonEmpty(accessibilityValue) {
            return value
        }

        return nil
    }

    /// Text extractor shared by picker row APIs and tests.
    static func userpilotExtractPickerRowText(from view: UIView) -> String? {
        findText(in: view)
    }

    /// SwiftUI wheel pickers are backed by private table views. On recent iOS
    /// versions those row hosts may not be returned from `view(forRow:)`, but
    /// the visible selected cell still exposes the row's accessibility text.
    private func resolveVisibleSelectedRowTitle(row: Int, component: Int) -> String? {
        let tableViews = Self.findTableViews(in: self)
            .sorted { lhs, rhs in
                lhs.convert(lhs.bounds, to: self).minX < rhs.convert(rhs.bounds, to: self).minX
            }

        guard tableViews.indices.contains(component) else { return nil }

        let tableView = tableViews[component]
        let selectedIndexPath = IndexPath(row: row, section: 0)

        if let cell = tableView.cellForRow(at: selectedIndexPath),
           let text = Self.findText(in: cell.contentView) ?? Self.findText(in: cell) {
            return text
        }

        for cell in tableView.visibleCells where tableView.indexPath(for: cell)?.row == row {
            if let text = Self.findText(in: cell.contentView) ?? Self.findText(in: cell) {
                return text
            }
        }

        return nil
    }

    private static func findTableViews(in view: UIView) -> [UITableView] {
        var result: [UITableView] = []
        if let tableView = view as? UITableView {
            result.append(tableView)
        }
        for subview in view.subviews {
            result.append(contentsOf: findTableViews(in: subview))
        }
        return result
    }

    /// Recursive search for row text in UIKit and SwiftUI-hosted picker rows.
    private static func findText(in view: UIView) -> String? {
        if let text = directText(in: view) {
            return text
        }

        if let text = accessibilityText(in: view) {
            return text
        }

        if let accessibilityElements = view.accessibilityElements {
            for element in accessibilityElements {
                if let elementView = element as? UIView, elementView === view {
                    continue
                }
                if let text = findText(in: element) {
                    return text
                }
            }
        }

        for subview in view.subviews {
            if let text = findText(in: subview) {
                return text
            }
        }

        return nil
    }

    private static func findText(in element: Any) -> String? {
        if let view = element as? UIView {
            return findText(in: view)
        }
        if let string = element as? String {
            return nonEmpty(string)
        }
        if let attributed = element as? NSAttributedString {
            return nonEmpty(attributed.string)
        }
        if let accessibilityElement = element as? UIAccessibilityElement {
            return accessibilityText(in: accessibilityElement)
        }
        return nil
    }

    private static func directText(in view: UIView) -> String? {
        if let label = view as? UILabel {
            if let text = nonEmpty(label.text) {
                return text
            }
            if let text = nonEmpty(label.attributedText?.string) {
                return text
            }
        }
        if let button = view as? UIButton {
            if let text = nonEmpty(button.currentTitle) {
                return text
            }
            if let text = nonEmpty(button.titleLabel?.text) {
                return text
            }
        }
        return nil
    }

    private static func accessibilityText(in view: UIView) -> String? {
        if let text = nonEmpty(view.accessibilityLabel) {
            return text
        }
        if let text = nonEmpty(view.accessibilityValue) {
            return text
        }
        if let text = nonEmpty(view.accessibilityAttributedLabel?.string) {
            return text
        }
        if let text = nonEmpty(view.accessibilityAttributedValue?.string) {
            return text
        }
        return nil
    }

    private static func accessibilityText(in element: UIAccessibilityElement) -> String? {
        if let text = nonEmpty(element.accessibilityLabel) {
            return text
        }
        if let text = nonEmpty(element.accessibilityValue) {
            return text
        }
        if let text = nonEmpty(element.accessibilityAttributedLabel?.string) {
            return text
        }
        if let text = nonEmpty(element.accessibilityAttributedValue?.string) {
            return text
        }
        return nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
