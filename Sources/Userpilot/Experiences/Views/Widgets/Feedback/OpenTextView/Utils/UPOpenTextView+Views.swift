//
//  UPOpenTextView+Views.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  An extension to setup views.
//

import UIKit

internal extension UPOpenTextView {

    /// Sets up the views.
    func setupView() {
        addSubview(titleDescriptionView)
        addSubview(textViewContainer)

        // TitleDescriptionView constraints
        titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleDescriptionView.topAnchor.constraint(equalTo: topAnchor),
            titleDescriptionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleDescriptionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])

        // TextView Container setup
        textViewContainer.translatesAutoresizingMaskIntoConstraints = false
        textViewContainer.layer.borderWidth = 1
        textViewContainer.layer.borderColor = UIColor.grayCA.cgColor
        textViewContainer.layer.cornerRadius = 8
        addSubview(textViewContainer)

        // TextView constraints
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.delegate = self
        textViewContainer.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: textViewContainer.topAnchor, constant: 4),
            textView.leadingAnchor.constraint(equalTo: textViewContainer.leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: textViewContainer.trailingAnchor, constant: -8),
            textView.bottomAnchor.constraint(equalTo: textViewContainer.bottomAnchor, constant: -4)
        ])

        // Placeholder setup
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.numberOfLines = 0
        textViewContainer.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textViewContainer.topAnchor, constant: 12),
            placeholderLabel.leadingAnchor.constraint(equalTo: textViewContainer.leadingAnchor, constant: 12),
            placeholderLabel.trailingAnchor.constraint(equalTo: textViewContainer.trailingAnchor, constant: -8)
        ])

        // Counter Label setup
        counterLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(counterLabel)

        NSLayoutConstraint.activate([
            counterLabel.topAnchor.constraint(equalTo: textViewContainer.bottomAnchor),
            counterLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -26),
            counterLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])

        // TextViewContainer constraints
        NSLayoutConstraint.activate([
            textViewContainer.topAnchor.constraint(equalTo: titleDescriptionView.bottomAnchor, constant: 16),
            textViewContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            textViewContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            textViewContainer.heightAnchor.constraint(equalToConstant: 80)
        ])

        // Initial counter setup
        updateCounter()
    }

    /// Updates the character counter label with the current text length.
    private func updateCounter() {
        let textLength = textView.text.count
        counterLabel.text = "\(textLength)/\(maxLength)"
    }

}

// MARK: - UITextViewDelegate

extension UPOpenTextView: UITextViewDelegate {

    /// Handles text change events in the text view.
    ///
    /// This method hides the placeholder label when the text view is not empty and updates the character counter.
    /// It also triggers the `onViewStateChanged` callback to notify the delegate of the state change.
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateCounter()
        viewStateProtocol?.onViewStateChanged(isValid: isValidAnswer())
    }
}
