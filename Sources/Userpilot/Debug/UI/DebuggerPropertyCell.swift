//
//  DebuggerPropertyCell.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

internal final class DebuggerPropertyCell: UITableViewCell {

    static let reuseId = "DebuggerPropertyCell"

    private let keyLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        backgroundColor = DebuggerTheme.surface

        keyLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        keyLabel.textColor = DebuggerTheme.text
        keyLabel.numberOfLines = 0

        valueLabel.font = UIFont.systemFont(ofSize: 13)
        valueLabel.textColor = DebuggerTheme.secondary
        valueLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [keyLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(key: String, value: String) {
        keyLabel.text = key
        valueLabel.text = value
    }
}
