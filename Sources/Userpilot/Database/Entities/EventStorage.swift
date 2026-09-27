//
//  EventStorage.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 08/10/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Represents an event stored in the local database with all necessary metadata
//  for tracking and syncing with the backend.
//

import Foundation

internal struct EventStorage: Codable {
    let requestId: UUID
    let token: String
    let userId: String
    let data: Data
    /// Timestamp in milliseconds since epoch (Unix timestamp * 1000)
    let createdAt: TimeInterval
    let sizeBytes: Int

    init?(_ event: Event, _ token: String, _ userId: String) {
        self.init(StoredOfflineEvent(event: event), token, userId)
    }

    init?(_ stored: StoredOfflineEvent, _ token: String, _ userId: String) {
        guard let data = try? UserpilotEncoder.shared.encode(stored) else {
            return nil
        }
        self.requestId = UUID()
        self.token = token
        self.userId = userId
        self.data = data
        self.createdAt = Date().timeIntervalSince1970 * 1_000.0
        self.sizeBytes = data.count
    }

    /// Decodes the stored envelope back to a `StoredOfflineEvent`.
    func toStoredEvent() -> StoredOfflineEvent? {
        do {
            return try UserpilotDecoder.shared.decode(StoredOfflineEvent.self, from: data)
        } catch {
            return nil
        }
    }
}
