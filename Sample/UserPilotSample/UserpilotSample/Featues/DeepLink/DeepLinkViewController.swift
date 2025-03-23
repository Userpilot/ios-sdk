//
//  DeepLinkViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 03/10/2024.
//

import Foundation
import UIKit

class DeepLinkViewController: UIViewController {

    @IBAction func onBackButtonClicked(_ sender: UIButton) {
        close()
    }
}

// MARK: - Instance

extension DeepLinkViewController {

    static func newInstance() -> DeepLinkViewController {
        return DeepLinkViewController()
    }

}
