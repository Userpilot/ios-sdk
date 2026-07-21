//
//  MainViewController.swift
//  UserpilotSample
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

    internal lazy var content: [Content] = [.identify, .screens, .events, .eventsLog, .autoCapture, .configurations]

    private var didPresentInitialConfig = false

    // MARK: - Override
    override func viewDidLoad() {
        super.viewDidLoad()
        UserpilotManager.shared.settings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("main")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let appToken: String? = StorageManager.shared.get(forKey: StorageManager.Keys.appToken)
        if !didPresentInitialConfig, appToken?.isEmpty ?? true {
            didPresentInitialConfig = true
            openConfigScreen()
        }
    }

    internal func openConfigScreen() {
        FlowRoutingManager.shared.openViewController(ConfigViewController())
    }
}

// MARK: - Instance

extension MainViewController {

    static func newInstance() -> MainViewController {
        return MainViewController()
    }

}
