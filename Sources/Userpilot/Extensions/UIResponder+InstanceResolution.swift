//
//  UIResponder+InstanceResolution.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Finds the nearest view controller in a responder chain without loading views.
//

import UIKit

internal extension UIResponder {

    /// Finds the nearest controller, including this responder, without loading views.
    var instanceResolutionViewController: UIViewController? {
        var current: UIResponder? = self
        while let cursor = current {
            if let viewController = cursor as? UIViewController { return viewController }
            current = cursor.next
        }
        return nil
    }
}

/// The retained binding deliberately survives its weak owner. An abandoned subtree
/// remains claimed until detached instead of falling through to another tenant.
internal final class UserpilotOwnerBinding {
    /// Set by the first attachment and never cleared, so resolution skips the responder walk
    /// until an app actually binds UI. Expired bindings keep blocking fallback after that.
    static let hasAttachments = AtomicReference<Bool>(false)

    weak var owner: Userpilot?

    init(owner: Userpilot) {
        self.owner = owner.canonicalInstance
    }
}

private var userpilotOwnerBindingKey: UInt8 = 0

internal extension UIResponder {

    /// Main-thread-only ownership metadata for native views and controllers.
    var userpilotOwnerBinding: UserpilotOwnerBinding? {
        get { objc_getAssociatedObject(self, &userpilotOwnerBindingKey) as? UserpilotOwnerBinding }
        set {
            objc_setAssociatedObject(self, &userpilotOwnerBindingKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Finds the nearest binding, including an expired one. Do not skip expired
    /// bindings: doing so would attribute a removed owner's UI to its parent/default.
    var userpilotOwnerBindingInHierarchy: UserpilotOwnerBinding? {
        var current: UIResponder? = self
        while let cursor = current {
            if let binding = cursor.userpilotOwnerBinding { return binding }
            current = cursor.next
        }
        return nil
    }

    /// Binds this native subtree without retaining the SDK instance or loading UI.
    func attachUserpilotOwner(_ owner: Userpilot) {
        UserpilotOwnerBinding.hasAttachments.value = true
        userpilotOwnerBinding = UserpilotOwnerBinding(owner: owner)
    }

    /// One instance may release only its own binding; a newer owner's claim is preserved.
    /// A binding whose owner is gone can be released by any instance, since its owner never can.
    func detachUserpilotOwner(_ owner: Userpilot) {
        guard let binding = userpilotOwnerBinding,
              binding.owner == nil || binding.owner === owner.canonicalInstance else { return }
        userpilotOwnerBinding = nil
    }
}
