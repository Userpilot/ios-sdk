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
