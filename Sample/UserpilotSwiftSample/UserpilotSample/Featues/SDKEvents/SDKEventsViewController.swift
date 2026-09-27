//
//  SDKEventsViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 16/11/2024.
//

import Foundation
import UIKit

class SDKEventsViewController: BaseViewController {

    // MARK: - IBOutlet

    @IBOutlet weak var emptyContentLabel: UILabel!
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.rowHeight = UITableView.automaticDimension
            tableView.estimatedRowHeight = 160
            tableView.separatorStyle = .none
            tableView.backgroundColor = SampleAppearance.screenBackground
            tableView.register(
                SDKEventTableViewCell.self,
                forCellReuseIdentifier: SDKEventTableViewCell.reuseIdentifier
            )
        }
    }

    private var userpilotSDKEvents = UserpilotManager.shared.userpilotSDKEvents

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Events log"
        configureEmptyState()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Clear",
            style: .plain,
            target: self,
            action: #selector(clearEvents)
        )
        navigationItem.rightBarButtonItem?.isEnabled = !userpilotSDKEvents.isEmpty
        updateTitleCount()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadEvents()
    }

    // MARK: - Actions

    @objc private func clearEvents() {
        UserpilotManager.shared.clearSDKEvents()
        reloadEvents()
    }

    private func reloadEvents() {
        userpilotSDKEvents = UserpilotManager.shared.userpilotSDKEvents
        tableView.reloadData()
        emptyContentLabel.isHidden = !userpilotSDKEvents.isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !userpilotSDKEvents.isEmpty
        updateTitleCount()
    }

    private func updateTitleCount() {
        let count = userpilotSDKEvents.count
        title = count == 0 ? "Events log" : "Events log (\(count))"
    }

    private func configureEmptyState() {
        emptyContentLabel.text = "No events have been tracked yet"
        emptyContentLabel.textColor = .secondaryLabel
        emptyContentLabel.font = .systemFont(ofSize: 15, weight: .medium)
        emptyContentLabel.isHidden = !userpilotSDKEvents.isEmpty
    }

}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension SDKEventsViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userpilotSDKEvents.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let eventTableViewCell: SDKEventTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        eventTableViewCell.bindCell(userpilotSDKEvents[indexPath.row])
        return eventTableViewCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        presentJSONPreview(for: userpilotSDKEvents[indexPath.row])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNonzeroMagnitude
    }

    private func presentJSONPreview(for event: UserpilotSDKEvent) {
        let properties: [String: Any]?
        if event.analytic == "Identify" {
            properties = UserpilotManager.shared.settings()
        } else {
            properties = event.properties
        }

        let alert = UIAlertController(
            title: event.analytic,
            message: event.value,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Copy JSON", style: .default, handler: { _ in
            let payload: [String: Any] = [
                "type": event.analytic,
                "title": event.value,
                "properties": properties ?? [:]
            ]
            UIPasteboard.general.string = JSONPreview.prettyString(from: payload)
        }))
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        present(alert, animated: true)
    }

}

// MARK: - Instance

extension SDKEventsViewController {

    static func newInstance() -> SDKEventsViewController {
        return SDKEventsViewController()
    }

}
