//
//  ConfigFlagTableViewCell.swift
//  UserpilotSample
//
//  Created by Userpilot on 21/07/2026.
//

import UIKit

/// Renders a single `ConfigFlag`: title, description and an on/off switch.
final class ConfigFlagTableViewCell: UITableViewCell {

    static let reuseIdentifier = "ConfigFlagTableViewCell"

    // MARK: - UI Components

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let flagSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        return toggle
    }()

    private let dividerView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Callback

    /// Called whenever the user toggles the switch.
    private var onToggle: ((Bool) -> Void)?

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        selectionStyle = .none
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(flagSwitch)
        contentView.addSubview(dividerView)

        flagSwitch.setContentHuggingPriority(.required, for: .horizontal)
        flagSwitch.setContentCompressionResistancePriority(.required, for: .horizontal)
        flagSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: flagSwitch.leadingAnchor, constant: -12),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: flagSwitch.leadingAnchor, constant: -12),

            flagSwitch.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            flagSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            dividerView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            dividerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dividerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            dividerView.heightAnchor.constraint(equalToConstant: 1),
            dividerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    // MARK: - Configuration

    func configure(with flag: ConfigFlag, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        titleLabel.text = flag.title
        descriptionLabel.text = flag.description
        flagSwitch.isOn = isOn
        self.onToggle = onToggle
    }

    // MARK: - Actions

    @objc private func switchChanged() {
        onToggle?(flagSwitch.isOn)
    }
}
