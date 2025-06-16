//
//  UPSingleInputView+Phone.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 20/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A extension to handle country popup menu.
//

import UIKit

// MARK: - Country Picker Popup Menu Management for UPSingleInputView
internal extension UPSingleInputView {

    // MARK: - Popup Menu Display

    /// Displays the country picker popup menu just below the text field.
    @objc func showCoutriesPopupMenu() {
        guard let parentView = parentViewController?.view else { return }

        // Get the frame of the text field in the parent view's coordinate system
        let textFieldFrame = textField.convert(textField.bounds, to: parentView)

        var yPosition = textFieldFrame.maxY + 4
        if distanceFromViewToScreenBottom(view: textField) ?? 200 < CGFloat(220) {
            yPosition = textFieldFrame.maxY - (200 + 50 + 4)
        }
        // Create and configure the country picker popup menu
        countryPickerPopupMenu = CountryPickerPopupMenu(frame: CGRect(
            x: textFieldFrame.origin.x,
            y: yPosition,  // Positioning the menu below or above the text field
            width: textFieldFrame.width,
            height: 200  // Set a fixed height for the popup
        ), view: parentView)

        // Define the behavior when a country is selected
        countryPickerPopupMenu?.onSelectCountry = { [weak self] dialCode in
            self?.countrySelectorButton.config(
                with: dialCode,
                and: self?.surveyTheme?.textSecondaryColorAlpha80 ?? .gray)
            self?.hideCoutriesPopupMenu()
        }

        // Define the behavior when the menu is dismissed
        countryPickerPopupMenu?.onDismissMenu = { [weak self] in
            self?.hideCoutriesPopupMenu()
        }

        // Add the popup menu to the parent view and bring it to the front
        parentView.addSubview(countryPickerPopupMenu!)
        parentView.bringSubviewToFront(countryPickerPopupMenu!)

        // Initially set the popup menu's alpha to 0 for a smooth fade-in effect
        countryPickerPopupMenu?.alpha = 0
        countryPickerPopupMenu?.isHidden = false

        // Animate the appearance of the popup menu with a fade-in effect
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.countryPickerPopupMenu?.alpha = 1  // Fade in the popup
        }, completion: nil)
    }

    // MARK: - Popup Menu Hiding

    /// Hides the country picker popup menu.
    @objc func hideCoutriesPopupMenu() {
        countryPickerPopupMenu?.removeFromSuperview()
        countryPickerPopupMenu?.isHidden = true
    }
}
