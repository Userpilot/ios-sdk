//
//  ChoiceTableViewCell.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Custom UITableViewCell used to display a choice in the multiple-choice survey view.
//  Includes icons, labels, and text field for "Other" option with dynamic styling and selection states.
//

import UIKit

internal class ChoiceTableViewCell: UITableViewCell {

    // MARK: - Properties
    static let identifier = "ChoiceTableViewCell"

    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let label = UILabel()
    private let textField = UITextField()

    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    // MARK: - Setup Cell
    private func setupCell() {
        // Add containerView to contentView
        contentView.addSubview(containerView)

        // Configure containerView
        containerView.layer.cornerRadius = 8
        containerView.layer.borderWidth = 1
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.borderColor = UIColor.gray.cgColor

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 47)
        ])

        // Add iconImageView, label, and textField to containerView
        containerView.addSubview(iconImageView)
        containerView.addSubview(label)
        containerView.addSubview(textField)
        textField.isHidden = true

        // Configure iconImageView
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24)
        ])

        // Configure label
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8)
        ])

        // Configure textField
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.borderStyle = .none
        textField.isUserInteractionEnabled = false
        textField.isHidden = true
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            textField.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 47)
        ])
    }

    // MARK: - Binding Data
    func bindCell(choice: Choice, surveyStep: SurveyStep, surveyTheme: SurveyTheme) {
        textField.textColor = surveyTheme.textColor
        textField.setPlaceholder(text: choice.value ?? "", color: surveyTheme.textColor)
        textField.font = UIFont.matching(
            fontName: surveyTheme.fontFamily, fontWeight: [.traitMonoSpace],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyDescriptionTextSize))

        label.text = choice.value
        label.textColor = surveyTheme.textColor
        iconImageView.image = getIcon(for: choice, with: surveyStep)
        label.font = UIFont.matching(
            fontName: surveyTheme.fontFamily, fontWeight: [.traitMonoSpace],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyDescriptionTextSize))

        // Styling based on selection state
        if choice.isSelected == true {
            containerView.layer.borderColor = surveyTheme.primaryColor.cgColor
            containerView.backgroundColor = surveyTheme.secondaryColor
            iconImageView.tintColor = surveyTheme.primaryColor
        } else {
            containerView.layer.borderColor = surveyTheme.textSecondaryColor.cgColor
            containerView.backgroundColor = .clear
            iconImageView.tintColor = surveyTheme.textSecondaryColor
        }

        // Handle 'Other' option
        if choice.id == ThemeHandler.DefaultValues.surveyOtherChoice {
            showTextField(true)
            if let otherText = choice.otherOptionText, !otherText.isEmpty {
                textField.text = otherText
            }
            if choice.isSelected == true {
                textField.isUserInteractionEnabled = true
                textField.becomeFirstResponder()
            }
        } else {
            textField.isUserInteractionEnabled = false
            showTextField(false)
        }
    }

    // MARK: - Helper Methods
    func showTextField(_ show: Bool) {
        textField.isHidden = !show
        label.isHidden = show
    }

    func getOtherOptionText() -> String? {
        return textField.text
    }

    func showKeyboard() {
        textField.becomeFirstResponder()
    }

    private func getIcon(for choice: Choice, with surveyStep: SurveyStep) -> UIImage? {
        if surveyStep.metadata?.isMultiSelect == true {
            return UIImage(
                named: choice.isSelected == true ? "icon_check_box_selected" : "icon_check_box_unselected",
                in: Userpilot.resourceBundle,
                compatibleWith: nil
            )
        } else {
            return UIImage(
                named: choice.isSelected == true ? "icon_radio_button_selected" : "icon_radio_button_unselected",
                in: Userpilot.resourceBundle,
                compatibleWith: nil
            )
        }
    }
}
