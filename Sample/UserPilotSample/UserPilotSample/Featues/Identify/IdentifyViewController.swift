//
//  IdentifyViewController.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit

class IdentifyViewController: BaseViewController {

    // MARK: - IBOutlet

    @IBOutlet weak var textFieldUserID: UITextField!
    @IBOutlet weak var userPropertiesStackView: UIStackView!
    @IBOutlet weak var companyPropertiesStackView: UIStackView!

    internal var userPropertiesViews: [String: PropertyView] = [:]
    internal var companyPropertiesViews: [String: PropertyView] = [:]

    // MARK: - override

    override func viewDidLoad() {
        super.viewDidLoad()
        UserPilotManager.shared.startPerformanceTest()
    }

    // MARK: - IBActions

    @IBAction func onIdentifyButtonClicked(_ sender: UIButton) {
        identifyUser()
    }

    @IBAction func onBackButtonClicked(_ sender: UIButton) {
        close()
    }

    @IBAction func onAddUserProperty(_ sender: UIButton) {
        showAddUserPropertyDiaog()
    }

    @IBAction func onAddCompanyProperty(_ sender: UIButton) {
        showAddCompanyPropertyDiaog()
    }

}

// MARK: - Helper methods

extension IdentifyViewController {

    private func identifyUser() {
        guard let userID = textFieldUserID.text, !userID.isEmpty
        else { return }
        var userProperties: [String: String] = [:]
        for (_, propertyView) in userPropertiesViews {
            userProperties[propertyView.getParams().0] = propertyView.getParams().1
        }
        var companyProperties: [String: String] = [:]
        for (_, propertyView) in companyPropertiesViews {
            companyProperties[propertyView.getParams().0] = propertyView.getParams().1
        }
        UserPilotManager.shared.identify(userID: userID, properties: userProperties, company: companyProperties)
    }

}

// MARK: - Instance

extension IdentifyViewController {

    static func newInstance() -> IdentifyViewController {
        return IdentifyViewController()
    }

}
