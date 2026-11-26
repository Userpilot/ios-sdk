//
//  DebugUserSnapshotFactory.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Builds the User tab snapshot from cached storage.
//

import Foundation

/// Builds the User tab snapshot from cached storage.
internal protocol DebugUserSnapshotMaking: AnyObject {
    func create() -> DebugSnapshot
}

internal final class DebugUserSnapshotFactory: DebugUserSnapshotMaking {

    private let storage: DataStoring

    init(storage: DataStoring) {
        self.storage = storage
    }

    init(container: DIContainer) {
        self.storage = container.resolve(DataStoring.self)
    }

    func create() -> DebugSnapshot {
        let identityRows = [
            DebugProperty(key: "user_id", value: storage.userId.isEmpty ? Self.unset : storage.userId),
            DebugProperty(
                key: "anonymous_user_id",
                value: storage.anonymousUserId.isEmpty ? Self.unset : storage.anonymousUserId
            ),
            DebugProperty(key: "session_date", value: format(storage.sessionDate)),
            DebugProperty(key: "configuration_date", value: format(storage.configurationDate)),
            DebugProperty(
                key: "temporary_user",
                value: storage.temporaryUser.flatMap { $0.isEmpty ? nil : $0 } ?? Self.unset
            )
        ]
        return DebugSnapshot(sections: [DebugSection(title: Self.sectionIdentity, rows: identityRows)])
    }

    private func format(_ date: Date?) -> String {
        guard let date else { return Self.unset }
        return ISO8601DateFormatter().string(from: date)
    }

    private static let sectionIdentity = "Identity"
    private static let unset = "—"
}
