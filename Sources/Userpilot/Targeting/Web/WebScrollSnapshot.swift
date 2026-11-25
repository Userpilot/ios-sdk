//
//  WebScrollSnapshot.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The page's reply to `WebElementScript.scrollEnd`.
//

import Foundation

internal struct WebScrollSnapshot: Decodable {
    let scrolls: Bool
    let atEnd: Bool

    /// Whether the page's main vertical scroller is at its end, or nil when nothing on the
    /// page scrolls vertically. A missing or unreadable reply counts as not at end, so no
    /// alert is sent rather than a wrong one.
    static func atEnd(from reply: Any?) -> Bool? {
        guard let reply, JSONSerialization.isValidJSONObject(reply),
              let data = try? JSONSerialization.data(withJSONObject: reply),
              let snapshot = try? JSONDecoder().decode(WebScrollSnapshot.self, from: data) else { return false }
        return snapshot.scrolls ? snapshot.atEnd : nil
    }
}
