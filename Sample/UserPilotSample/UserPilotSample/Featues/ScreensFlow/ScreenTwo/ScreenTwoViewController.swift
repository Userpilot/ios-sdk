//
//  ScreenTwoViewController.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 19/08/2024.
//

import Foundation
import UIKit

class ScreenTwoViewController: BaseViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserPilotManager.shared.screen("screen two")
    }

    // MARK: - IBAction

    @IBAction func onBackButtonClicked(_ sender: UIButton) {
        close()
    }

    @IBAction func onNextButtonClicked(_ sender: UIButton) {
        // FlowRoutingManager.shared.openViewController(ScreenTwoViewController.newInstance())
    }

}

// MARK: - Instance

extension ScreenTwoViewController {

    static func newInstance() -> ScreenTwoViewController {
        return ScreenTwoViewController()
    }

}
