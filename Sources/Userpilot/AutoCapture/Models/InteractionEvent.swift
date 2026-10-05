//
//  InteractionEvent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 17/02/2026.
//  Copyright © 2024 Userpilot. All rights reserved.
//
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
    var targetClass: String

    // MARK: - Optional Element Properties

    /// The display text or label of the element
    var elementText: String?

    /// The accessibility label of the element
    var accessibilityLabel: String?

    /// The accessibility identifier of the element
    var accessibilityIdentifier: String?

    /// The hierarchical path to the element
    var hierarchy: String?

    /// The target action name (e.g., "onBackButtonClicked:" from IBAction)
    var targetAction: String?

    /// The target class name that handles the action
    var ownerTargetClass: String?

    /// The IBOutlet property name (e.g., "searchTextField")
    var targetViewName: String?

    /// The placeholder text (for text fields and text views)
    var placeholder: String?

    /// The dialog title
    var dialogTitle: String?

    /// The dialog message
    var dialogMessage: String?

    // MARK: - Index Path Properties (for table/collection views)

    /// Section index for table/collection view selections
    var section: Int?

    /// Row/item index for table/collection view selections
    var row: Int?

    /// Control-specific and privacy-safe values (switch on/off, slider value, selected index, text length, etc.).
    /// Prefer keys from `Constants.AutoCapture`; merged into the published payload by `toSourceDictionary()`.
    var sourceProperties: [String: Any] = [:]

    // MARK: - Initialization

    /// Creates an interaction payload with required properties
    init(
        interactionType: InteractionType,
        elementType: String
    ) {
        self.interactionType = interactionType
        self.targetClass = elementType
    }

}

// MARK: - Payload Conversion

extension InteractionPayload {

    /// Builds a dialog interaction without replacing the underlying tracked screen.
    static func fromDialog(_ screen: ScreenTrackingPayload) -> InteractionPayload {
        var payload = InteractionPayload(
            interactionType: .viewPresented,
            elementType: Constants.AutoCapture.elementTypeUIAlertController
        )
        payload.dialogTitle = screen.alertTitle
        payload.dialogMessage = screen.alertMessage

        // Dialogs retain a shallow leaf; the coordinator appends the underlying screen later.
        let dialogClass = screen.screenClass.trimmingCharacters(in: .whitespacesAndNewlines)
        let leaf = dialogClass.isEmpty
            ? Constants.AutoCapture.elementTypeUIAlertController
            : dialogClass.replacingOccurrences(of: "\"", with: "\\\"")
        payload.hierarchy = "\(leaf):attr__index=\"0\""
        return payload
    }

    /// Maps window `sendEvent` fields without adding values absent from the captured dictionary.
    /// Window-touch filtering remains with the coordinator and runs before this conversion.
    static func fromWindowClick(_ properties: [String: Any]) -> InteractionPayload? {
        guard let elementType = properties[Constants.AutoCapture.targetClass] as? String else {
            return nil
        }
        var payload = InteractionPayload(
            interactionType: .tap,
            elementType: elementType
        )
        if let targetText = properties[Constants.AutoCapture.targetText] as? String {
            payload.elementText = targetText
        }
        if let accessibilityLabel = properties[Constants.AutoCapture.accessibilityLabel] as? String {
            payload.accessibilityLabel = accessibilityLabel
        }
        if let targetResourceId = properties[Constants.AutoCapture.accessibilityIdentifier] as? String {
            payload.accessibilityIdentifier = targetResourceId
        }
        payload.hierarchy = properties[Constants.AutoCapture.hierarchy] as? String
        return payload
    }

    // Encodes captured target fields; nil fields are omitted while captured empty strings remain.
    // swiftlint:disable:next function_body_length cyclomatic_complexity superfluous_disable_command
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            Constants.AutoCapture.targetClass: targetClass
        ]

        // Element properties
        if let elementText = elementText {
            dict[Constants.AutoCapture.targetText] = elementText
        }
        if let accessibilityLabel = accessibilityLabel {
            dict[Constants.AutoCapture.accessibilityLabel] = accessibilityLabel
        }
        if let accessibilityIdentifier = accessibilityIdentifier {
            dict[Constants.AutoCapture.accessibilityIdentifier] = accessibilityIdentifier
        }
        if let hierarchy = hierarchy {
            dict[Constants.AutoCapture.hierarchy] = hierarchy
        }
        if let targetAction = targetAction {
            dict[Constants.AutoCapture.targetAction] = targetAction
        }
        if let targetClass = ownerTargetClass {
            dict[Constants.AutoCapture.ownerTargetClass] = targetClass
        }
        if let targetViewName = targetViewName {
            dict[Constants.AutoCapture.targetViewName] = targetViewName
        }
        if let placeholder = placeholder {
            dict[Constants.AutoCapture.placeholder] = placeholder
        }
        if let dialogTitle = dialogTitle {
            dict[Constants.AutoCapture.dialogTitle] = dialogTitle
        }
        if let dialogMessage = dialogMessage {
            dict[Constants.AutoCapture.dialogMessage] = dialogMessage
        }

        // Index path properties
        if let section = section {
            dict[Constants.AutoCapture.section] = section
        }
        if let row = row {
            dict[Constants.AutoCapture.selectedIndex] = row
        }

        return dict
    }

    /// Values merged into the autocapture event (same keys as before: `is_checked`, `value`, `selected_index`, …).
    func toSourceDictionary() -> [String: Any] {
        sourceProperties
    }

}
