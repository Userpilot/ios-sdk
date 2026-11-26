//
//  UIViewController+ExperiencePresentation.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Presents SDK dialog and bottom-sheet controllers over the host screen.
//

import UIKit

// MARK: - Show Dialog view controller

internal extension UIViewController {
    /// Presents a dialog view controller modally.
    /// - Parameter viewController: The DialogViewController to present.
    func presentDialog(viewController: UIViewController) {
        viewController.modalPresentationStyle = .overFullScreen
        present(viewController, animated: false, completion: nil)
    }
}

// MARK: - Show BottomSheet view controller

internal extension UIViewController {

    /// Present a `BottomSheetViewController` modally
    func presentBottomSheet(viewController: UIViewController) {
        viewController.modalPresentationStyle = .overFullScreen
        present(viewController, animated: false, completion: nil)
    }
}
