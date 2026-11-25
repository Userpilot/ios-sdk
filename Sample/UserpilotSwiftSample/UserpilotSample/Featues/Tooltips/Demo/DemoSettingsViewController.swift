//
//  DemoSettingsViewController.swift
//  UserpilotSample
//
//  Settings screen opened from the Profile tab in the Tooltips demo app.
//

import UIKit

final class DemoSettingsViewController: BaseViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let pushSwitch = UISwitch()
    private let analyticsSwitch = UISwitch()
    private let darkModeSwitch = UISwitch()

    private let rows: [SettingsRow] = [
        .pushNotifications,
        .analytics,
        .darkMode,
        .language,
        .about
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.accessibilityIdentifier = "demo-settings-screen"
        pushSwitch.isOn = true
        analyticsSwitch.isOn = true
        darkModeSwitch.isOn = false
        setupTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("demo settings")
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = SampleAppearance.screenBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func switchForRow(_ row: SettingsRow) -> UISwitch? {
        switch row {
        case .pushNotifications: return pushSwitch
        case .analytics: return analyticsSwitch
        case .darkMode: return darkModeSwitch
        case .language, .about: return nil
        }
    }
}

extension DemoSettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = row.title
        config.image = UIImage(systemName: row.symbolName)
        config.imageProperties.tintColor = SampleAppearance.accentColor
        cell.contentConfiguration = config
        cell.accessibilityIdentifier = "demo-settings-\(row.rawValue)"

        if let toggle = switchForRow(row) {
            toggle.accessibilityIdentifier = "demo-settings-toggle-\(row.rawValue)"
            cell.accessoryView = toggle
            cell.selectionStyle = .none
            cell.accessoryType = .none
        } else {
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        guard switchForRow(row) == nil else { return }
        let alert = UIAlertController(
            title: row.title,
            message: "Demo placeholder for \(row.title.lowercased()).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

private enum SettingsRow: String {
    case pushNotifications
    case analytics
    case darkMode
    case language
    case about

    var title: String {
        switch self {
        case .pushNotifications: return "Push Notifications"
        case .analytics: return "Analytics"
        case .darkMode: return "Dark Mode"
        case .language: return "Language"
        case .about: return "About"
        }
    }

    var symbolName: String {
        switch self {
        case .pushNotifications: return "bell.badge"
        case .analytics: return "chart.xyaxis.line"
        case .darkMode: return "moon.fill"
        case .language: return "globe"
        case .about: return "info.circle"
        }
    }
}
