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
        guard let data = try? UserpilotEncoder.shared.encode(event) else {
            return nil
        }
        self.requestId = UUID()
        self.token = token
        self.userId = userId
        self.data = data
        self.createdAt = Date().timeIntervalSince1970 * 1_000.0
        self.sizeBytes = data.count
    }

    /// Decodes the stored event data back to an Event object
    func toEvent() -> Event? {
        do {
            return try UserpilotDecoder.shared.decode(Event.self, from: data)
        } catch {
            print("❌ Failed to decode Event:", error)
            return nil
        }
    }
}
