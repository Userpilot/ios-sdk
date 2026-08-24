//
//  DebugEventMapper.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
//

import Foundation

/// Maps analytics / internal SDK payloads into `DebugEvent` instances.
internal protocol DebugEventMapping: AnyObject {
    func fromAnalytics(_ event: Event) -> DebugEvent
    func fromInternal(_ sdkEvent: SDKEvent) -> DebugEvent
}

internal final class DebugEventMapper: DebugEventMapping {

    private let clock: () -> Int64
    private let lock = NSLock()
    private var nextId = 0

    init(clock: @escaping () -> Int64 = {
        Int64(Date().timeIntervalSince1970 * 1000)
    }) {
        self.clock = clock
    }

    init(container: DIContainer) {
        self.clock = { Int64(Date().timeIntervalSince1970 * 1000) }
        _ = container
    }

    func fromAnalytics(_ event: Event) -> DebugEvent {
        DebugEvent(
            id: nextIdentifier(),
            channel: channelFor(event),
            title: titleFor(event),
            typeLabel: typeLabelFor(event),
            timestampMs: clock(),
            properties: flatten(mergedProperties(from: event))
        )
    }

    func fromInternal(_ sdkEvent: SDKEvent) -> DebugEvent {
        DebugEvent(
            id: nextIdentifier(),
            channel: .internalSDK,
            title: sdkEvent.eventName,
            typeLabel: Self.typeInternal,
            timestampMs: clock(),
            properties: flatten(sdkEvent.eventPayload)
        )
    }

    func channelFor(_ event: Event) -> DebugEventChannel {
        switch event.type {
        case .autoCaptureEvent:
            return .autoCapture
        case .screen:
            let source = event.properties?[AutoCaptureConstants.source] as? String
            if source == AutoCaptureConstants.autoCaptureSourceValue {
                return .autoCapture
            }
            return .manual
        case .event, .identify:
            return .manual
        }
    }

    func flatten(_ source: [String: Any]) -> [DebugProperty] {
        guard !source.isEmpty else { return [] }
        return source.keys.sorted().prefix(Self.maxProperties).map { key in
            DebugProperty(key: key, value: stringify(source[key] ?? NSNull()))
        }
    }

    private func titleFor(_ event: Event) -> String {
        switch event.type {
        case .event(let title):
            return title
        case .screen(let title):
            return title
        case .identify(let userId):
            return userId
        case .autoCaptureEvent:
            if let name = event.interactionEventName, !name.isEmpty {
                return name
            }
            if let action = event.properties?[AutoCaptureConstants.targetAction] {
                return String(describing: action)
            }
            return EventType.autoCaptureEvent.eventName
        }
    }

    private func typeLabelFor(_ event: Event) -> String {
        switch event.type {
        case .event:
            return Self.typeTrack
        case .screen:
            return Self.typeScreen
        case .identify:
            return Self.typeIdentify
        case .autoCaptureEvent:
            return Self.typeAutoCapture
        }
    }

    private func mergedProperties(from event: Event) -> [String: Any] {
        var merged: [String: Any] = event.properties ?? [:]
        if let company = event.company {
            merged[Self.companySection] = company
        }
        if let screen = event.screen {
            merged[Self.screenSection] = screen
        }
        if let interaction = event.interactionEventName {
            merged[Self.interactionName] = interaction
        }
        return merged
    }

    private func stringify(_ value: Any) -> String {
        let raw: String
        if value is NSNull {
            raw = Self.nullValue
        } else if let map = value as? [AnyHashable: Any] {
            raw = map.count > Self.maxNestedEntries
                ? "{\(map.count) keys}"
                : String(describing: map)
        } else if let collection = value as? [Any] {
            raw = collection.count > Self.maxNestedEntries
                ? "[\(collection.count) items]"
                : String(describing: collection)
        } else {
            raw = String(describing: value)
        }
        if raw.count > Self.maxValueLength {
            return String(raw.prefix(Self.maxValueLength)) + Self.ellipsis
        }
        return raw
    }

    private func nextIdentifier() -> Int {
        lock.lock()
        nextId += 1
        let value = nextId
        lock.unlock()
        return value
    }

    private static let maxProperties = 80
    private static let maxValueLength = 400
    private static let maxNestedEntries = 20
    private static let companySection = "company"
    private static let screenSection = "screen"
    private static let interactionName = "interaction_event_name"
    private static let typeTrack = "track"
    private static let typeScreen = "screen"
    private static let typeIdentify = "identify"
    private static let typeAutoCapture = "auto_capture"
    private static let typeInternal = "internal"
    private static let nullValue = "null"
    private static let ellipsis = "…"
}
