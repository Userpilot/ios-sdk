//
//  UICollectionView+AutoCapture.swift
//  Userpilot
//
//  Created by Userpilot on 17/02/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UICollectionView+AutoCapture provides utilities for capturing UICollectionView item interactions.
//  Item taps are captured via UIWindow.sendEvent when a UICollectionViewCell is touched.
//

import UIKit

// MARK: - UICollectionViewCell Auto Capture

internal extension UICollectionViewCell {

    /// Captures a collection view item selection interaction
    /// - Parameter touchedView: The specific view that was touched within the cell
    func captureCollectionViewItemSelection(touchedView: UIView?) {
        guard Userpilot.isInitialized else { return }
        guard !AutocaptureViewConfiguration.isAutoCaptureStopped else { return }
        let config = Userpilot.shared.config
        guard config.enableInteractionAutocapture else { return }
        guard !shouldIgnoreInteractions() else { return }

        var payload = InteractionPayload(
            interactionType: .collectionViewItemSelected,
            elementType: String(describing: type(of: self))
        )

        // Try to get index path from parent collection view
        if let collectionView = findParentCollectionView(),
           let indexPath = collectionView.indexPath(for: self) {
            payload.section = indexPath.section
            payload.row = indexPath.item
        }

        let (effectiveView, path) = UIKitViewResolver.resolvePathForCapture(view: self)
        payload.elementPath = path
        if effectiveView !== self {
            payload.elementType = String(describing: type(of: effectiveView))
            payload.elementText = "****"
        } else {
            payload.elementText = touchedView?.getTextContent()
            payload.accessibilityIdentifier = accessibilityIdentifier
            payload.accessibilityLabel = touchedView?.getAccessibilityLabelContent()
        }

        // Send to the engine
        Userpilot.shared.uiKitAutoCaptureEngine.handleInteraction(payload)
    }

    // MARK: - Private Helpers

    /// Finds the parent UICollectionView
    private func findParentCollectionView() -> UICollectionView? {
        var currentView: UIView? = superview
        while let view = currentView {
            if let collectionView = view as? UICollectionView {
                return collectionView
            }
            currentView = view.superview
        }
        return nil
    }

    /// Resolves text content from the cell with priority order
    /// - Parameter touchedView: The specific view that was touched
    /// - Returns: The resolved text content or nil
    private func resolveTextContent(touchedView: UIView?) -> String? {
        // 1. Try the specific touched view if it has text
        if let touchedView = touchedView {
            if let text = extractText(from: touchedView), !text.isEmpty {
                return text
            }
        }

        // 2. Search contentView for any text
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
