//
//  DebugUserSnapshotFactory.swift
//  Userpilot
//
//  Copyright © 2026 Userpilot. All rights reserved.
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
        let user = User.fromJson(storage.user)
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
        let propertyRows: [DebugProperty] = {
            let rows = user.properties.keys.sorted().map {
                DebugProperty(key: $0, value: String(describing: user.properties[$0] ?? Self.unset))
            }
            return rows.isEmpty ? [DebugProperty(key: "properties", value: Self.unset)] : rows
        }()
        let companyRows: [DebugProperty] = {
            let rows = user.company.keys.sorted().map {
                DebugProperty(key: $0, value: String(describing: user.company[$0] ?? Self.unset))
            }
            return rows.isEmpty ? [DebugProperty(key: "company", value: Self.unset)] : rows
        }()

        return DebugSnapshot(
            sections: [
                DebugSection(title: Self.sectionIdentity, rows: identityRows),
                DebugSection(title: Self.sectionProperties, rows: propertyRows),
                DebugSection(title: Self.sectionCompany, rows: companyRows)
            ]
        )
    }

    private func format(_ date: Date?) -> String {
        guard let date else { return Self.unset }
        return ISO8601DateFormatter().string(from: date)
    }

    private static let sectionIdentity = "Identity"
    private static let sectionProperties = "Properties"
    private static let sectionCompany = "Company"
    private static let unset = "—"
}
