//
//  Swizzle.swift
//  Userpilot SDK
//
//  Created by Userpilot on 17/02/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  This utility provides a method-swizzling mechanism used primarily for delegate method interception,
//  such as handling optional UIApplicationDelegate methods (e.g., push token registration).
//  It works by injecting placeholder implementations when necessary and safely replacing original method
//  implementations at runtime, even when those methods are optional and not defined at compile time.
//

import UIKit

internal enum Swizzler {

    /// Exchanges two instance method implementations on the given class.
    /// Returns false when either method cannot be found.
    @discardableResult
    static func swapInstanceMethods(
        on cls: AnyClass,
        original: Selector,
        swizzled: Selector
    ) -> Bool {
        guard
            let originalMethod = class_getInstanceMethod(cls, original),
            let swizzledMethod = class_getInstanceMethod(cls, swizzled)
        else { return false }

        method_exchangeImplementations(originalMethod, swizzledMethod)
        return true
    }

    /// Installs a delegate hook once per concrete class. Optional callbacks receive a placeholder
    /// so the hook can always forward to the original selector after the exchange.
    static func swizzle(
        targetInstance: AnyObject,
        targetSelector: Selector,
        replacementOwner: AnyClass,
        placeholderSelector: Selector,
        swizzleSelector: Selector
    ) {
        let targetClass: AnyClass = type(of: targetInstance)
        let existingMethod = class_getInstanceMethod(targetClass, targetSelector)
        if existingMethod == nil {
            guard let placeholder = class_getInstanceMethod(replacementOwner, placeholderSelector) else { return }
            addMethod(placeholder, on: targetClass, as: targetSelector)
        }

        guard let original = existingMethod ?? class_getInstanceMethod(targetClass, targetSelector),
              let replacement = class_getInstanceMethod(replacementOwner, swizzleSelector),
              method_getImplementation(original) != method_getImplementation(replacement) else { return }

        // Installing the forwarding selector is the existing once-per-class guard. Swapping a second
        // time would undo the hook or recurse; a selector already owned by the class must be left alone.
        guard addMethod(replacement, on: targetClass, as: swizzleSelector),
              let forwarding = class_getInstanceMethod(targetClass, swizzleSelector) else { return }
        method_exchangeImplementations(original, forwarding)
    }

    /// Copies the implementation and its Objective-C type encoding together.
    @discardableResult
    private static func addMethod(_ method: Method, on targetClass: AnyClass, as selector: Selector) -> Bool {
        class_addMethod(targetClass, selector, method_getImplementation(method), method_getTypeEncoding(method))
    }
}
