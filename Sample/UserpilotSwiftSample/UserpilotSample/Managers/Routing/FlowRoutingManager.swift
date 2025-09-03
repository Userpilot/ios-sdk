//
//  FlowRoutingManager.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 25/08/2024.
//

/*
 * Main responsiblity to hold one UINavigationController for all UI
 * Used when we have multi storyboard
 * Make all UI routes
 
 * Call SETUP method in first view controller with UINavigationController, entry point for the app
 */
import Foundation
import UIKit

public protocol FlowRoutingManagerProtocol {
    var rootViewController: UIViewController { get }
    var visibleViewController: UIViewController { get }
    func openViewController(_ controller: UIViewController)
    func clearStackInBetween(left: UIViewController, right: UIViewController)
    func clearStackAndShowPushed(_ controllers: [UIViewController])
    func clearLastAndShowPushed(_ controller: UIViewController)
    func jumpBack(to controller: UIViewController?)
    func jumpBack(to controller: UIViewController,
                  andPush next: UIViewController)
    func jumpBackToRoot()
    func replace(viewController: UIViewController,
                 with controller: UIViewController)
    func showModel(_ controller: UIViewController,
                   modelPresentationStyle: UIModalPresentationStyle?,
                   closeHandler: (() -> Void)?)
    func openViewControllerWithPresentStyle(_ controller: UIViewController)
    func hideViewControllerWithPresentStyle()
}

// MARK: - Singlton Instance
private var instance: FlowRoutingManager!

public class FlowRoutingManager {

    // MARK: - Setup
    //    class func setup(navigationController: UINavigationController) -> FlowRoutingManager {
    //        instance = FlowRoutingManager(navigationController: navigationController)
    //        return instance
    //    }

    class func setup(navigationController: UINavigationController) {
        instance = FlowRoutingManager(navigationController: navigationController)
    }

    // MARK: - Initialization
    private init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    // MARK: - Accessors
    class var shared: FlowRoutingManager! {
        if instance == nil {
            print("FlowRoutingManager must called before setup")
        }
        return instance
    }

    // MARK: - properties
    private var navigationController: UINavigationController

    // MARK: - To handle open bottom sheet correctly
    private var tabbarViewController: UIViewController?
    func setBaseTabbarViewController(viewController: UIViewController) {
        tabbarViewController = viewController
    }

    func getBaseTabbarViewController() -> UIViewController? {
        return tabbarViewController
    }
}

extension FlowRoutingManager: FlowRoutingManagerProtocol {
    public var rootViewController: UIViewController {
        return navigationController.viewControllers.first!
    }

    public var visibleViewController: UIViewController {
        return navigationController.visibleViewController ?? navigationController.viewControllers.last!
    }

    public func clearStackInBetween(left: UIViewController, right: UIViewController) {
        let navigationController =
        self.navigationController.visibleViewController?.navigationController ?? self.navigationController
        let currentStack = navigationController.viewControllers
        guard let leftIndex = currentStack.firstIndex(of: left),
              let rightIndex = currentStack.firstIndex(of: right),
              leftIndex < rightIndex
        else { return }
        let newStack = Array(currentStack.prefix(leftIndex + 1)) + [right]
        clearStackAndShowPushed(newStack)
    }

    public func clearStackAndShowPushed(_ controllers: [UIViewController]) {
        if let visibleViewController = navigationController.visibleViewController {
            visibleViewController.navigationController?.setViewControllers(controllers, animated: true)
        } else {
            navigationController.setViewControllers(controllers, animated: false)
        }
    }

    public func openViewController(_ controller: UIViewController) {
        if let visibleViewController = navigationController.visibleViewController {
            visibleViewController.navigationController?.pushViewController(
                controller,
                animated: true
            )
        } else {
            navigationController.pushViewController(controller, animated: true)
        }
    }

    public func clearLastAndShowPushed(_ controller: UIViewController) {
        let navigationController: UINavigationController? = {
            if let visibleViewController = self.navigationController.visibleViewController {
                return visibleViewController.navigationController
            } else {
                return self.navigationController
            }
        }()
        guard let navigationController else { return }

        navigationController.setViewControllers(
            Array(navigationController.viewControllers.dropLast()) +
            [controller], animated: true)
    }

    public func jumpBack(to controller: UIViewController?) {
        if let controller {
            if let topNav = visibleViewController.navigationController,
               topNav.viewControllers.contains(controller) {
                topNav.popToViewController(controller, animated: true)
            } else {
                navigationController.popToViewController(controller, animated: true)
            }
        } else {
            visibleViewController.navigationController?.popViewController(animated: true)
        }
    }

    public func jumpBack(to controller: UIViewController, andPush next: UIViewController) {
        guard let nav = visibleViewController.navigationController,
              let index = nav.viewControllers.firstIndex(of: controller)
        else {
            return
        }
        let stack = Array(nav.viewControllers.dropLast(nav.viewControllers.count - index - 1)) + [next]
        nav.setViewControllers(stack, animated: true)
    }

    public func jumpBackToRoot() {
        let navigationController = visibleViewController.navigationController ?? self.navigationController
        navigationController.popToRootViewController(animated: true)
    }

    public func replace(viewController: UIViewController, with controller: UIViewController) {
        guard
            let navigationController = visibleViewController.navigationController,
            let index = navigationController.viewControllers.firstIndex(of: viewController)
        else {
            return
        }
        navigationController.viewControllers[index] = controller
    }

    public func showModel(
        _ controller: UIViewController,
        modelPresentationStyle: UIModalPresentationStyle?,
        closeHandler: (() -> Void)?
    ) {
        if controller is UINavigationController
            || controller is UIAlertController {
            visibleViewController.present(controller, animated: true)
        } else {
            let navigationController = UINavigationController(rootViewController: controller)
            if let modalPresentationStyle = modelPresentationStyle {
                navigationController.modalPresentationStyle = modalPresentationStyle
            }
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "close",
                style: .done,
                target: nil,
                action: nil
            )
        }
    }

    public func openViewControllerWithPresentStyle(_ viewController: UIViewController) {
        DispatchQueue.main.async {
            let transition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            transition.type = CATransitionType.moveIn
            transition.subtype = CATransitionSubtype.fromTop
            self.navigationController.view.layer.add(transition, forKey: nil)
            self.navigationController.pushViewController(viewController, animated: false)
        }
    }

    public func hideViewControllerWithPresentStyle() {
        let transition: CATransition = CATransition()
        transition.duration = 0.2
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.reveal
        transition.subtype = CATransitionSubtype.fromBottom
        self.navigationController.view.layer.add(transition, forKey: kCATransition)
        self.navigationController.popViewController(animated: false)
    }

    func openScreenAsRoot(viewController: UIViewController, withAnimation animation: Bool = true) {
        navigationController.setViewControllers([viewController], animated: animation)
    }

    func openViewControlerWithFadeAnimation(_ viewController: UIViewController, setAsRoot: Bool = false) {
        let transition = CATransition()
        transition.duration = 0.3
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.fade
        self.navigationController.view.layer.add(transition, forKey: nil)
        self.navigationController.pushViewController(viewController, animated: false)
        if setAsRoot {
            navigationController.setViewControllers([viewController], animated: false)
        }
    }

    func closeViewControllerWitFadeAnimation() {
        let transition: CATransition = CATransition()
        transition.duration = 0.2
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = .fade
        navigationController.view.layer.add(transition, forKey: kCATransition)
        navigationController.popViewController(animated: false)
    }

}

// MARK: - General methods
extension FlowRoutingManager {

    static func openSendSMSViewController(viewController: UIViewController, sms: String) {
        let strURL: String = sms.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        UIApplication.shared.open(URL.init(string: strURL)!, options: [:], completionHandler: nil)
    }

    // MARK: - Helper Method
    // MARK: - Helper Method
    static func topMostController() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.visibleViewController()
        } else {
            guard let viewController = UIViewController.topMostViewController() else { return nil }
            return viewController
        }
    }

    // MARK: - General methods
    static func getWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.windows
            .filter({$0.isKeyWindow}).first
    }

}

extension UIViewController {

    static func topMostViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            let keyWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }

            return keyWindow?.rootViewController?.topMostViewController()
        } else {
            let keyWindow = UIApplication.shared.keyWindow
            return keyWindow?.rootViewController?.topMostViewController()
        }
    }

    func topMostViewController() -> UIViewController? {
        if let navigationController = self as? UINavigationController {
            return navigationController.topViewController?.topMostViewController()
        } else if let tabBarController = self as? UITabBarController {
            if let selectedViewController = tabBarController.selectedViewController {
                return selectedViewController.topMostViewController()
            }
            return tabBarController.topMostViewController()
        } else if let presentedViewController = self.presentedViewController {
            return presentedViewController.topMostViewController()
        } else {
            return self
        }
    }

}

extension FlowRoutingManager {

    func showAlertMessage(_ message: String) {
        guard
            let viewController = FlowRoutingManager.topMostController()
        else { return }
        let alertStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .actionSheet : .alert
        let alert = UIAlertController(title: "Userpilot",
                                      message: message,
                                      preferredStyle: alertStyle)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
        }))
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = viewController.view
            popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                                  y: viewController.view.bounds.midY,
                                                  width: 0,
                                                  height: 0)
        }

        viewController.present(alert, animated: true, completion: nil)
    }

}

extension UIWindow {

    func visibleViewController() -> UIViewController? {
        if let rootViewController: UIViewController = self.rootViewController {
            return UIWindow.getVisibleViewControllerFrom(viewController: rootViewController)
        }
        return nil
    }

    static func getVisibleViewControllerFrom(viewController: UIViewController) -> UIViewController {
        if let navigationController = viewController as? UINavigationController,
           let visibleController = navigationController.visibleViewController {
            return UIWindow.getVisibleViewControllerFrom(viewController: visibleController )
        } else if let tabBarController = viewController as? UITabBarController,
                  let selectedTabController = tabBarController.selectedViewController {
            return UIWindow.getVisibleViewControllerFrom(viewController: selectedTabController )
        } else {
            if let presentedViewController = viewController.presentedViewController {
                return UIWindow.getVisibleViewControllerFrom(viewController: presentedViewController)
            } else {
                return viewController
            }
        }
    }

}
