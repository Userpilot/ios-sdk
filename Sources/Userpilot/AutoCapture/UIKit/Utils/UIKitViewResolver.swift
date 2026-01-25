//
//  UIKitViewResolver.swift
//  Userpilot
//
//  Created by Motasem Hamed on 06/01/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  UIKitViewResolver provides utilities for resolving element properties and generating
//  unique identifiers for UIKit view elements in automatic analytics capture.
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

    /// Generates a stable event ID based on the collected data
    /// - Returns: Unique event identifier string
    func generateEventUID() -> String {
        let components = [
            elementType,
            elementLabel ?? "",
            accessibilityId ?? "",
            screenHierarchyPath,
            String(positionIndex)
        ].joined(separator: "|")

        return String(components.hashValue)
    }

    /// Returns a dictionary representation for event properties
    /// - Returns: Dictionary of tracking data
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "screen_hierarchy_path": screenHierarchyPath,
            "position_index": positionIndex,
            "event_uid": generateEventUID()
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

/// `UIKitViewResolver` provides utilities for UIKit view element identification and tracking.
internal enum UIKitViewResolver {
    // MARK: - Static Methods

    /// Resolves text content from UIKit views for backward compatibility
    /// - Parameter view: The UIView to extract text from
    /// - Returns: Text content or nil
    static func resolve(view: UIView) -> String? {
        if let label = view as? UILabel {
            return label.text
        }

        if let button = view as? UIButton {
            return button.title(for: .normal)
                ?? button.currentTitle
                ?? button.titleLabel?.text
        }

        if let textField = view as? UITextField {
            return textField.text
        }

        if let textView = view as? UITextView {
            return textView.text
        }

        if let accessibilityLabel = view.accessibilityLabel, !accessibilityLabel.isEmpty {
            return accessibilityLabel
        }

        return nil
    }

    /// Extracts comprehensive element tracking data from UIKit views
    /// - Parameter view: The UIView to extract data from
    /// - Returns: ElementTrackingData with all tracking information
    static func resolveElementData(view: UIView) -> ElementTrackingData {
        return ElementTrackingData(
            elementType: resolveElementType(view: view),
            elementLabel: resolveElementLabel(view: view),
            accessibilityId: resolveAccessibilityId(view: view),
            screenHierarchyPath: resolveHierarchyPath(view: view),
            positionIndex: resolvePositionIndex(view: view)
        )
    }

    /// Generates a unique identifier for click events
    /// - Parameters:
    ///   - screenName: The current screen name
    ///   - properties: Event properties
    /// - Returns: Unique event identifier string
    static func generateEventUID(screenName: String, properties: [String: Any]) -> String {
        let elementType = properties["element_type"] as? String ?? "view"
        let elementLabel = properties["element_label"] as? String ?? ""
        let accessibilityId = properties["accessibility_id"] as? String ?? ""
        let hierarchyPath = properties["screen_hierarchy_path"] as? String ?? ""
        let positionIndex = properties["position_index"] as? Int ?? 0
        let components = [
            screenName,
            elementType,
            elementLabel,
            accessibilityId,
            hierarchyPath,
            String(positionIndex)
        ].joined(separator: "|")

        return String(components.hashValue)
    }

    /// Resolves the hierarchical path of a view in the view tree
    /// - Parameter view: The UIView to resolve path for
    /// - Returns: Hierarchical path string
    static func resolvePath(view: UIView) -> String {
        var path = [String]()
        var currentView: UIView? = view
        while let view = currentView {
            if let parent = view.superview {
                let index = parent.subviews.firstIndex(of: view) ?? 0
                path.append("\(type(of: view))[\(index)]")
                currentView = parent
            } else {
                path.append("Root")
                break
            }
        }
        return path.reversed().joined(separator: "/")
    }

    /// Gets a unique tag or identifier for the element
    /// - Parameter view: The UIView to get tag for
    /// - Returns: Element tag string
    static func elementTag(view: UIView) -> String {
        if let tag = view.accessibilityIdentifier {
            return tag
        } else if view.tag != 0 {
            return "\(view.tag)"
        } else {
            return resolvePath(view: view)
        }
    }

    // MARK: - Element Type Resolution

    // Resolves the element type based on UIView class type
    // - Parameter view: The UIView to resolve type for
    // - Returns: Element type string
    // swiftlint:disable:next cyclomatic_complexity
    private static func resolveElementType(view: UIView) -> String {
        if view is UIButton {
            return "button"
        } else if view is UILabel {
            return "label"
        } else if view is UITextField {
            return "textfield"
        } else if view is UITextView {
            return "textview"
        } else if view is UISwitch {
            return "switch"
        } else if view is UISlider {
            return "slider"
        } else if view is UISegmentedControl {
            return "segmented_control"
        } else if view is UIImageView {
            return "image"
        } else if view is UIScrollView {
            return "scrollview"
        } else if view is UITableView {
            return "tableview"
        } else if view is UICollectionView {
            return "collectionview"
        } else if view is UIStackView {
            return "stackview"
        }

        return "view"
    }

    // MARK: - Element Label Resolution

    /// Resolves the element label or text content
    /// - Parameter view: The UIView to resolve label for
    /// - Returns: Element label string or nil
    private static func resolveElementLabel(view: UIView) -> String? {
        if let label = view as? UILabel {
            return label.text
        }

        if let button = view as? UIButton {
            return button.title(for: .normal)
                ?? button.currentTitle
                ?? button.titleLabel?.text
        }

        if let textField = view as? UITextField {
            return textField.placeholder ?? textField.text
        }

        if let textView = view as? UITextView {
            return textView.text
        }

        if let accessibilityLabel = view.accessibilityLabel, !accessibilityLabel.isEmpty {
            return accessibilityLabel
        }

        return nil
    }

    // MARK: - Accessibility ID Resolution

    /// Resolves the accessibility identifier of the view
    /// - Parameter view: The UIView to resolve accessibility ID for
    /// - Returns: Accessibility identifier string or nil
    private static func resolveAccessibilityId(view: UIView) -> String? {
        return view.accessibilityIdentifier
    }

    // MARK: - Hierarchy Path Resolution

    /// Resolves the hierarchical path of the view in the view tree
    /// - Parameter view: The UIView to resolve hierarchy path for
    /// - Returns: Hierarchical path string
    private static func resolveHierarchyPath(view: UIView) -> String {
        var path: [String] = []
        var currentView: UIView? = view

        while let view = currentView {
            if let superview = view.superview {
                let index = superview.subviews.firstIndex(of: view) ?? 0
                let typeName =
                    String(describing: type(of: view))
                    .components(separatedBy: ".").last ?? String(describing: type(of: view))
                path.append("\(typeName)[\(index)]")
                currentView = superview
            } else {
                path.append("Root")
                break
            }
        }

        return path.reversed().joined(separator: "/")
    }

    // MARK: - Position Index Resolution

    /// Resolves the position index of the view within its parent
    /// - Parameter view: The UIView to resolve position for
    /// - Returns: Position index integer
    private static func resolvePositionIndex(view: UIView) -> Int {
        guard let superview = view.superview else { return 0 }
        return superview.subviews.firstIndex(of: view) ?? 0
    }
}
