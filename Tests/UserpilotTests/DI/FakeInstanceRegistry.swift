//
//  FakeInstanceRegistry.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  A substitute `InstanceRegistering` for tests, so routing / forwarding logic
//  can be exercised without mutating the process-wide `Userpilot.Registry.shared`.
//

import Foundation
@testable import Userpilot

// swiftlint:disable all

final class FakeInstanceRegistry: InstanceRegistering {

    var defaultInstance: Userpilot?
    var instances: [Userpilot] = []

    var `default`: Userpilot? { defaultInstance }

    var allInstances: [Userpilot] { instances }

    func instance(forToken token: String) -> Userpilot? {
        instances.first { $0.config.token == token }
    }

    func registrationIndex(forToken token: String) -> Int? {
        instances.firstIndex { $0.config.token == token }
    }
}

// swiftlint:enable all
