//
//  TooltipsHubViewController.swift
//  UserpilotSample
//
//  Hub for tooltip testing: manual bench + demo app.
//

import UIKit

final class TooltipsHubViewController: BaseViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let items: [TooltipsHubContent] = [
        .testBench,
        .demoApp
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tooltips"
        setupTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("tooltips hub")
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

    static func newInstance() -> TooltipsHubViewController {
        TooltipsHubViewController()
    }
}

extension TooltipsHubViewController: UITableViewDataSource, UITableViewDelegate {

    // Section 0 is the bench and demo; section 1 has one screen per target alert.
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 1 ? "Target alerts" : nil
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 1 ? TooltipAlertCase.allCases.count : items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        if indexPath.section == 1 {
            let alert = TooltipAlertCase.allCases[indexPath.row]
            config.text = alert.title
            config.secondaryText = "Expected reason: \(alert.reason)"
            config.image = UIImage(systemName: "exclamationmark.triangle")
        } else {
            config.text = items[indexPath.row].title
            config.secondaryText = items[indexPath.row].subtitle
            config.image = UIImage(systemName: items[indexPath.row].symbolName)
        }
        config.imageProperties.tintColor = SampleAppearance.accentColor
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            let alert = TooltipAlertCase.allCases[indexPath.row]
            FlowRoutingManager.shared.openViewController(TooltipAlertViewController(alert: alert))
            return
        }
        switch items[indexPath.row] {
        case .testBench:
            FlowRoutingManager.shared.openViewController(TooltipsTestViewController())
        case .demoApp:
            FlowRoutingManager.shared.openViewController(TooltipsDemoTabBarController())
        }
    }
}

private enum TooltipsHubContent {
    case testBench
    case demoApp

    var title: String {
        switch self {
        case .testBench: return "Test Bench"
        case .demoApp: return "Demo App"
        }
    }

    var subtitle: String {
        switch self {
        case .testBench: return "Targets for Builder-made tooltips, one below the fold"
        case .demoApp: return "Dashboard, newsfeed and profile tabs to target"
        }
    }

    var symbolName: String {
        switch self {
        case .testBench: return "hammer"
        case .demoApp: return "square.grid.2x2"
        }
    }
}
