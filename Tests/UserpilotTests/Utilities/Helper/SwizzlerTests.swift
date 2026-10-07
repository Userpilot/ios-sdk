//
//  SwizzlerTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies optional delegate installation and forwarding without changing application delegates.
//

import XCTest
@testable import Userpilot

final class SwizzlerTests: XCTestCase {
    func testHookForwardsToOriginalAndRepeatedInstallationDoesNotUndoIt() {
        let target = ExistingCallbackTarget()
        install(on: target)
        install(on: target)
        XCTAssertEqual(target.callback(), "hook:original")
    }

    func testMissingOptionalCallbackForwardsToPlaceholder() {
        let target = MissingCallbackTarget()
        install(on: target)
        install(on: target)
        let value = target.perform(#selector(ExistingCallbackTarget.callback))?.takeUnretainedValue() as? String
        XCTAssertEqual(value, "hook:placeholder")
    }

    func testMissingSelectorLeavesExistingMethodAlone() {
        XCTAssertFalse(Swizzler.swapInstanceMethods(
            on: ExistingCallbackTarget.self,
            original: #selector(ExistingCallbackTarget.callback),
            swizzled: NSSelectorFromString("unavailableCallback")
        ))
    }

    private func install(on target: NSObject) {
        Swizzler.swizzle(
            targetInstance: target,
            targetSelector: #selector(ExistingCallbackTarget.callback),
            replacementOwner: CallbackHooks.self,
            placeholderSelector: #selector(CallbackHooks.placeholder),
            swizzleSelector: #selector(CallbackHooks.intercepted)
        )
    }
}

private final class ExistingCallbackTarget: NSObject {
    @objc dynamic func callback() -> NSString { "original" }
}

private final class MissingCallbackTarget: NSObject {}

private final class CallbackHooks: NSObject {
    @objc dynamic func placeholder() -> NSString { "placeholder" }
    @objc dynamic func intercepted() -> NSString { "hook:\(intercepted())" as NSString }
}
