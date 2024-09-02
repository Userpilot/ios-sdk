//
//  BaseViewController.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit

class BaseViewController: UIViewController {

    func close() {
        self.navigationController?.popViewController(animated: true)
    }
}
