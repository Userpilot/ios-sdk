//
//  UPSingleInputView+View.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 20/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A extension to handle setup views.
//

import UIKit

extension UPSingleInputView {

    // MARK: - Configure Text Field

    /// Configures the text field based on the provided text type.
    func configureTextField(for type: SingleTextType) {
        switch type {
        case .number:
            textField.setPadding(start: 10, end: 10)
            textField.keyboardType = .numberPad
            countryStackView.isHidden = true
            calendarIconButton.isHidden = true
        case .date:
            setDirectionalPadding(leading: 10, trailing: 60)
            textField.keyboardType = .numberPad
            textField.placeholder = "dd/mm/yyyy"
            calendarIconButton.isHidden = false
            countryStackView.isHidden = true
            calendarIconButton.tintColor = ThemeHandler.DefaultValues.grayColor
        case .phone:
            setDirectionalPadding(leading: 120, trailing: 10)
            textField.keyboardType = .phonePad
            countryStackView.isHidden = false
            calendarIconButton.isHidden = true
            downArrowButton.tintColor = ThemeHandler.DefaultValues.grayColor
            countrySelectorButton.config(with: "+1", and: ThemeHandler.DefaultValues.grayColor)
        case .email:
            textField.setPadding(start: 10, end: 10)
            textField.keyboardType = .emailAddress
            countryStackView.isHidden = true
            calendarIconButton.isHidden = true
        case .text:
            textField.setPadding(start: 10, end: 10)
            textField.keyboardType = .default
            countryStackView.isHidden = true
            calendarIconButton.isHidden = true
        case .general:
            textField.setPadding(start: 10, end: 10)
            textField.keyboardType = .default
            countryStackView.isHidden = true
            calendarIconButton.isHidden = true
        }
    }

    private func setDirectionalPadding(leading: CGFloat, trailing: CGFloat) {
        if isRTL == isAppRTL {
            textField.setPadding(start: leading, end: trailing)
        } else {
            textField.setPadding(start: trailing, end: leading)
        }
    }

    // MARK: - Setup View
    // swiftlint:disable:next function_body_length
    func setupView() {
        addTapGesture { [weak self] in
            self?.endEditing(true)
        }
        backgroundColor = .clear
        // Setup countryStackView
        countryStackView.addArrangedSubviews([countrySelectorButton, downArrowButton, separatorView])
        countryStackView.axis = .horizontal
        countryStackView.spacing = 10
        countryStackView.translatesAutoresizingMaskIntoConstraints = false
        countryStackView.alignment = .center
        countryStackView.isHidden = true

        // Setup titleDescriptionView
        addSubview(titleDescriptionView)
        titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false

        // Setup textField
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(equalToConstant: 50).isActive = true
        textField.borderStyle = .none
        textField.layer.borderWidth = 1
        textField.layer.cornerRadius = 8
        textField.layer.borderColor = ThemeHandler.DefaultValues.grayColor.cgColor
        textField.returnKeyType = .done
        textField.delegate = self
        textField.backgroundColor = .clear
        textField.disableAutoCorrect()
        textField.addTarget(self, action: #selector(textDidChange(_:)), for: .editingChanged)
        addSubview(textField)

        // Setup calendar button
        calendarIconButton.translatesAutoresizingMaskIntoConstraints = false
        calendarIconButton.setImage(UIImage.userpilotImage(named: "userpilot_icon_calander"), for: .normal)
        calendarIconButton.addTarget(self, action: #selector(showDatePicker), for: .touchUpInside)
        addSubview(calendarIconButton)
        calendarIconButton.isHidden = true

        // Setup country selector button
        countrySelectorButton.translatesAutoresizingMaskIntoConstraints = false
        countrySelectorButton.addTarget(self, action: #selector(showCoutriesPopupMenu), for: .touchUpInside)

        // Setup down arrow button
        downArrowButton.translatesAutoresizingMaskIntoConstraints = false
        downArrowButton.setImage(UIImage.userpilotImage(named: "userpilot_icon_down_arrow"), for: .normal)
        downArrowButton.addTarget(self, action: #selector(showCoutriesPopupMenu), for: .touchUpInside)
        addSubview(countryStackView)

        // Setup separator view
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = .lightGray

        // Apply constraints for the layout
        NSLayoutConstraint.activate([
            titleDescriptionView.topAnchor.constraint(equalTo: topAnchor),
            titleDescriptionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            titleDescriptionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: margin.negative),

            textField.topAnchor.constraint(equalTo: titleDescriptionView.bottomAnchor, constant: 16),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: margin.negative),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),

            calendarIconButton.trailingAnchor.constraint(equalTo: textField.trailingAnchor, constant: -16),
            calendarIconButton.centerYAnchor.constraint(equalTo: textField.centerYAnchor),

            // Country stack view positioning
            countryStackView.leadingAnchor.constraint(equalTo: textField.leadingAnchor, constant: 8),
            countryStackView.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
            countryStackView.widthAnchor.constraint(equalToConstant: 100),

            separatorView.heightAnchor.constraint(equalToConstant: 30),
            separatorView.widthAnchor.constraint(equalToConstant: 1)
        ])
    }
}
