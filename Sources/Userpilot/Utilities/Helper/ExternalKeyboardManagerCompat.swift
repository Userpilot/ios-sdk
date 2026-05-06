//
//  ExternalKeyboardManagerCompat.swift
//  Userpilot
//
//  Created by Motasem Hamed on 23/04/2026.
//

import UIKit

/// Soft-integrates with third-party keyboard managers used by the host app
/// (currently IQKeyboardManager) so they do not collide with Userpilot's own
/// bottom-sheet keyboard handling.
///
/// Uses runtime lookups only — no compile-time dependency on IQKeyboardManager.
/// If the host app does not link IQKeyboardManager, every call is a no-op.
internal enum ExternalKeyboardManagerCompat {

    /// Tell IQKeyboardManager to fully step aside for first responders inside
    /// the given view controller classes. Registers them with every disable-list
    /// we care about — distance handling (root-view / inner scroll-view offset),
    /// the input accessory toolbar, and tap-to-resign handling. Idempotent.
    static func disableIQKeyboardManager(for classes: [UIViewController.Type]) {
        guard let manager = resolveIQKeyboardManager() else { return }

        let keys = [
            "disabledDistanceHandlingClasses",
            "disabledToolbarClasses",
            "disabledTouchResignedClasses"
        ]
        for key in keys {
            guard let existing = manager.value(forKey: key) as? [AnyClass] else { continue }
            let toAdd = classes.filter { cls in !existing.contains(where: { $0 === cls }) }
            if toAdd.isEmpty { continue }
            manager.setValue(existing + toAdd, forKey: key)
        }
    }

    private static func resolveIQKeyboardManager() -> NSObject? {
        // Try module-prefixed Swift names first (v8 ships as IQKeyboardManagerSwift),
        // then the bare Obj-C name for older versions / users who bridged via @objc(...).
        let candidates = [
            "IQKeyboardManagerSwift.IQKeyboardManager",
            "IQKeyboardManager.IQKeyboardManager",
            "IQKeyboardManager"
        ]
        let managerClass: NSObject.Type? = candidates
            .lazy
            .compactMap { NSClassFromString($0) as? NSObject.Type }
            .first
        guard let managerClass else { return nil }

        if let shared = managerClass.value(forKey: "shared") as? NSObject {
            return shared
        }
        let legacySelector = NSSelectorFromString("sharedManager")
        if managerClass.responds(to: legacySelector),
           let unmanaged = managerClass.perform(legacySelector) {
            return unmanaged.takeUnretainedValue() as? NSObject
        }
        return nil
    }
}
