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
    ///
    /// The dialog is handed the survey's own colours rather than left on its defaults. Those
    /// defaults are black text on a light grey card, which is unreadable over a dark survey — the
    /// theme's `textColor` already resolves to something legible on the card this dialog floats
    /// above, and its background is what decides whether the dialog goes light or dark.
    @objc func showDatePicker() {
        let dialog = DatePickerDialog(
            textColor: surveyTheme?.textColor ?? .black,
            // The brand colour tints the actions, the way a system alert tints its own. The dialog
            // falls back to a plain legible colour if this one cannot be read on its surface.
            buttonColor: surveyTheme?.primaryColor ?? .black,
            themeBackground: surveyTheme?.backgroundColor
        )
        dialog.glassResolver = glassResolver
        dialog.show {[weak self] date in
            guard let self, let date else { return }
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            self.textField.text = formatter.string(from: date)
            self.viewStateProtocol?.onViewStateChanged(isValid: self.isValidAnswer())
        }
    }
}
