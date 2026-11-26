//
//  InteractionType.swift
//  Userpilot SDK
//
//  Created by Userpilot on 28/03/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Defines automatically captured interaction kinds and their payload names.
//

import Foundation

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

    /// System view controller presented (e.g. UIActivityViewController) — not used for `UIAlertController`.
    case viewPresented = "view_presented"

    /// Tabbar selected
    case tabSelected = "tab_selected"
}

internal enum InteractionEventType: String {
    /// Button, tap gesture, generic tap-like interaction
    case tap = "tap"

    /// Text field / text view edits
    case textChange = "text_change"

    /// Picker / segmented / page / table / collection selection changes
    case selectionChange = "selection_change"

    /// Switch / slider / stepper / date picker value changes
    case valueChange = "value_change"

    /// UIAlertDialog
    case viewPresented = "view_presented"
}

extension InteractionType {
    /// Raw type is always present; an unresolved framework contributes no metadata field.
    func buildInternalProperties(framework: Userpilot.AppFramework?) -> [String: Any] {
        var result: [String: String] = [
            Constants.AutoCapture.rawInteractionType: rawValue
        ]
        if let framework = framework?.rawValue {
            result[Constants.AutoCapture.uiFramework] = framework
        }
        return result
    }

    func toInteractionEventType() -> InteractionEventType {
        switch self {
        case .tap, .gesture:
            return .tap

        case .textFieldChanged, .textViewChanged:
            return .textChange

        case .segmentChanged,
            .pageControlChanged,
            .tableViewCellSelected,
            .collectionViewItemSelected,
            .pickerViewChanged,
            .tabSelected:
            return .selectionChange

        case .switchChanged,
            .sliderChanged,
            .stepperChanged,
            .datePickerChanged:
            return .valueChange

        case .viewPresented:
            return .viewPresented
        }
    }
}

// MARK: - Tab properties

extension InteractionType {
    /// Builds the native tab fields and shallow hierarchy from the coordinator's captured screen.
    /// A blank content-controller leaf omits hierarchy; the tracked screen alone is not substituted.
    func buildTabProperties(
        name tabName: String,
        index tabIndex: Int,
        screenClass: String,
        screen: ScreenTrackingPayload?,
        framework: Userpilot.AppFramework?
    ) -> [String: Any] {
        var properties: [String: Any] = [
            Constants.AutoCapture.tabName: tabName,
            Constants.AutoCapture.tabIndex: tabIndex
        ]
        let internalProps = buildInternalProperties(framework: framework)
        properties.merge(internalProps) { (_, new) in new }

        // Tabs keep their shallow content-controller leaf followed by the tracked screen.
        let leaf = screenClass.trimmingCharacters(in: .whitespacesAndNewlines)
        if !leaf.isEmpty {
            let escaped = leaf.replacingOccurrences(of: "\"", with: "\\\"")
            let hierarchy = "\(escaped):attr__index=\"\(tabIndex)\""
            properties[Constants.AutoCapture.hierarchy] = screen?.buildHierarchyPath(hierarchy) ?? hierarchy
        }
        return properties
    }
}
