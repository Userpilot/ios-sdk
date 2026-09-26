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
            interactionType: .collectionViewItemSelected,
            elementType: String(describing: type(of: self))
        )
        payload.ownerTargetClass = "UICollectionViewCell"

        // Try to get index path from parent collection view
        if let collectionView = findParentCollectionView(),
           let indexPath = collectionView.indexPath(for: self) {
            payload.section = indexPath.section
            payload.row = indexPath.item
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

    /// Resolves `target_text` for an item selection, in priority order.
    ///
    /// The interacted element is the **item**, not the leaf view under the finger, so the item's
    /// own text wins: two taps on the same item publish the same text no matter where they land,
    /// and an item that renders a large text blob (a JSON preview, a long description) can no
    /// longer push that blob into the payload ahead of its title.
    ///
    /// 1. `UIListContentConfiguration.text` (iOS 14+ list cells)
    /// 2. First visible, non-redacted text inside `contentView` (custom cells)
    /// 3. The touched view itself (items whose only text lives outside `contentView`)
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
        if let itemText = contentView.userpilotFirstTextInSubtree() {
            return resolvedInteractionText(itemText)
        }
        return touchedView?.getTextContent()
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

    /// The item's own title: the iOS 14+ content configuration's text (list cells).
    private func userpilotCellTitle() -> String? {
        guard #available(iOS 14.0, *) else { return nil }
        return UIKitViewResolver.listConfigurationText(contentConfiguration)
    }
}

// MARK: - UICollectionReusableView Auto Capture

internal extension UICollectionReusableView {

    /// Resolves `target_text` for a tap that landed inside a supplementary view (section header,
    /// footer, decoration) rather than an item.
    ///
    /// Same rule as an item: the element is the supplementary view, so its own text wins over
    /// whichever leaf the finger hit. Supplementary views have no title API of their own, so
    /// resolution starts at the first text in the subtree.
    ///
    /// - Parameter touchedView: The specific view that was touched
    /// - Returns: The resolved text content or nil
    func userpilotResolvedSupplementaryText(touchedView: UIView?) -> String? {
        if let headerText = userpilotFirstTextInSubtree() {
            return resolvedInteractionText(headerText)
        }
        return touchedView?.getTextContent()
    }
}
