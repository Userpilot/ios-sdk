//
//  EventsViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 11/09/2024.
//

import Foundation
import UIKit

class EventsViewController: BaseViewController {

    // MARK: - IBOutlet

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.rowHeight = UITableView.automaticDimension
            tableView.estimatedRowHeight = 217
            tableView.register(cellFromNib: EventTableViewCell.self)
        }
    }

    // MARK: - override

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("events")
    }

    // MARK: - IBAction

    @IBAction func onBackButtonClicked(_ sender: UIButton) {
        close()
    }

    // MARK: - Track Event

    private func trackEvent(_ position: Int, _ title: String?, _ value: String?) {
        var properties: [String: Any] = [:]

        if let title, !title.isEmpty, let value = value, !value.isEmpty {
            properties[title] = value
        }

        UserpilotManager.shared.track(eventName: "Row #\(position)", properties: properties.isEmpty ? nil : properties)
    }

}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension EventsViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 20
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let eventTableViewCell: EventTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        eventTableViewCell.selectionStyle = .none
        eventTableViewCell.bindCell(indexPath)
        eventTableViewCell.onTrackEvent = { [weak self] title, value in
            self?.trackEvent(indexPath.row, title, value)
        }
        return eventTableViewCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNonzeroMagnitude
    }

}

// MARK: - Instance

extension EventsViewController {

    static func newInstance() -> EventsViewController {
        return EventsViewController()
    }

}
