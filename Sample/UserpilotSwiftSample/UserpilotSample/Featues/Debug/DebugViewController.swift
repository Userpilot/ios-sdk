//
//  DebugViewController.swift
//  UserpilotSample
//
//  Hub for QA / debug harness screens.
//

import UIKit

final class DebugViewController: BaseViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let items: [DebugContent] = [
        .onlineQueue,
        .offlineEvents
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Debug"
        setupTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("debug")
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

    static func newInstance() -> DebugViewController {
        DebugViewController()
    }
}

extension DebugViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row].title
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch items[indexPath.row] {
        case .onlineQueue:
            FlowRoutingManager.shared.openViewController(OnlineQueueViewController())
        case .offlineEvents:
            FlowRoutingManager.shared.openViewController(OfflineEventsViewController())
        }
    }
}

enum DebugContent {
    case onlineQueue
    case offlineEvents

    var title: String {
        switch self {
        case .onlineQueue:
            return "Online queue"
        case .offlineEvents:
            return "Offline events"
        }
    }
}
