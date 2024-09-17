//
//  AddPropertyDialogViewController.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 15/09/2024.
//

import Foundation
import UIKit

class AddPropertyDialogViewController: UIViewController {

    // MARK: - IBOutlets

    @IBOutlet weak var propertyTitle: UITextField!
    @IBOutlet weak var propertyValue: UITextField!

    // MARK: - Properties

    private var propertyTitleData: String?
    private var propertyValueData: String?
    private var doneButtonHandler: ((String, String) -> Void)?

    // MARK: - Initialization

    public init(propertyTitle: String, propertyValue: String, doneButtonHandler: ((String, String) -> Void)?) {
        super.init(nibName: "AddPropertyDialogViewController", bundle: nil)

        self.propertyTitleData = propertyTitle
        self.propertyValueData = propertyValue
        self.doneButtonHandler = doneButtonHandler
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Override

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.propertyTitle.text = propertyTitleData
        self.propertyValue.text = propertyValueData
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
           let propertyTitle = propertyTitle.text, !propertyTitle.isEmpty,
           let propertyValue = propertyValue.text, !propertyValue.isEmpty {
            self.doneButtonHandler!(propertyTitle, propertyValue)
        }
        dismiss(animated: true)
    }

}
