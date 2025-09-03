//
//  BaseViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit

class BaseViewController: UIViewController {

    // MARK: - Helper methods
    func close() {
        self.navigationController?.popViewController(animated: true)
    }
}
