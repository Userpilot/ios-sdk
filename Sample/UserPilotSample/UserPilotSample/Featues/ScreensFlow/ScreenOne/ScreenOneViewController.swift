//
//  ScreenOneViewController.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 19/08/2024.
//

import Foundation
import UIKit

class ScreenOneViewController: BaseViewController {

    @IBAction func onBackButtonClicked(_ sender: UIButton) {
        close()
    }

}

// MARK: - Instance
extension ScreenOneViewController {

    static func newInstance() -> ScreenOneViewController {
        return ScreenOneViewController()
    }

}
