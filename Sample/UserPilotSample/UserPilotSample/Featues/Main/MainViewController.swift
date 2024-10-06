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

    override func viewDidLoad() {
        super.viewDidLoad()
        // UserPilotManager.shared.identify(userID: "11113")
        UserPilotManager.shared.startPerformanceTest()
    }

}

// MARK: - Instance

extension MainViewController {

    static func newInstance() -> MainViewController {
        return MainViewController()
    }

}
