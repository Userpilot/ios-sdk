//
//  DebugFontCatalog.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Lists fonts the host app and system expose without loading font files.
//

import Foundation
import UIKit

/// Lists fonts the host app and system expose without loading font files.
internal protocol DebugFontCataloging {
    func appFontNames() -> [String]
    func systemFontNames() -> [String]
}

internal final class DebugFontCatalog: DebugFontCataloging {

    private let lock = NSLock()
    private var cachedApp: [String]?
    private var cachedSystem: [String]?

    init() {}

    init(container: DIContainer) {
        _ = container
    }

    func appFontNames() -> [String] {
        if let cached = lock.withLock({ cachedApp }) { return cached }
        var names = Set<String>()
        if let fonts = Bundle.main.infoDictionary?["UIAppFonts"] as? [String] {
            for fileName in fonts {
                let stem = (fileName as NSString).deletingPathExtension
                if !stem.isEmpty {
                    names.insert(stem)
                }
            }
        }
        let result = names.sorted()
        lock.withLock { cachedApp = result }
        return result
    }

    func systemFontNames() -> [String] {
        if let cached = lock.withLock({ cachedSystem }) { return cached }
        let result = Array(UIFont.familyNames.sorted().prefix(Self.maxSystemFonts))
        lock.withLock { cachedSystem = result }
        return result
    }

    private static let maxSystemFonts = 80
}
