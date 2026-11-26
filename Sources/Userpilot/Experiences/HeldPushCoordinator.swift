//
//  HeldPushCoordinator.swift
//  Userpilot SDK
//
//  Created by Userpilot on 22/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owned by ExperiencesPublisher: the one slot for a server push that arrived while an operation was active.
//

import Foundation

/// Keeps the latest server push that arrived while an operation was active. A fake reload can't fetch it again,
/// so it starts where the ending operation's reload would have gone, and that reload goes out when it ends.
/// Screen change, logout, QR preview, Builder capture and a completion deep link drop it through `clear()`.
///
/// Confined to the publisher's experience queue like the rest of its orchestration state: every call runs
/// there, and `start` and `publishFakeReload` are called back synchronously on it.
internal final class HeldPushCoordinator {

    private let logger: Logging
    /// Admits `experience` as an operation that owes `owedReload`; false when admission refuses it.
    private let start: (_ experience: ExperienceContent, _ owedReload: Bool) -> Bool
    private let publishFakeReload: () -> Void

    private var push: ExperienceContent?

    init(
        logger: Logging,
        start: @escaping (_ experience: ExperienceContent, _ owedReload: Bool) -> Bool,
        publishFakeReload: @escaping () -> Void
    ) {
        self.logger = logger
        self.start = start
        self.publishFakeReload = publishFakeReload
    }

    /// Decoded content only; it replaces an older held push.
    func hold(_ experience: ExperienceContent) {
        push = experience
        logger.info("⏳ Server push held until the current experience ends")
    }

    /// Called once the active operation released ownership: starts the held push in place of the fake reload,
    /// handing it `owesReload`; otherwise publishes that reload when it is owed.
    func onOperationFinished(owesReload: Bool) {
        if startHeldPush(owedReload: owesReload) || !owesReload { return }
        publishFakeReload()
    }

    func clear() {
        push = nil
    }

    /// Hands the held push to `start`; it is consumed whether or not admission takes it.
    private func startHeldPush(owedReload: Bool) -> Bool {
        guard let experience = push else { return false }
        push = nil
        return start(experience, owedReload)
    }
}
