//
//  UPSingleInputView+Date.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 20/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A extension to handle date picker
//

import UIKit

extension UPSingleInputView {

    // MARK: - Show Date Picker

    /// Displays a date picker dialog and sets the selected date to the text field.
    @objc func showDatePicker() {
        DatePickerDialog().show {[weak self] date in
            guard let self, let date else { return }
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            textField.text = formatter.string(from: date)
        }
    }
}
