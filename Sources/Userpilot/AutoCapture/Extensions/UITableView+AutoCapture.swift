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
            payload.elementText = (touchedView ?? self).shouldRedactText()
                ? AutoCaptureConstants.reductText
                : userpilotLabel
        } else if effectiveView !== self {
            payload.targetClass = String(describing: type(of: effectiveView))
            payload.elementText = AutoCaptureConstants.reductText
        } else {
            payload.elementText = touchedView?.getTextContent()
            payload.accessibilityIdentifier = accessibilityIdentifier
            payload.accessibilityLabel = touchedView?.getAccessibilityLabelContent()
        }

        // Send to the owning instance's engine
        owningInstance.autoCaptureCoordinator.handleInteractionEvent(payload)
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

    /// Resolves text content from the cell with priority order
    /// - Parameter touchedView: The specific view that was touched
    /// - Returns: The resolved text content or nil
    private func resolveTextContent(touchedView: UIView?) -> String? {
        // 1. Try cell's textLabel first (standard cells)
        if let text = textLabel?.text, !text.isEmpty {
            return text
        }

        // 2. Try the specific touched view if it has text
        if let touchedView = touchedView {
            if let text = extractText(from: touchedView), !text.isEmpty {
                return text
            }
        }

        // 3. Search contentView for any text
        return findTextInView(contentView)
    }

    /// Extracts text from a specific view
    private func extractText(from view: UIView) -> String? {
        if let label = view as? UILabel {
            return label.text
        }
        if let button = view as? UIButton {
            return button.currentTitle ?? button.titleLabel?.text
        }
        if let textField = view as? UITextField {
            return textField.placeholder // Don't capture actual text for privacy
        }
        return nil
    }

    /// Recursively searches for text content in a view hierarchy
    private func findTextInView(_ view: UIView) -> String? {
        // Check current view
        if let text = extractText(from: view), !text.isEmpty {
            return text
        }

        // Search subviews
        for subview in view.subviews {
            if let text = findTextInView(subview) {
                return text
            }
        }

        return nil
    }
}
