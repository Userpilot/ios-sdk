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

    internal lazy var content: [Content] = [.identify, .screens, .events, .eventsLog, .configurations, .autoCapture, .configurations]

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
        if let appToken: String? = StorageManager.shared.get(forKey: StorageManager.Keys.appToken),
           appToken == nil {
            showConfigurationDialog()
        }
    }

    internal func showConfigurationDialog() {
        DialogManager.shared().showConfigurationDialog { [weak self] in
            guard self != nil else { return }
            self?.showAlertWithAction()
        }
    }

    private func showAlertWithAction() {
        let alert = UIAlertController(
            title: "Confirm",
            message: "Restart the App to take the new configuration",
            preferredStyle: .alert
        )
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            exit(0)
        }
        alert.addAction(okAction)
        present(alert, animated: true)
    }
}

// MARK: - Instance

extension MainViewController {

    static func newInstance() -> MainViewController {
        return MainViewController()
    }

}
