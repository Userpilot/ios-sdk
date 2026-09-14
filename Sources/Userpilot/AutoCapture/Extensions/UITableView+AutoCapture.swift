//
//  UITableView+AutoCapture.swift
//  Userpilot
//
//  Created by Userpilot on 17/02/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UITableView+AutoCapture provides utilities for capturing UITableView cell interactions.
//  Cell taps are captured via UIWindow.sendEvent when a UITableViewCell is touched.
//

import UIKit

// MARK: - UITableViewCell Auto Capture

internal extension UITableViewCell {

    /// Captures a table view cell selection interaction
    /// - Parameter touchedView: The specific view that was touched within the cell
    func captureTableViewCellSelection(touchedView: UIView?) {
        guard Userpilot.isInitialized else { return }
        // Resolve the owning Userpilot instance from this cell. Touched view is preferred
        // because it lives deeper in the responder chain (more accurate scope match).
        guard let owningInstance = InstanceResolver.shared.target(forSource: touchedView ?? self) else {
            return
        }
        guard !owningInstance.autoCaptureCoordinator.isStopped else { return }
        let config = owningInstance.config
        guard config.enableInteractionAutoCapture else { return }
        guard !shouldIgnoreInteractions() else { return }

        var payload = InteractionPayload(
            interactionType: .tableViewCellSelected,
            elementType: String(describing: type(of: self))
        )
        payload.ownerTargetClass = "UITableViewCell"

        // Try to get index path from parent table view
        if let tableView = findParentTableView(),
           let indexPath = tableView.indexPath(for: self) {
            payload.section = indexPath.section
            payload.row = indexPath.row
        }

        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: self)
        payload.hierarchy = path
        if let userpilotLabel = (touchedView ?? self).resolveUserpilotLabel() {
            if let labelViewType = (touchedView ?? self).resolveUserpilotLabelViewType() {
                payload.targetClass = labelViewType
            }
            payload.elementText = (touchedView ?? self).resolvedInteractionText(userpilotLabel)
        } else if effectiveView !== self {
            payload.targetClass = String(describing: type(of: effectiveView))
            payload.elementText = effectiveView.ignoreInnerHierarchyTextPlaceholder()
        } else {
            payload.elementText = userpilotResolvedCellText(touchedView: touchedView)
            payload.accessibilityIdentifier = accessibilityIdentifier
            payload.accessibilityLabel = touchedView?.getAccessibilityLabelContent()
        }

        // Send to the owning instance's engine
        owningInstance.autoCaptureCoordinator.handleInteractionEvent(payload)
    }

    /// Resolves `target_text` for a row selection, in priority order.
    ///
    /// The interacted element is the **row**, not the leaf view under the finger, so the row's own
    /// title wins: two taps on the same row publish the same text no matter where they land, and a
    /// cell that renders a large text blob (a JSON preview, a long description) can no longer push
    /// that blob into the payload ahead of its title.
    ///
    /// 1. `textLabel` (standard cells) / `UIListContentConfiguration.text` (iOS 14+ cells)
    /// 2. First visible, non-redacted text inside `contentView` (custom cells)
    /// 3. The touched view itself (rows whose only text lives outside `contentView`)
    ///
    /// Text-capture policy (config flag, `userpilotRedactText`) and bounding are applied by
    /// ``UIView/resolvedInteractionText(_:)`` / ``UIView/getTextContent()``.
    ///
    /// - Parameter touchedView: The specific view that was touched
    /// - Returns: The resolved text content or nil
    func userpilotResolvedCellText(touchedView: UIView?) -> String? {
        if let title = userpilotCellTitle() {
            return resolvedInteractionText(title)
        }
        if let rowText = contentView.userpilotFirstTextInSubtree() {
            return resolvedInteractionText(rowText)
        }
        return touchedView?.getTextContent()
    }

    // MARK: - Private Helpers

    /// Finds the parent UITableView
    private func findParentTableView() -> UITableView? {
        var currentView: UIView? = superview
        while let view = currentView {
            if let tableView = view as? UITableView {
                return tableView
            }
            currentView = view.superview
        }
        return nil
    }

    /// The cell's own title: the legacy `textLabel`, or the iOS 14+ content configuration's text.
    private func userpilotCellTitle() -> String? {
        if let text = textLabel?.text, !text.isEmpty {
            return text
        }
        if #available(iOS 14.0, *) {
            return UIKitViewResolver.listConfigurationText(contentConfiguration)
        }
        return nil
    }
}

// MARK: - UITableViewHeaderFooterView Auto Capture

internal extension UITableViewHeaderFooterView {

    /// Resolves `target_text` for a tap that landed inside a section header or footer.
    ///
    /// Same rule as a row: the element is the header, so its own title wins over whichever leaf
    /// view the finger hit. See ``UITableViewCell/userpilotResolvedCellText(touchedView:)``.
    ///
    /// - Parameter touchedView: The specific view that was touched
    /// - Returns: The resolved text content or nil
    func userpilotResolvedHeaderFooterText(touchedView: UIView?) -> String? {
        if let title = userpilotHeaderFooterTitle() {
            return resolvedInteractionText(title)
        }
        if let headerText = contentView.userpilotFirstTextInSubtree() {
            return resolvedInteractionText(headerText)
        }
        return touchedView?.getTextContent()
    }

    // MARK: - Private Helpers

    /// The header/footer's own title: the legacy `textLabel`, or the iOS 14+ content
    /// configuration's text.
    private func userpilotHeaderFooterTitle() -> String? {
        if let text = textLabel?.text, !text.isEmpty {
            return text
        }
        if #available(iOS 14.0, *) {
            return UIKitViewResolver.listConfigurationText(contentConfiguration)
        }
        return nil
    }
}
