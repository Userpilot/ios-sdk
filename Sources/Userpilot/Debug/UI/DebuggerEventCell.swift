//
//  DebuggerEventCell.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

internal final class DebuggerEventCell: UITableViewCell {

    static let reuseId = "DebuggerEventCell"

    private let titleLabel = UILabel()
    private let typeLabel = UILabel()
    private let timeLabel = UILabel()
    private let propertiesLabel = UILabel()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = DebuggerTheme.surface

        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = DebuggerTheme.text
        titleLabel.numberOfLines = 0

        typeLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        typeLabel.textColor = DebuggerTheme.brand
        typeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let tag = UIView()
        tag.backgroundColor = DebuggerTheme.tagBackground
        tag.layer.cornerRadius = 8
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        tag.addSubview(typeLabel)
        NSLayoutConstraint.activate([
            typeLabel.topAnchor.constraint(equalTo: tag.topAnchor, constant: 4),
            typeLabel.bottomAnchor.constraint(equalTo: tag.bottomAnchor, constant: -4),
            typeLabel.leadingAnchor.constraint(equalTo: tag.leadingAnchor, constant: 8),
            typeLabel.trailingAnchor.constraint(equalTo: tag.trailingAnchor, constant: -8)
        ])

        timeLabel.font = UIFont.systemFont(ofSize: 12)
        timeLabel.textColor = DebuggerTheme.secondary
        timeLabel.numberOfLines = 0
        let metadata = UIStackView(arrangedSubviews: [tag, timeLabel])
        metadata.axis = .horizontal
        metadata.alignment = .center
        metadata.spacing = 8

        propertiesLabel.font = UIFont.systemFont(ofSize: 12)
        propertiesLabel.textColor = DebuggerTheme.secondary
        propertiesLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, metadata, propertiesLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(_ event: DebugEvent) {
        titleLabel.text = event.title
        let time = Self.timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(event.timestampMs) / 1000))
        typeLabel.text = event.typeLabel
        timeLabel.text = time
        if event.properties.isEmpty {
            propertiesLabel.text = nil
            propertiesLabel.isHidden = true
        } else {
            propertiesLabel.isHidden = false
            let text = NSMutableAttributedString(string: "")
            for (index, property) in event.properties.enumerated() {
                if index > 0 { text.append(NSAttributedString(string: "\n")) }
                text.append(NSAttributedString(
                    string: "\(property.key): ",
                    attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .bold)]
                ))
                text.append(NSAttributedString(
                    string: property.value,
                    attributes: [.font: UIFont.systemFont(ofSize: 12)]
                ))
            }
            propertiesLabel.attributedText = text
        }
    }
}
