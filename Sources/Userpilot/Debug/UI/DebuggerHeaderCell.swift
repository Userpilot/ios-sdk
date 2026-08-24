//
//  DebuggerHeaderCell.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

internal final class DebuggerHeaderCell: UITableViewCell {

    static let reuseId = "DebuggerHeaderCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = DebuggerTheme.headerBackground
        textLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        textLabel?.textColor = DebuggerTheme.secondary
        textLabel?.numberOfLines = 1
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(_ title: String) {
        textLabel?.text = title.uppercased()
    }
}
