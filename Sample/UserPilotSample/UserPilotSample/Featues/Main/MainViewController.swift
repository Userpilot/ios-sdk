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
    internal lazy var content: [Content] = {
        var content: [Content] = [.identify, .screens, .events]
        if let isInternalRelease = readConfigValue(forKey: "IS_INTERNAL_RELEASE") as? String,
            isInternalRelease == "true" {
            content.append(.configurations)
        }
        return content
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        UserPilotManager.shared.settings()
        /*
        UserPilotManager.shared.identify(
            userID: "112233",
            properties: ["locale_code": Locale.current.languageCode ?? "en"]
        )
         */

        delay(4) {
            UserPilotManager.shared.triggerExperience(token: "mobile:IEebGyacOX")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if
            let isInternalRelease = readConfigValue(forKey: "IS_INTERNAL_RELEASE") as? String,
            isInternalRelease == "true",
            let appToken: String? = StorageManager.shared.get(forKey: StorageManager.Keys.appToken),
            appToken == nil {
            showConfigurationDialog()
        }
    }

    internal func showConfigurationDialog() {
        DialogManager.shared().showConfigurationDialog { [weak self] in
            guard self != nil else { return }
            UserPilotManager.shared.logout()
            UserPilotManager.shared.initialize()
        }
    }
}

// MARK: - Instance

extension MainViewController {

    static func newInstance() -> MainViewController {
        return MainViewController()
    }

}
