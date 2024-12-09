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
    internal lazy var content: [Content] = [.identify, .screens, .events, .configurations, .eventsLog]

    override func viewDidLoad() {
        super.viewDidLoad()
        UserpilotManager.shared.settings()
        /*
        UserpilotManager.shared.identify(
            userID: "112233",
            properties: ["locale_code": Locale.current.languageCode ?? "en"]
        )
         */

        delay(4) {
            UserpilotManager.shared.testesz()
        }
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
            UserpilotManager.shared.destroy()
            UserpilotManager.shared.initialize()
        }
    }
}

// MARK: - Instance

extension MainViewController {

    static func newInstance() -> MainViewController {
        return MainViewController()
    }

}
