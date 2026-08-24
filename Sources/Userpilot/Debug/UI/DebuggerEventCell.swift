//
//  DebuggerEventCell.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

internal final class DebuggerEventCell: UITableViewCell {

    static let reuseId = "DebuggerEventCell"

    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
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

        metaLabel.font = UIFont.systemFont(ofSize: 12)
        metaLabel.textColor = DebuggerTheme.secondary
        metaLabel.numberOfLines = 1

        propertiesLabel.font = UIFont.systemFont(ofSize: 12)
        propertiesLabel.textColor = DebuggerTheme.secondary
        propertiesLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, metaLabel, propertiesLabel])
        stack.axis = .vertical
        stack.spacing = 4
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
        metaLabel.text = "\(event.typeLabel)  ·  \(time)"
        if event.properties.isEmpty {
            propertiesLabel.text = nil
            propertiesLabel.isHidden = true
        } else {
            propertiesLabel.isHidden = false
            propertiesLabel.text = event.properties
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
        }
    }
}
