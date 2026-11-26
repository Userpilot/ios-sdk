//
//  TypeNameMemo.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Memoizes derived type names shared by native SwiftUI readers.
//

import UIKit

// MARK: - Type-name memoization

/// Memoizes a value derived from a type's name. Demangling SwiftUI's deeply
/// generic types is the dominant cost of a scan — one `String(describing:)`
/// can build a multi-kilobyte name — and the scan asks for names on every
/// node, view and layer. Metatypes are unique and live for the whole process,
/// so the first stored value is reused for each type; only the derived value
/// (usually a Bool or a short name) is stored, never the full name.
/// Any-thread cache. Derivation runs outside the lock; concurrent misses may compute the
/// same type, but all callers receive the single stored result. Derivation must be pure.
internal final class TypeNameMemo<Value> {

    enum NameSource {
        /// `String(describing:)` — demangled, unqualified.
        case swift
        /// `String(reflecting:)` — demangled, module-qualified.
        case qualified
        /// The Objective-C runtime class name (`NSStringFromClass`). Already
        /// stored on the class, so no demangling — the cheap choice for UIKit
        /// views, controllers and layers. Swift classes report their mangled
        /// name, which still contains each identifier ("…14_UIHostingView…").
        case runtimeClass
    }

    private var values: [ObjectIdentifier: Value] = [:]
    private let lock = NSLock()
    private let source: NameSource
    private let derive: (String) -> Value

    init(_ source: NameSource = .swift, _ derive: @escaping (String) -> Value) {
        self.source = source
        self.derive = derive
    }

    func callAsFunction(_ type: Any.Type) -> Value {
        let key = ObjectIdentifier(type)
        if let cached = lock.withLock({ values[key] }) { return cached }
        let value = derive(name(of: type))
        return lock.withLock {
            // Another caller may have filled this type while its name was being derived.
            if let cached = values[key] { return cached }
            values[key] = value
            return value
        }
    }

    private func name(of type: Any.Type) -> String {
        switch source {
        case .swift:
            return String(describing: type)
        case .qualified:
            return String(reflecting: type)
        case .runtimeClass:
            guard let cls = type as? AnyClass else { return String(describing: type) }
            return NSStringFromClass(cls)
        }
    }
}
