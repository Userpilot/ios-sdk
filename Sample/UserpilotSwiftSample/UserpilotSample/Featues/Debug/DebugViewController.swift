//
//  DebugViewController.swift
//  UserpilotSample
//
//  Hub for QA / debug harness screens.
//

import UIKit

final class DebugViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let items: [DebugContent] = [
        .onlineQueue,
        .socketRace,
        .offlineEvents
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Debug"
        view.backgroundColor = .systemBackground
        setupBackButton()
        setupTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("debug")
    }

    private func setupBackButton() {
        let backButton = UIButton(type: .system)
        backButton.setTitle("< Back", for: .normal)
        backButton.contentHorizontalAlignment = .leading
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
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
        case .socketRace:
            FlowRoutingManager.shared.openViewController(SocketRaceReproViewController())
        case .offlineEvents:
            FlowRoutingManager.shared.openViewController(OfflineEventsViewController())
        }
    }
}

enum DebugContent {
    case onlineQueue
    case socketRace
    case offlineEvents

    var title: String {
        switch self {
        case .onlineQueue:
            return "Online queue"
        case .socketRace:
            return "Socket Race Repro (#50 / CI-3925)"
        case .offlineEvents:
            return "Offline events"
        }
    }
}
