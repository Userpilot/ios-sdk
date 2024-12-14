//
//  ScreenTwoViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 19/08/2024.
//

import Foundation
import UIKit

class ScreenTwoViewController: BaseViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("screen two")
    }

    // MARK: - IBAction

    @IBAction func onBackButtonClicked(_ sender: UIButton) {
        close()
    }

    @IBAction func onNextButtonClicked(_ sender: UIButton) {
        UserpilotManager.shared.triggerExperience(experienceID: "mobile:5")
    }

}

// MARK: - Instance

extension ScreenTwoViewController {

    static func newInstance() -> ScreenTwoViewController {
        return ScreenTwoViewController()
    }

}
