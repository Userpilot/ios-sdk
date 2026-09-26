//
//  ScreenOneViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 19/08/2024.
//

import Foundation
import UIKit

class ScreenOneViewController: BaseViewController {

    // MARK: - Override

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Screen One"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("screen one")
    }

    // MARK: - IBAction

    @IBAction func onNextButtonClicked(_ sender: UIButton) {
        FlowRoutingManager.shared.openViewController(ScreenTwoViewController.newInstance())
    }

}

// MARK: - Instance

extension ScreenOneViewController {

    static func newInstance() -> ScreenOneViewController {
        return ScreenOneViewController()
    }

}
