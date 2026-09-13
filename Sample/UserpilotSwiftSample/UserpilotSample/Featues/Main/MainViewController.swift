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

    internal lazy var content: [Content] = [.configurations, .identify, .screens, .events, .eventsLog, .debug, .autoCapture]

    // MARK: - Override
    override func viewDidLoad() {
        super.viewDidLoad()
        UserpilotManager.shared.settings()
        presentConfigIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("main")
    }

    /// Mirrors Android MainActivity: open Configuration when no app token is saved.
    private func presentConfigIfNeeded() {
        let appToken: String = StorageManager.shared.get(forKey: StorageManager.Keys.appToken) ?? ""
        guard appToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Defer until the navigation stack from SceneDelegate is ready.
        DispatchQueue.main.async { [weak self] in
            self?.openConfigScreen()
        }
    }

    internal func openConfigScreen() {
        // Avoid stacking duplicate config screens if Main already pushed one.
        if FlowRoutingManager.shared.visibleViewController is ConfigViewController {
            return
        }
        FlowRoutingManager.shared.openViewController(ConfigViewController())
    }
}

// MARK: - Instance

extension MainViewController {

    static func newInstance() -> MainViewController {
        return MainViewController()
    }

}
