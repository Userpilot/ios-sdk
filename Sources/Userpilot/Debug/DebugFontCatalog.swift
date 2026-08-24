//
//  DebugFontCatalog.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
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
        lock.lock()
        if let cachedApp {
            lock.unlock()
            return cachedApp
        }
        lock.unlock()
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
        lock.lock()
        cachedApp = result
        lock.unlock()
        return result
    }

    func systemFontNames() -> [String] {
        lock.lock()
        if let cachedSystem {
            lock.unlock()
            return cachedSystem
        }
        lock.unlock()
        let result = Array(UIFont.familyNames.sorted().prefix(Self.maxSystemFonts))
        lock.lock()
        cachedSystem = result
        lock.unlock()
        return result
    }

    private static let maxSystemFonts = 80
}
