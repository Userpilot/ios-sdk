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

// MARK: - Interaction Payload

/// Payload containing comprehensive interaction tracking information.
internal struct InteractionPayload {
    // MARK: - Required Properties

    /// The type of interaction
    let interactionType: InteractionType

    /// The element type (e.g., "button", "switch", "slider")
    var elementType: String

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

    /// The dialog title
    var dialogTitle: String?

    /// The dialog message
    var dialogMessage: String?

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

    // MARK: - Gesture Properties

    /// Whether the interaction was triggered by a long press (vs. a tap)
    var isLongPress: Bool?

    // MARK: - Initialization

    /// Creates an interaction payload with required properties
    init(
        interactionType: InteractionType,
        elementType: String
    ) {
        self.interactionType = interactionType
        self.elementType = elementType
    }

    // MARK: - Conversion

    // Converts the payload to a dictionary for event properties
    // swiftlint:disable:next function_body_length cyclomatic_complexity superfluous_disable_command
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            AutoCaptureConstants.elementType: elementType
        ]

        // Element properties
        if let elementText = elementText {
            dict[AutoCaptureConstants.elementText] = elementText
        }
        if let accessibilityLabel = accessibilityLabel {
            dict[AutoCaptureConstants.accessibilityLabel] = accessibilityLabel
        }
        if let accessibilityIdentifier = accessibilityIdentifier {
            dict[AutoCaptureConstants.accessibilityIdentifier] = accessibilityIdentifier
        }
        if let elementPath = elementPath {
            dict[AutoCaptureConstants.hierarchy] = elementPath
        }
        if let targetAction = targetAction {
            dict[AutoCaptureConstants.targetAction] = targetAction
        }
        if let targetClass = targetClass {
            dict[AutoCaptureConstants.targetClass] = targetClass
        }
        if let referenceName = referenceName {
            dict[AutoCaptureConstants.referenceName] = referenceName
        }
        if let placeholder = placeholder {
            dict[AutoCaptureConstants.placeholder] = placeholder
        }
        if let dialogTitle = dialogTitle {
            dict[AutoCaptureConstants.dialogTitle] = dialogTitle
        }
        if let dialogMessage = dialogMessage {
            dict[AutoCaptureConstants.dialogMessage] = dialogMessage
        }

        // Index path properties
        if let section = section {
            dict[AutoCaptureConstants.section] = section
        }
        if let row = row {
            dict[AutoCaptureConstants.row] = row
        }

        // Gesture properties
        if let isLongPress = isLongPress {
            dict[AutoCaptureConstants.isLongPress] = isLongPress
        }

        return dict
    }

    // Converts the payload to a dictionary for event properties
    // swiftlint:disable:next function_body_length cyclomatic_complexity superfluous_disable_command
    func toSourceDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        // Value properties
        if let boolValue = boolValue {
            dict[AutoCaptureConstants.isChecked] = boolValue
        }
        if let floatValue = floatValue {
            dict[AutoCaptureConstants.value] = floatValue
        }
        if let doubleValue = doubleValue {
            dict[AutoCaptureConstants.value] = doubleValue
        }
        if let intValue = intValue {
            dict[AutoCaptureConstants.selectedIndex] = intValue
        }
        if let stringValue = stringValue {
            dict[AutoCaptureConstants.selectedValue] = stringValue
        }
        if let dateValue = dateValue {
            dict[AutoCaptureConstants.selectedDate] = ISO8601DateFormatter().string(from: dateValue)
        }

        // Text input properties
        if let hasText = hasText {
            dict[AutoCaptureConstants.hasText] = hasText
        }
        if let textLength = textLength {
            dict[AutoCaptureConstants.textLength] = textLength
        }

        return dict
    }

}
