//
//  MainViewController.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 19/08/2024.
//

import Foundation
import UIKit

class MainViewController: BaseViewController {

    // MARK: - IBOutlet
    @IBOutlet weak var contentTableView: UITableView! {
        didSet {
            contentTableView.register(UITableViewCell.self, forCellReuseIdentifier: "cellIdentifier")
        }
    }

    // MARK: - Properties
    lazy var content: [Content] = [.identify, .screens, .events]

}

// MARK: - Instance
extension MainViewController {

    static func newInstance() -> MainViewController {
        return MainViewController()
    }

}

extension MainViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellIdentifier", for: indexPath)
        cell.textLabel?.text = content[indexPath.row].title
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        switch content[indexPath.row] {
        case .identify:
            FlowRoutingManager.shared.openViewController(LoginViewController.newInstance())
        case .screens:
            FlowRoutingManager.shared.openViewController(ScreenOneViewController.newInstance())
        case .events:
            FlowRoutingManager.shared.openViewController(EventsViewController.newInstance())
        }
    }

}
