//
//  InteractionType.swift
//  Userpilot
//
//  Created by Motasem Hamed on 28/03/2026.
//

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
