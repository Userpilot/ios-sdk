//
//  ConfigurationsDialogViewController.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 03/11/2024.
//

import Foundation
import UIKit

class ConfigurationsDialogViewController: UIViewController {

    // MARK: - IBOutlets

    @IBOutlet weak var textFieldAppToken: UITextField!

    // MARK: - Properties
    private var doneButtonHandler: (() -> Void)?

    // MARK: - Initialization

    public init(doneButtonHandler: (() -> Void)?) {
        super.init(nibName: "ConfigurationsDialogViewController", bundle: nil)
        self.doneButtonHandler = doneButtonHandler
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Actions

    @IBAction func cancelButtonHandler(_ sender: UIButton) {
        self.excuteCancelButton()
    }

    @IBAction func doneButtonHandler(_ sender: UIButton) {
        self.excuteDoneButton()
    }

    // MARK: - Helper methods

    func excuteCancelButton() {
        self.dismiss(animated: true)
    }

    func excuteDoneButton() {
        if !self.isViewLoaded {
            self.executeDoneButtonHandler()
            return
        }

        self.dismiss(animated: true, completion: {
            self.executeDoneButtonHandler()
        })
    }

    func executeDoneButtonHandler() {
        if self.doneButtonHandler != nil,
           let appToken = textFieldAppToken.text, !appToken.isEmpty {
            StorageManager.shared.set(value: appToken, forKey: StorageManager.Keys.appToken)
            self.doneButtonHandler?()
        }
        dismiss(animated: true)
    }

}
