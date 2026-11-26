//
//  BuilderCaptureMode.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Process-wide Builder capture state: whether capture mode is on, which coordinator owns it and which
//  capture ids are spent.
//

import Foundation

/// Process-wide capture state shared by every SDK instance. Only one capture session runs in a process;
/// while it does, no experience shows from any SDK instance.
///
/// Thread safety: `isActive` and `endedCaptureIDs` are atomic and readable from any thread;
/// `ExperiencesPublisher` reads `isActive` on its experience queue and on main. The coordinator that owns
/// the session writes everything on main, and `owner` is read on main only. Nothing is persisted: a killed
/// process forgets all of it.
internal enum BuilderCaptureMode {
    private static let active = AtomicReference(false)
    private static let ended = AtomicReference<Set<String>>([])

    /// True while a capture session runs in any instance. Every instance's publisher then admits and
    /// presents no experience. This is not the publisher's `busy` state, so screen and track events,
    /// including repeat screen events, keep flowing.
    static var isActive: Bool { active.value }

    /// Capture ids whose session ended (Saved or 401, Close, logout). One QR code is one capture,
    /// so a link with one of these ids is refused.
    static var endedCaptureIDs: Set<String> { ended.value }

    /// The coordinator that owns the running session, so another instance's link can stop it. Main only.
    private(set) static var owner: BuilderCaptureCoordinating?

    /// Makes `coordinator` the session owner. The caller stops any other owner's session first.
    static func begin(_ coordinator: BuilderCaptureCoordinating) {
        owner = coordinator
        active.value = true
    }

    /// Ends capture mode if `coordinator` owns it.
    static func end(_ coordinator: BuilderCaptureCoordinating) {
        guard owner === coordinator else { return }
        owner = nil
        active.value = false
    }

    /// One QR code is one capture: `captureID` cannot start capture mode again in this process.
    static func markEnded(_ captureID: String) {
        ended.update { $0.union([captureID]) }
    }

    #if DEBUG
    /// Tests start from a fresh process state.
    static func reset() {
        owner = nil
        active.value = false
        ended.value = []
    }
    #endif
}
