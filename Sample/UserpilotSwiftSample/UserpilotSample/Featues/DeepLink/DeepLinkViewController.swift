//
//  DeepLinkViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 03/10/2024.
//

import Foundation
import UIKit

class DeepLinkViewController: BaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Movies Gallery"
    }
}

// MARK: - Instance

extension DeepLinkViewController {

    static func newInstance() -> DeepLinkViewController {
        return DeepLinkViewController()
    }

}
