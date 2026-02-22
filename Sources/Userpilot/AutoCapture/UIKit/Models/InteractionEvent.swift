//
//  InteractionEvent.swift
//  Userpilot
//
//  Created by Userpilot on 17/02/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  InteractionEvent defines the types and payload structures for automatic
//  interaction capture in UIKit applications.
//

import UIKit

// MARK: - Interaction Type

/// Defines the types of interactions that can be automatically captured.
internal enum InteractionType: String {
    /// Touch/tap on any UIControl (buttons, switches, etc.)
    case tap = "tap"

    /// UISwitch value changed
    case switchChanged = "switch_changed"

    /// UISlider value changed
    case sliderChanged = "slider_changed"

    /// UISegmentedControl selection changed
    case segmentChanged = "segment_changed"

    /// UIStepper value changed
    case stepperChanged = "stepper_changed"

    /// UIDatePicker date changed
    case datePickerChanged = "date_picker_changed"

    /// UIPageControl page changed
    case pageControlChanged = "page_control_changed"

    /// UITextField text was edited (cached per field, sent on screen change)
    case textFieldChanged = "text_field_changed"

    /// UITextView text was edited (cached per view, sent on screen change)
    case textViewChanged = "text_view_changed"

    /// UITableView cell selected
    case tableViewCellSelected = "table_view_cell_selected"

    /// UICollectionView item selected
    case collectionViewItemSelected = "collection_view_item_selected"

    /// UIPickerView selection changed
    case pickerViewChanged = "picker_view_changed"

    /// Gesture recognizer triggered (tap, long press)
    case gesture = "gesture"

    /// System view controller presented (UIAlertController, UIActivityViewController, etc.)
    case viewPresented = "view_presented"
}

// MARK: - Interaction Payload

/// Payload containing comprehensive interaction tracking information.
internal struct InteractionPayload {
    // MARK: - Required Properties

    /// The type of interaction
    let interactionType: InteractionType

    /// The source of the auto capture (e.g., "UIKit")
    let autoCaptureSource: String

    /// The element type (e.g., "button", "switch", "slider")
    let elementType: String

    /// The timestamp of the event
    let timestamp: TimeInterval

    // MARK: - Optional Element Properties

    /// The display text or label of the element
    var elementText: String?

    /// The accessibility label of the element
    var accessibilityLabel: String?

    /// The accessibility identifier of the element
    var accessibilityIdentifier: String?

    /// The hierarchical path to the element
    var elementPath: String?

    /// The target action name (e.g., "onBackButtonClicked:" from IBAction)
    var targetAction: String?

    /// The target class name that handles the action
    var targetClass: String?

    /// The IBOutlet property name (e.g., "searchTextField")
    var referenceName: String?

    /// The placeholder text (for text fields and text views)
    var placeholder: String?

    // MARK: - Value Properties (for controls with values)

    /// Boolean value for switches
    var boolValue: Bool?

    /// Float value for sliders
    var floatValue: Float?

    /// Double value for steppers
    var doubleValue: Double?

    /// Integer value for segment index, page index, etc.
    var intValue: Int?

    /// String value for selected segment title, picker selection, etc.
    var stringValue: String?

    /// Date value for date pickers
    var dateValue: Date?

    // MARK: - Index Path Properties (for table/collection views)

    /// Section index for table/collection view selections
    var section: Int?

    /// Row/item index for table/collection view selections
    var row: Int?

    // MARK: - Text Input Properties

    /// Whether the text field/view has text (privacy-safe)
    var hasText: Bool?

    /// The length of the text (privacy-safe)
    var textLength: Int?

    // MARK: - Initialization

    /// Creates an interaction payload with required properties
    init(
        interactionType: InteractionType,
        autoCaptureSource: String = FrameworkType.uiKit.rawValue,
        elementType: String,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.interactionType = interactionType
        self.autoCaptureSource = autoCaptureSource
        self.elementType = elementType
        self.timestamp = timestamp
    }

    // MARK: - Conversion

    // Converts the payload to a dictionary for event properties
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "interaction_type": interactionType.rawValue,
            "auto_capture_source": autoCaptureSource,
            "element_type": elementType,
            "timestamp": timestamp
        ]

        // Element properties
        if let elementText = elementText {
            dict["element_text"] = elementText
        }
        if let accessibilityLabel = accessibilityLabel {
            dict["accessibility_label"] = accessibilityLabel
        }
        if let accessibilityIdentifier = accessibilityIdentifier {
            dict["accessibility_identifier"] = accessibilityIdentifier
        }
        if let elementPath = elementPath {
            dict["element_path"] = elementPath
        }
        if let targetAction = targetAction {
            dict["target_action"] = targetAction
        }
        if let targetClass = targetClass {
            dict["target_class"] = targetClass
        }
        if let referenceName = referenceName {
            dict["reference_name"] = referenceName
        }
        if let placeholder = placeholder {
            dict["placeholder"] = placeholder
        }

        // Value properties
        if let boolValue = boolValue {
            dict["value"] = boolValue
        }
        if let floatValue = floatValue {
            dict["value"] = floatValue
        }
        if let doubleValue = doubleValue {
            dict["value"] = doubleValue
        }
        if let intValue = intValue {
            dict["selected_index"] = intValue
        }
        if let stringValue = stringValue {
            dict["selected_value"] = stringValue
        }
        if let dateValue = dateValue {
            dict["date_value"] = ISO8601DateFormatter().string(from: dateValue)
        }

        // Index path properties
        if let section = section {
            dict["section"] = section
        }
        if let row = row {
            dict["row"] = row
        }

        // Text input properties
        if let hasText = hasText {
            dict["has_text"] = hasText
        }
        if let textLength = textLength {
            dict["text_length"] = textLength
        }

        return dict
    }
}
