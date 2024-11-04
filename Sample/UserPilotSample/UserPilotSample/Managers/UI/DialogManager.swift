//
//  DialogManager.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 15/09/2024.
//

import Foundation
import UIKit

class DialogManager {

    // MARK: - Initialization
    static let instance: DialogManager = {
        let instance = DialogManager()
        // setup code
        return instance
    }()

    // MARK: - Accessors
    class func shared() -> DialogManager {
        return instance
    }

    // MARK: - Initialization
    private init() {
    }

    // MARK: - Alert Dialog
    func showAPIAlertDialog(propertyTitle: String,
                            propertyValue: String,
                            doneButtonHandler: ((String, String) -> Void)?) {

        let dialog = AddPropertyDialogViewController(
            propertyTitle: propertyTitle,
            propertyValue: propertyValue,
            doneButtonHandler: doneButtonHandler)

        dialog.modalPresentationStyle = .overCurrentContext
        dialog.modalTransitionStyle = .crossDissolve

        if let topMostController = FlowRoutingManager.topMostController() {
            if !topMostController.isKind(of: AddPropertyDialogViewController.self) {
                topMostController.present(dialog, animated: false, completion: nil)
            }
        }
    }

    // MARK: - Configuration Dialog
    func showConfigurationDialog(doneButtonHandler: (() -> Void)?) {

        let dialog = ConfigurationsDialogViewController(
            doneButtonHandler: doneButtonHandler)

        dialog.modalPresentationStyle = .overCurrentContext
        dialog.modalTransitionStyle = .crossDissolve

        if let topMostController = FlowRoutingManager.topMostController() {
            if !topMostController.isKind(of: ConfigurationsDialogViewController.self) {
                topMostController.present(dialog, animated: false, completion: nil)
            }
        }
    }
}
