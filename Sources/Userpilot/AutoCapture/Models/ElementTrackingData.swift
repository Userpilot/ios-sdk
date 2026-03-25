//
//  ElementTrackingData.swift
//  Userpilot
//
//  Created by Motasem Hamed on 10/03/2026.
//

import UIKit

/// `ElementTrackingData` contains comprehensive tracking information for UI elements.
internal struct ElementTrackingData {
    // MARK: - Properties

    /// The type of UI element (button, label, etc.)
    let elementType: String

    /// The display label or text content of the element
    let elementLabel: String?

    /// The accessibility identifier of the element
    let accessibilityId: String?

    /// The hierarchical path to the element in the view tree
    let screenHierarchyPath: String

    /// The position index of the element within its parent
    let positionIndex: Int

    // MARK: - Methods

    /// Returns a dictionary representation for event properties
    /// - Returns: Dictionary of tracking data
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "element_type": elementType,
            "screen_hierarchy_path": screenHierarchyPath,
            "position_index": positionIndex
        ]

        if let elementLabel = elementLabel {
            dict["element_label"] = elementLabel
        }
        if let accessibilityId = accessibilityId {
            dict["accessibility_id"] = accessibilityId
        }

        return dict
    }
}
