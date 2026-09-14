//
//  MainViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 19/08/2024.
//

import Foundation
import UIKit

final class MainViewController: BaseViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let items: [Content] = [
        .configurations,
        .identify,
        .screens,
        .events,
        .eventsLog,
        .debug,
        .autoCapture
    ]

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Userpilot"
        setupTable()
        UserpilotManager.shared.settings()
        presentConfigIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("main")
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

    /// Mirrors Android MainActivity: open Configuration when no app token is saved.
    private func presentConfigIfNeeded() {
        let appToken: String = StorageManager.shared.get(forKey: StorageManager.Keys.appToken) ?? ""
        guard appToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            self?.openConfigScreen()
        }
    }

    private func openConfigScreen() {
        if FlowRoutingManager.shared.visibleViewController is ConfigViewController {
            return
        }
        FlowRoutingManager.shared.openViewController(ConfigViewController())
    }

    static func newInstance() -> MainViewController {
        MainViewController()
    }
}

extension MainViewController: UITableViewDataSource, UITableViewDelegate {

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
        case .identify:
            FlowRoutingManager.shared.openViewController(IdentifyViewController.newInstance())
        case .screens:
            FlowRoutingManager.shared.openViewController(ScreenOneViewController.newInstance())
        case .events:
            FlowRoutingManager.shared.openViewController(CustomEventViewController.newInstance())
        case .configurations:
            openConfigScreen()
        case .eventsLog:
            FlowRoutingManager.shared.openViewController(SDKEventsViewController.newInstance())
        case .debug:
            FlowRoutingManager.shared.openViewController(DebugViewController.newInstance())
        case .autoCapture:
            FlowRoutingManager.shared.openViewController(AutoCaptureHubViewController.newInstance())
        }
    }
}
