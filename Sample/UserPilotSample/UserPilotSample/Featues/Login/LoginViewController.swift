//
//  LoginViewController.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit
import UserPilot

class LoginViewController: BaseViewController {

    // MARK: - IBOutlet
    @IBOutlet weak var textFieldUserName: UITextField!
    @IBOutlet weak var textFieldPassword: UITextField!
    @IBOutlet weak var loginButton: LoadingButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        UserPilotManager.shared.startPerformanceTest()
    }

    // MARK: - IBActions
    @IBAction func onLoginButtonClicked(_ sender: UIButton) {
        excuteLogin()
    }

    @IBAction func onShowNewsButtonClicked(_ sender: UIButton) {
        UserPilotManager.shared.screen("log in")
    }

    @IBAction func onBackButtonClicked(_ sender: UIButton) {
        close()
    }

}

// MARK: - Helper methods
extension LoginViewController {

    private func excuteLogin() {
        guard let userID = textFieldUserName.text, !userID.isEmpty
        else { return }
        UserPilotManager.shared.identify(userID: userID)
    }

}

// MARK: - Instance
extension LoginViewController {

    static func newInstance() -> LoginViewController {
        return LoginViewController()
    }

}
