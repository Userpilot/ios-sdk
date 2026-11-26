//
//  UNUserNotificationCenter+Swizzle.swift
//  Userpilot SDK
//
//  Created by Userpilot on 17/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  The `UserpilotUNUserNotificationCenterDelegate` provides a fallback delegate for
//  UNUserNotificationCenter in case no other delegate is set. This file also includes
//  a swizzled getter for accessing the delegate, enabling interception of push notification
//  events. It ensures Userpilot push notifications are properly handled even when no
//  custom notification delegate is provided in the host app.
//

import UIKit
import UserNotifications

// The notification center holds its delegate weakly. Keep the fallback alive when the host has none.
// swiftlint:disable:next type_name
internal final class UserpilotUNUserNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = UserpilotUNUserNotificationCenterDelegate()
}

internal extension UNUserNotificationCenter {

    static func swizzleNotificationCenterGetDelegate() {
        // Also used temporarily around fallback assignment: this must remain an exchange, not a once gate.
        Swizzler.swapInstanceMethods(
            on: self,
            original: #selector(getter: self.delegate),
            swizzled: #selector(userpilot__getNotificationCenterDelegate)
        )
    }

    /// Reads the current host delegate and installs callbacks on its concrete class. Hooking the
    /// getter lets a replacement host delegate receive hooks when it is subsequently read too.
    @objc
    private func userpilot__getNotificationCenterDelegate() -> UNUserNotificationCenterDelegate? {
        let delegate: UNUserNotificationCenterDelegate

        var shouldSetDelegate = false

        // this call looks recursive, but it is not, it is calling the swapped implementation
        // to get the actual delegate value that has been assigned, if any - can be nil
        if let existingDelegate = userpilot__getNotificationCenterDelegate() {
            delegate = existingDelegate
        } else {
            // if it is nil, then we assign our own delegate implementation so there is
            // something hooked in to listen to notifications
            delegate = UserpilotUNUserNotificationCenterDelegate.shared
            shouldSetDelegate = true
        }

        installNotificationHooks(on: delegate)

        // If we need to set a non-nil implementation where there previously was not one,
        // swap the swizzled getter back first, then assign, then restore the swizzled getter.
        // Assignment can re-enter the getter and recursively assign the fallback while our hook is
        // installed. Preserve both exchanges and their order around the setter to prevent that loop.
        if shouldSetDelegate {
            UNUserNotificationCenter.swizzleNotificationCenterGetDelegate()
            self.delegate = delegate
            UNUserNotificationCenter.swizzleNotificationCenterGetDelegate()
        }

        return delegate
    }

    /// Hook the actual host delegate class, or the fallback class when the host has no delegate.
    private func installNotificationHooks(on delegate: UNUserNotificationCenterDelegate) {
        Swizzler.swizzle(
            targetInstance: delegate,
            targetSelector:
                NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:"),
            replacementOwner: UNUserNotificationCenter.self,
            placeholderSelector:
                #selector(userpilot__placeholderUserNotificationCenterDidReceive),
            swizzleSelector:
                #selector(userpilot__userNotificationCenterDidReceive)
        )

        Swizzler.swizzle(
            targetInstance: delegate,
            targetSelector:
                NSSelectorFromString("userNotificationCenter:willPresentNotification:withCompletionHandler:"),
            replacementOwner: UNUserNotificationCenter.self,
            placeholderSelector:
                #selector(userpilot__placeholderUserNotificationCenterWillPresent),
            swizzleSelector:
                #selector(userpilot__userNotificationCenterWillPresent)
        )
    }

    @objc
    func userpilot__placeholderUserNotificationCenterDidReceive(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Forwarding must still finish the OS callback when the host omitted this optional method.
        completionHandler()
    }

    @objc
    func userpilot__placeholderUserNotificationCenterWillPresent(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // An absent host callback opts out of presentation and still completes the OS request.
        completionHandler([])
    }

    @objc
    func userpilot__userNotificationCenterDidReceive(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if UserpilotNotification(userInfo: response.notification.request.content.userInfo) != nil {
            PushNotificationAutoConfig.didReceive(
                response,
                withCompletionHandler: completionHandler)
        } else {
            // After exchange this selector invokes the original host method or the placeholder.
            // Forward its completion unchanged; the SDK must not complete this branch as well.
            userpilot__userNotificationCenterDidReceive(
                center,
                didReceive: response,
                withCompletionHandler: completionHandler)
        }
    }

    @objc
    func userpilot__userNotificationCenterWillPresent(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if let parsedNotification = UserpilotNotification(userInfo: notification.request.content.userInfo) {
            PushNotificationAutoConfig.willPresent(
                parsedNotification,
                withCompletionHandler: completionHandler)
        } else {
            // The host keeps its presentation decision for notifications outside Userpilot.
            // This selector forwards to the original method after exchange.
            userpilot__userNotificationCenterWillPresent(
                center,
                willPresent: notification,
                withCompletionHandler: completionHandler)
        }
    }
}
