//
//  BaseNavigationController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit

class BaseNavigationController: UINavigationController {

    // Indicates if a UIViewController is currently being pushed onto this navigation controller
    private var duringPushAnimation = false
    private var isSwipeBackeEnabled = true

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        self.delegate = self
        self.interactivePopGestureRecognizer?.delegate = self
        navigationBar.isTranslucent = false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return topViewController?.preferredStatusBarStyle ?? .default
    }

    deinit {
        delegate = nil
        interactivePopGestureRecognizer?.delegate = nil
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        duringPushAnimation = true
        super.pushViewController(viewController, animated: animated)
    }

}

extension BaseNavigationController: UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        (navigationController as? BaseNavigationController)?.duringPushAnimation = false
    }
}

extension BaseNavigationController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == interactivePopGestureRecognizer else {
            return true
        }
        if isSwipeBackeEnabled == false {
            return false
        }
        return viewControllers.count > 1 && self.duringPushAnimation == false
    }
}
