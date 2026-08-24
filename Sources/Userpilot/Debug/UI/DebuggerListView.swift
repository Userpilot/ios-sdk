//
//  DebuggerListView.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

internal final class DebuggerListView: UIView, UITableViewDataSource, UITableViewDelegate {

    private enum Mode {
        case properties
        case events
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private var mode: Mode = .properties
    private var properties: [DebugListItem] = []
    private var events: [DebugEvent] = []
    var onPropertyTap: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.backgroundColor = DebuggerTheme.surface
        tableView.register(DebuggerHeaderCell.self, forCellReuseIdentifier: DebuggerHeaderCell.reuseId)
        tableView.register(DebuggerPropertyCell.self, forCellReuseIdentifier: DebuggerPropertyCell.reuseId)
        tableView.register(DebuggerEventCell.self, forCellReuseIdentifier: DebuggerEventCell.reuseId)
        tableView.contentInset.bottom = 16
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)

        emptyLabel.text = DebuggerStrings.emptyEvents
        emptyLabel.textColor = DebuggerTheme.secondary
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showProperties(_ items: [DebugListItem]) {
        mode = .properties
        properties = items
        events = []
        applyEmpty(items.isEmpty)
        tableView.reloadData()
    }

    func showEvents(_ items: [DebugEvent]) {
        mode = .events
        events = items
        properties = []
        applyEmpty(items.isEmpty)
        tableView.reloadData()
    }

    private func applyEmpty(_ empty: Bool) {
        emptyLabel.isHidden = !empty
        tableView.isHidden = empty
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch mode {
        case .properties:
            return properties.count
        case .events:
            return events.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch mode {
        case .properties:
            return propertyCell(at: indexPath)
        case .events:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: DebuggerEventCell.reuseId,
                for: indexPath
            ) as? DebuggerEventCell ?? DebuggerEventCell(style: .default, reuseIdentifier: DebuggerEventCell.reuseId)
            cell.bind(events[indexPath.row])
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard mode == .properties, case .row(_, let value) = properties[indexPath.row] else { return }
        onPropertyTap?(value)
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch mode {
        case .properties:
            if case .row = properties[indexPath.row] {
                return true
            }
            return false
        case .events:
            return false
        }
    }

    private func propertyCell(at indexPath: IndexPath) -> UITableViewCell {
        switch properties[indexPath.row] {
        case .header(let title):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: DebuggerHeaderCell.reuseId,
                for: indexPath
            ) as? DebuggerHeaderCell ?? DebuggerHeaderCell(style: .default, reuseIdentifier: DebuggerHeaderCell.reuseId)
            cell.bind(title)
            return cell
        case .row(let key, let value):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: DebuggerPropertyCell.reuseId,
                for: indexPath
            ) as? DebuggerPropertyCell
                ?? DebuggerPropertyCell(style: .default, reuseIdentifier: DebuggerPropertyCell.reuseId)
            cell.bind(key: key, value: value)
            return cell
        }
    }
}
