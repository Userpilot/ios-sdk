//
//  IdentifyViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit

class IdentifyViewController: BaseViewController {

    // MARK: - IBOutlet

    @IBOutlet weak var textFieldUserID: UITextField! {
        didSet {
            textFieldUserID.delegate = self
        }
    }
    @IBOutlet weak var userPropertiesStackView: UIStackView!
    @IBOutlet weak var companyPropertiesStackView: UIStackView!
    @IBOutlet weak var anonymousButton: UIButton! {
        didSet {
            anonymousButton.layer.borderColor = UIColor.accent.cgColor
            anonymousButton.layer.borderWidth = 1
        }
    }

    internal var userPropertiesViews: [String: PropertyView] = [:]
    internal var companyPropertiesViews: [String: PropertyView] = [:]

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("identify")
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
        showAddCompanyPropertyDialog()
    }

    @IBAction func onLogout(_ sender: UIButton) {
        FlowRoutingManager.shared.showAlertMessage("User logged out successfully!")
        UserpilotManager.shared.logout()
    }

    @IBAction func onAnonymous(_ sender: UIButton) {
        UserpilotManager.shared.anonymous()
    }

}

// MARK: - UITextFieldDelegate

extension IdentifyViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Helper methods

extension IdentifyViewController {

    private func identifyUser() {
        guard
            let userID = textFieldUserID.text, !userID.isEmpty
        else {
            FlowRoutingManager.shared.showAlertMessage("Please insert User ID!")
            return
        }
        var userProperties: [String: String] = [:]
        for (_, propertyView) in userPropertiesViews {
            userProperties[propertyView.getParams().0] = propertyView.getParams().1
        }
        var companyProperties: [String: String] = [:]
        for (_, propertyView) in companyPropertiesViews {
            companyProperties[propertyView.getParams().0] = propertyView.getParams().1
        }
        UserpilotManager.shared.identify(userID: userID, properties: userProperties, company: companyProperties)
    }

}

// MARK: - Instance

extension IdentifyViewController {

    static func newInstance() -> IdentifyViewController {
        return IdentifyViewController()
    }

}
