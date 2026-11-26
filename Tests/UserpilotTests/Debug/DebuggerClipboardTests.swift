//
//  DebuggerClipboardTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Checks that a copied debugger value stays pasteable as plain text.
//

import UIKit
import XCTest
@testable import Userpilot

final class DebuggerClipboardTests: XCTestCase {

    func testACopiedValue_pastesAsPlainText() throws {
        let pasteboard = try XCTUnwrap(UIPasteboard(name: UIPasteboard.Name("userpilot.tests.debugger"), create: true))
        defer { UIPasteboard.remove(withName: pasteboard.name) }

        DebuggerClipboard.copy("app-token-123", to: pasteboard)

        XCTAssertEqual(pasteboard.string, "app-token-123")
        XCTAssertEqual(pasteboard.numberOfItems, 1)
    }
}
