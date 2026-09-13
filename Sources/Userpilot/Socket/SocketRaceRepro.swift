//
//  SocketRaceRepro.swift
//  Userpilot SDK
//
//  QA-only instrumentation for the Phoenix socket lifecycle races reported in
//  Userpilot/ios-sdk#50 and CI-3925. Ported from the 1.0.12 working copy so the same
//  reproduction screen can be pointed at every version before a release.
//
//  Each `hold…WindowIfNeeded()` call sits at the exact point where the unsynchronized
//  version had a window, and parks the calling thread there. Widening a window does not
//  create one: the surrounding code keeps its production shape, so a crash means the
//  serialization this version added is missing or has regressed.
//
//  What each kind targets, and what closed it in this version:
//
//  Crash A — `NSGenericException: Task created in a session that has been invalidated`.
//            A queued connect closure built a WebSocket task on a `URLSession` that a
//            concurrent teardown had already invalidated. Closed by `SocketManager.openSocket()`
//            hopping to main, which is the queue that already serializes Phoenix lifecycle work.
//
//  Crash B — `EXC_BAD_ACCESS` reading `PhoenixTransport.readyState`. A socket-state reader on
//            another queue loaded the transport pointer, teardown freed the object, and the
//            reader then dereferenced it. Closed by `Socket.connection` reading under
//            `connectionLock` and handing the caller its own strong reference.
//
//  Crash C — `objc_loadWeakRetained` on main (CI-3925). `DispatchQueue.main.async { [weak self] }`
//            resolved a weak reference to a transport that was mid-`dealloc`; with the host app's
//            APM instrumentation in play, the `isa` was already freed. Closed by
//            `URLSessionTransport.notifyDelegate` capturing the delegate strongly before the hop,
//            so no weak load happens on main at all.
//
//  Default is disarmed and every hook is a single atomic read, so an un-armed build behaves
//  exactly like a stock build. Arm only from the sample app's "Socket Race Repro" screen.
//
//  ⚠️ This file and its call sites are verification instrumentation. They must not reach a
//  release branch — `SocketRaceRepro`, `SocketRaceKind` and `Userpilot.qa*` are public only so
//  the sample app can drive them, and would otherwise become shipped API.
//

import Foundation

/// Which production crash window to widen.
public enum SocketRaceKind {

    /// Overlap `URLSessionTransport.connect(with:)` with teardown so the WebSocket task is
    /// created on a `URLSession` another queue has already invalidated.
    case crashA

    /// Overlap a socket-state read with teardown so `readyState` is read after the
    /// transport would have been deallocated.
    case crashB

    /// Overlap the transport's main-queue delegate hop with the transport's own `dealloc`.
    case crashC
}

/// Process-wide switch read by the Phoenix stack and driven by the sample app.
public enum SocketRaceRepro {

    /// How long `connect()` holds the freshly created `URLSession` before creating the task.
    public static var connectDelay: TimeInterval = 0.30

    /// How long a socket-state read waits after resolving the transport.
    public static var readyStateDelay: TimeInterval = 0.30

    /// How long the main-queue delegate hop waits before invoking the delegate.
    public static var delegateHopDelay: TimeInterval = 0.30

    private static let armed = AtomicReference<SocketRaceKind?>(nil)

    /// The currently armed crash window, or `nil` when disarmed.
    public static var kind: SocketRaceKind? { armed.value }

    public static var isCrashAArmed: Bool { armed.value == .crashA }
    public static var isCrashBArmed: Bool { armed.value == .crashB }
    public static var isCrashCArmed: Bool { armed.value == .crashC }

    public static func arm(_ kind: SocketRaceKind) {
        armed.value = kind
        print("[SocketRaceRepro] armed \(kind)")
    }

    public static func disarm() {
        armed.value = nil
        print("[SocketRaceRepro] disarmed")
    }

    /// Crash A window: the session exists and the task does not yet. A concurrent teardown
    /// reaching `invalidateAndCancel()` here is what threw `NSGenericException`.
    ///
    /// In this version `connect()` runs on main, so parking here also parks every other
    /// lifecycle call — which is the point: there is no longer another queue to race.
    static func holdCrashAWindowIfNeeded() {
        guard isCrashAArmed, connectDelay > 0 else { return }
        print("[SocketRaceRepro] Crash A window open (\(connectDelay)s) — invalidate the session now")
        Thread.sleep(forTimeInterval: connectDelay)
        print("[SocketRaceRepro] Crash A window closing — creating webSocketTask")
    }

    /// Crash B window: the transport has been resolved and `readyState` not yet read.
    /// A teardown releasing the last other reference here is what freed the object
    /// under the reader.
    static func holdCrashBWindowIfNeeded() {
        guard isCrashBArmed, readyStateDelay > 0 else { return }
        print("[SocketRaceRepro] Crash B window open (\(readyStateDelay)s) — deallocate the transport now")
        Thread.sleep(forTimeInterval: readyStateDelay)
        print("[SocketRaceRepro] Crash B window closing — reading readyState")
    }

    /// Crash C window: main is inside the delegate hop and has not called the delegate yet.
    /// The transport deallocating here is what the pending `[weak self]` load faulted on.
    static func holdCrashCWindowIfNeeded() {
        guard isCrashCArmed, delegateHopDelay > 0 else { return }
        print("[SocketRaceRepro] Crash C window open (\(delegateHopDelay)s) — deallocate the transport now")
        Thread.sleep(forTimeInterval: delegateHopDelay)
        print("[SocketRaceRepro] Crash C window closing — invoking the delegate")
    }
}
