//
//  SwizzlerTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 06/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies optional delegate installation and forwarding without changing application delegates,
//  including delegates that inherit the callback from a shared base class.
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

    /// Exchanging the inherited method would hook the base for every sibling, which has no forwarding selector.
    func testHookingTwoSubclassesOfABase_leavesTheBaseAndEachSiblingWorking() {
        let first = FirstSiblingTarget()
        let second = SecondSiblingTarget()

        install(on: first)
        install(on: second)

        XCTAssertEqual(first.callback(), "hook:base")
        XCTAssertEqual(second.callback(), "hook:base")
        XCTAssertEqual(SiblingBaseTarget().callback(), "base")
    }

    func testHookingTheBaseAfterASubclass_runsEachHookOnce() {
        let subclass = OrderedSubclassTarget()
        let base = OrderedBaseTarget()

        install(on: subclass)
        install(on: base)
        install(on: OrderedOtherSubclassTarget())

        XCTAssertEqual(subclass.callback(), "hook:base")
        XCTAssertEqual(base.callback(), "hook:base")
        XCTAssertEqual(OrderedOtherSubclassTarget().callback(), "hook:base")
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

// Each test hooks its own classes: a swizzle lasts for the whole test process.

private class SiblingBaseTarget: NSObject {
    @objc dynamic func callback() -> NSString { "base" }
}

private final class FirstSiblingTarget: SiblingBaseTarget {}

private final class SecondSiblingTarget: SiblingBaseTarget {}

private class OrderedBaseTarget: NSObject {
    @objc dynamic func callback() -> NSString { "base" }
}

private final class OrderedSubclassTarget: OrderedBaseTarget {}

private final class OrderedOtherSubclassTarget: OrderedBaseTarget {}

private final class CallbackHooks: NSObject {
    @objc dynamic func placeholder() -> NSString { "placeholder" }
    @objc dynamic func intercepted() -> NSString { "hook:\(intercepted())" as NSString }
}
