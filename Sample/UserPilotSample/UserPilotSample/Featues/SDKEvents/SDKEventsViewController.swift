//
//  SDKEventsViewController.swift
//  UserPilotSample
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
            tableView.estimatedRowHeight = 105
            tableView.register(cellFromNib: SDKEventTableViewCell.self)
        }
    }

    private var userPilotSDKEvents = UserPilotManager.shared.userPilotSDKEvents

    override func viewDidLoad() {
        super.viewDidLoad()
        if userPilotSDKEvents.isEmpty {
            emptyContentLabel.isHidden = false
        }
    }
    // MARK: - IBAction

    @IBAction func onBackButtonClicked(_ sender: UIButton) {
        close()
    }

    // MARK: - Track Event

}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension SDKEventsViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userPilotSDKEvents.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let eventTableViewCell: SDKEventTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        eventTableViewCell.selectionStyle = .none
        eventTableViewCell.bindCell(userPilotSDKEvents[indexPath.row])
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

extension SDKEventsViewController {

    static func newInstance() -> SDKEventsViewController {
        return SDKEventsViewController()
    }

}
