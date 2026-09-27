//
//  SDKEventTableViewCell.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 16/11/2024.
//

import UIKit
import Userpilot

final class SDKEventTableViewCell: UITableViewCell, ReusableTableCellView {

    // MARK: - UI

    private let cardView = CardView()
    private let typeBadgeLabel = PaddedLabel()
    private let titleLabel = UILabel()
    private let jsonContainerView = UIView()
    private let jsonLabel = UILabel()
    private let emptyPropertiesLabel = UILabel()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        let headerStack = makeHeaderStack()
        setupJSONContainer()

        let contentStack = UIStackView(arrangedSubviews: [headerStack, jsonContainerView])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 12
        cardView.addSubview(contentStack)

        activateConstraints(contentStack: contentStack)
    }

    /// The badge + title row shown at the top of the card.
    private func makeHeaderStack() -> UIStackView {
        typeBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeBadgeLabel.textInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        typeBadgeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        typeBadgeLabel.textColor = .white
        typeBadgeLabel.layer.cornerRadius = 10
        typeBadgeLabel.layer.masksToBounds = true
        typeBadgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        typeBadgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        let headerStack = UIStackView(arrangedSubviews: [typeBadgeLabel, titleLabel])
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 10
        return headerStack
    }

    /// The JSON preview box and its "No properties" empty state.
    private func setupJSONContainer() {
        jsonContainerView.translatesAutoresizingMaskIntoConstraints = false
        jsonContainerView.backgroundColor = UIColor.tertiarySystemFill
        jsonContainerView.layer.cornerRadius = 12
        jsonContainerView.layer.cornerCurve = .continuous
        jsonContainerView.layer.masksToBounds = true

        jsonLabel.translatesAutoresizingMaskIntoConstraints = false
        jsonLabel.numberOfLines = 0
        jsonLabel.lineBreakMode = .byWordWrapping
        jsonLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
        // Preview JSON is for display only — don't let autocapture treat it as target_text.
        jsonLabel.userpilotRedactText = true
        jsonContainerView.userpilotRedactText = true

        emptyPropertiesLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyPropertiesLabel.text = "No properties"
        emptyPropertiesLabel.font = .systemFont(ofSize: 13, weight: .medium)
        emptyPropertiesLabel.textColor = .tertiaryLabel
        emptyPropertiesLabel.isHidden = true

        jsonContainerView.addSubview(jsonLabel)
        jsonContainerView.addSubview(emptyPropertiesLabel)
    }

    private func activateConstraints(contentStack: UIStackView) {
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),

            jsonLabel.topAnchor.constraint(equalTo: jsonContainerView.topAnchor, constant: 10),
            jsonLabel.leadingAnchor.constraint(equalTo: jsonContainerView.leadingAnchor, constant: 12),
            jsonLabel.trailingAnchor.constraint(equalTo: jsonContainerView.trailingAnchor, constant: -12),
            jsonLabel.bottomAnchor.constraint(equalTo: jsonContainerView.bottomAnchor, constant: -10),

            emptyPropertiesLabel.topAnchor.constraint(equalTo: jsonContainerView.topAnchor, constant: 12),
            emptyPropertiesLabel.leadingAnchor.constraint(
                equalTo: jsonContainerView.leadingAnchor, constant: 12),
            emptyPropertiesLabel.trailingAnchor.constraint(
                equalTo: jsonContainerView.trailingAnchor, constant: -12),
            emptyPropertiesLabel.bottomAnchor.constraint(
                equalTo: jsonContainerView.bottomAnchor, constant: -12)
        ])
    }

    // MARK: - Bind

    func bindCell(_ sdkEvent: UserpilotSDKEvent) {
        typeBadgeLabel.text = sdkEvent.analytic
        let title = sdkEvent.value.isEmpty ? "—" : sdkEvent.value
        titleLabel.text = title

        accessibilityLabel = sdkEvent.value.isEmpty
            ? sdkEvent.analytic
            : "\(sdkEvent.analytic): \(sdkEvent.value)"

        let tint = badgeColor(for: sdkEvent.analytic)
        typeBadgeLabel.backgroundColor = tint

        let properties: [String: Any]?
        if sdkEvent.analytic == "Identify" {
            properties = UserpilotManager.shared.settings()
        } else {
            properties = sdkEvent.properties
        }

        if let properties, !properties.isEmpty {
            jsonLabel.attributedText = JSONPreview.attributedString(from: properties, fontSize: 12)
            jsonLabel.isHidden = false
            emptyPropertiesLabel.isHidden = true
        } else {
            jsonLabel.attributedText = nil
            jsonLabel.isHidden = true
            emptyPropertiesLabel.isHidden = false
        }
    }

    private func badgeColor(for analytic: String) -> UIColor {
        let lowered = analytic.lowercased()
        if lowered.contains("identify") {
            return SampleAppearance.accentColor
        }
        if lowered.contains("screen") {
            return .systemTeal
        }
        if lowered.contains("event") {
            return .systemBlue
        }
        if lowered.contains("experience") {
            return .systemOrange
        }
        return .systemGray
    }
}
