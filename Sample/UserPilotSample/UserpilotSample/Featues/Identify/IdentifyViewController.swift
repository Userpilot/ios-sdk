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

    @IBOutlet weak var labelAuthorizedUser: PaddedLabel! {
        didSet {
            labelAuthorizedUser.textInsets = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
        }
    }
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

    // MARK: - Override

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("identify")
    }

    // MARK: - IBActions

    @IBAction func onIdentifyButtonClicked(_ sender: UIButton) {
        labelAuthorizedUser.text = "identifing".localized
        labelAuthorizedUser.isHidden = false
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
        labelAuthorizedUser.text = "identifing".localized
        labelAuthorizedUser.isHidden = false
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

    func onUserIdentified(_ user: [String: Any]) {
        labelAuthorizedUser.attributedText = user.formattedJSONLabel()
    }

}

// MARK: - Instance

extension IdentifyViewController {

    static func newInstance() -> IdentifyViewController {
        return IdentifyViewController()
    }

}

extension Dictionary where Key == String, Value == Any {
    func formattedJSONLabel() -> NSAttributedString {
        let attributedText = NSMutableAttributedString()

        let keyAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        ]

        let stringAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemGreen,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ]

        let numberAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemOrange,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ]

        let punctuationAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ]

        func appendFormatted(json: Any, indent: String = "") {
            if let dict = json as? [String: Any] {
                attributedText.append(NSAttributedString(string: "{\n", attributes: punctuationAttributes))
                for (index, key) in dict.keys.enumerated() {
                    attributedText.append(NSAttributedString(string: indent + "  \"\(key)\": ", attributes: keyAttributes))

                    let value = dict[key]

                    // Recursive check
                    if let subDict = value as? [String: Any] {
                        appendFormatted(json: subDict, indent: indent + "  ")
                    } else if let stringValue = value as? String {
                        attributedText.append(NSAttributedString(string: "\"\(stringValue)\"", attributes: stringAttributes))
                    } else if let numberValue = value as? NSNumber {
                        attributedText.append(NSAttributedString(string: "\(numberValue)", attributes: numberAttributes))
                    } else if value is NSNull {
                        attributedText.append(NSAttributedString(string: "null", attributes: punctuationAttributes))
                    } else {
                        attributedText.append(NSAttributedString(string: "\"\(String(describing: value))\"", attributes: stringAttributes))
                    }

                    if index < dict.keys.count - 1 {
                        attributedText.append(NSAttributedString(string: ",", attributes: punctuationAttributes))
                    }

                    // ADD NEW LINE AFTER EACH PROPERTY
                    attributedText.append(NSAttributedString(string: "\n", attributes: punctuationAttributes))
                }
                attributedText.append(NSAttributedString(string: indent + "}", attributes: punctuationAttributes))
            } else {
                // Handle arrays or other values if needed
            }
        }

        appendFormatted(json: self)

        return attributedText
    }
}
