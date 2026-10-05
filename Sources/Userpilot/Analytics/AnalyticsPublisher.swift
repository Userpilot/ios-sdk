//
//  AnalyticsPublisher.swift
//  Userpilot SDK
//
//  Created by Userpilot on 02/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Registered for AnalyticsPublishing in `Userpilot.initializeContainer()`.
//  One serial queue owns admission, buffers, identity transitions, and ACK progression.
//  See .agents/features/analytics-v2-design.md for preserved behavior and integration limitations.
//

// swiftlint:disable file_length
import Foundation
import UIKit

/**
 The `AnalyticsPublishing` protocol defines the methods necessary
 to publish analytic events and manage the event lifecycle.
 */
internal protocol AnalyticsPublishing: AnyObject {
    /// Sends an event to the backend.
    func publish(_ event: Event)

    /// Flush any cached events or session data.
    func flush()

    /// Open socket connection.
    func resume()

    /// Reset state
    func reset()

    /// Logout user from socket
    func logout()

    /// check socket state
    var canRequestEvent: Bool { get }

    /// publish experience event
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent)

    /// Keeps the reply and cancellation check with an event while it waits in the SDK queue.
    func publishInternalSDKEvent(
        _ sdkEvent: SDKEvent, shouldSend: @escaping () -> Bool, completion: SocketCompletion?
    )

    /// publish fake reload event
    /// - Returns: true when a screen refresh was accepted into the queue
    @discardableResult
    func publishFakeReloadScreenEvent(
        _ experienceType: ExperienceType?,
        _ experienceId: Int?,
        isFakeReload: Bool
    ) -> Bool

    /// update seen experiences
    func experiencePublished(
        _ experienceType: ExperienceType,
        _ experienceId: Int
    )

    /**
     * Returns whether the experience was already displayed on the current screen session.
     *
     * Flows use `seenExperiences`, Surveys use `seenSurveys`, and NPS returns `false` because NPS
     * is deduplicated by `ExperiencesPublisher` using its last tracked screen. The screen session
     * retains seen ids when the same screen is reported again and starts with empty sets when the
     * screen title changes.
     */
    func isExperienceSeen(_ experienceContent: ExperienceContent) -> Bool

    /// For experience which are come from start session
    var isStartSession: Bool { get }

    /// Current screen-session state.
    var screenSessionStateMachine: ScreenSessionStateMachine? { get }
}

extension AnalyticsPublishing {

    func publishInternalSDKEvent(
        _ sdkEvent: SDKEvent, shouldSend: @escaping () -> Bool = { true }, completion: SocketCompletion? = nil
    ) {
        guard shouldSend() else { return }
        publishInternalSDKEvent(sdkEvent)
    }

    /// Fake reload requested by experience close/dismiss flows.
    @discardableResult
    func publishFakeReloadScreenEvent(
        _ experienceType: ExperienceType?,
        _ experienceId: Int?
    ) -> Bool {
        publishFakeReloadScreenEvent(experienceType, experienceId, isFakeReload: true)
    }
}

/// Queue-owned processing with one in-flight operation. Main delivers delegate callbacks
/// and socket lifecycle calls whose implementation accesses Phoenix state.
/// Ordinary entry points enqueue work; the few synchronous contracts use withQueue.
internal final class AnalyticsPublisher: AnalyticsPublishing, SocketSubscription, NetworkMonitoringDelegate {

    /// One FIFO position; equal event values still occupy distinct entries.
    private struct Entry {
        let id = UUID()
        let event: Event
    }

    /// One transport attempt. Main reads cancellation; completion returns to the publisher's queue.
    private final class Send {
        let entry: Entry
        let payload: [String: Any]
        let isCancelled = AtomicReference(false)

        init(entry: Entry, payload: [String: Any]) {
            self.entry = entry
            self.payload = payload
        }
    }

    /// Waiting for an offline batch and waiting for an analytics ACK both hold the same gate.
    /// Internal SDK pushes have their own consumers and never occupy the analytics ACK slot.
    private enum InFlight {
        case restore(UUID)
        case analytics(Send)
    }

    /// Holds reconnect until the outgoing transport settles; a later identify can update the reason.
    private enum CloseReason {
        case userSwitch, background, logout
    }

    /// Any-thread session queries without exposing queue-owned mutable publisher state.
    private struct ReadState {
        var startSession = true
        var screen: ScreenSessionStateMachine?
    }

    private weak var container: DIContainer?
    private weak var userpilot: Userpilot?
    private let config: Userpilot.Config
    private let logger: Logging
    private let storage: DataStoring
    private let socket: SocketManaging
    private let offline: OfflineEventsHandling
    private let network: NetworkMonitoring
    private let sessions: UserSessionStateManaging
    private let screenTracker: ScreenNameTracking

    // Resolve circular dependencies only after initialization/registration has completed.
    private var experiences: ExperiencesPublishing? { container?.resolve(ExperiencesPublishing.self) }
    private var sessionMonitor: SessionMonitoring? { container?.resolve(SessionMonitoring.self) }

    // A dedicated serial instance; the existing event-queue label does not share queue ownership.
    private let queue = DispatchQueue(label: Constants.DispatchQueues.eventQueue, qos: .userInitiated)
    private let queueKey = DispatchSpecificKey<Bool>()
    private let reads = AtomicReference(ReadState())
    /// Invalidates this user's SDK sends, including those already queued at the socket.
    private let generation = AtomicReference(UUID())
    private let throttle = EventThrottle(throttleDuration: 1.0)

    // Only queue accesses these values. No separate atomic busy flag or locked EventQueues.
    private var initial: [Event] = []
    private var pending: [Entry] = []
    private var sdkEvents: [SDKSend] = []
    private var inFlight: InFlight?
    private var closing: CloseReason?
    private var startSession = true
    private var screen: ScreenSessionStateMachine?

    /// Replaces V1 in the AnalyticsPublishing registration. Never construct both in one
    /// container: both would subscribe to the same socket.
    init(container: DIContainer) {
        let config = container.resolve(Userpilot.Config.self)
        self.container = container
        self.userpilot = container.owner
        self.config = config
        self.logger = config.logger
        self.storage = container.resolve(DataStoring.self)
        self.socket = container.resolve(SocketManaging.self)
        self.offline = container.resolve(OfflineEventsHandling.self)
        self.network = container.resolve(NetworkMonitoring.self)
        self.sessions = container.resolve(UserSessionStateManaging.self)
        self.screenTracker = container.resolve(ScreenNameTracking.self)
        queue.setSpecific(key: queueKey, value: true)

        if let saved = storage.temporaryUser {
            let user = User.fromJson(saved)
            pending.append(Entry(event: Event(
                type: .identify(user.userId), properties: user.properties, company: user.company
            )))
        }
        socket.registerCallback(self)
        network.delegate = self
    }

    // MARK: - Ownership and synchronous queries

    /// External events/callbacks enter once; internal helpers call each other directly on queue.
    private func onQueue(_ action: @escaping (AnalyticsPublisher) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            defer { self.publishReadState() }
            tryCatch { action(self) }
        }
    }

    /// Preserves synchronous identify/reload admission, logout-before-cleanup, and seen read-after-write.
    /// Nested owner calls run inline. Work inside this boundary never synchronously waits for main.
    private func withQueue<T>(_ action: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) == true { return action() }
        return queue.sync {
            defer { publishReadState() }
            return action()
        }
    }

    /// Protects replacement of the screen reference. That object separately serializes its sets.
    private func publishReadState() {
        reads.value = ReadState(startSession: startSession, screen: screen)
    }

    var canRequestEvent: Bool { socket.isSocketOpened } // SocketManaging exposes thread-safe readiness.
    var isStartSession: Bool { reads.value.startSession }
    var screenSessionStateMachine: ScreenSessionStateMachine? { reads.value.screen }

    func isExperienceSeen(_ content: ExperienceContent) -> Bool {
        let screen = reads.value.screen
        switch content {
        case .flow(let flow): return screen?.seenExperiences.contains(flow.id) == true
        case .survey(let survey): return screen?.seenSurveys.contains(survey.id) == true
        case .nps: return false // Once-per-screen NPS suppression belongs to the experience publisher.
        }
    }

    /// Record seen data before returning so a following screen includes those content IDs.
    func experiencePublished(_ type: ExperienceType, _ id: Int) {
        withQueue { screen?.recordExperiencePublished(type, id) }
    }
}

// MARK: - Admission and identity

extension AnalyticsPublisher {

    /// Screen context and active/inactive admission retain their call-time semantics. Accepted
    /// events then join the owner queue, including an event submitted just before backgrounding.
    /// Identify waits for admission so a following push-token call observes the newly selected user.
    func publish(_ event: Event) {
        // Navigation reaches experiences now; analytics screen state advances in FIFO order.
        if event.isScreenEvent, event.isFakeReload == nil { experiences?.updateScreen(event) }
        guard sessionMonitor?.isAppActive == true else { return }
        if event.isIdentifyEvent {
            withQueue { accept(event) }
        } else {
            onQueue { $0.accept(event) }
        }
    }

    /// Select identity before routing; an identify during logout reuses the pending close.
    private func accept(_ event: Event) {
        let switched = admitIdentity(event)
        // A new login can arrive before the previous logout's transport finishes closing.
        // Retain its identify and let that existing close reconnect for the selected user.
        if event.isIdentifyEvent, event.userId?.isNotEmpty == true, closing == .logout {
            closing = .userSwitch
        }
        route(event, switchedUser: switched)
    }

    /// Identify deduplication belongs to the backend. A switch drops the previous user's work
    /// before adopting the new ID; route() then retains the new identify before transport teardown.
    private func admitIdentity(_ event: Event) -> Bool {
        guard event.isIdentifyEvent else { return false }
        storage.temporaryUser = event.toUser().toJson()
        guard let id = event.userId, !id.isEmpty else { return false }
        guard storage.userId.isNotEmpty, storage.userId != id else {
            storage.userId = id
            return false
        }

        sessions.markUserSwitch()
        dropAllState()
        userpilot?.clean()
        storage.userId = id
        return true
    }

    /// Routing decides where an already-admitted event waits. Network recovery by itself never
    /// reconnects or replays; an accepted event, resume, or socket-open callback drives delivery.
    private func route(_ event: Event, switchedUser: Bool = false) {
        if !network.isReady {
            initial.append(event)
            if switchedUser { close(.userSwitch) }
            return
        }
        if offline.shouldSaveOffline {
            if event.isScreenEvent, !setUpScreen(event), experiences?.canRequestScreenEvent() != true { return }
            guard !rejectsAutocapture(event) else { return }
            network.recheckIfOffline()
            offline.saveEventToLocalStorage(event: event)
            if switchedUser { close(.userSwitch) }
            return
        }
        guard closing == nil || closing == .userSwitch else { return }
        enqueue(event)
        if switchedUser { close(.userSwitch); return }
        guard closing == nil else { return }
        if canRequestEvent {
            drain()
        } else {
            connect()
        }
    }

    /// Throttle before retaining a live event. Generated refreshes use their own admission method.
    private func enqueue(_ event: Event) {
        if storage.userId.isEmpty { pending.removeAll() }
        if event.isScreenEvent {
            // Admit once, before retaining. A host resume rejected by the experience cooldown must
            // neither consume the throttle nor stand in for the required dismissal refresh.
            let precedingScreen = pending.last(where: { $0.event.isScreenEvent })?.event ?? screen?.event
            let changed = precedingScreen?.screenTitle != event.screenTitle
            guard event.isFakeReload != nil || changed || experiences?.canRequestScreenEvent() == true else { return }
            guard !throttle.shouldThrottleScreenEvent(screenTitle: event.screenTitle ?? "") else { return }
        }
        if event.isTrackEvent {
            if throttle.shouldThrottle(eventTitle: event.trackEventThrottleKey()) { return }
        }
        pending.append(Entry(event: event))
    }

    /// Reject screenless autocapture in both live and offline routing.
    private func rejectsAutocapture(_ event: Event) -> Bool {
        guard event.type == .autoCaptureEvent, event.screen?.isEmpty ?? true else { return false }
        logger.error("❗ Event Error, Auto capture event must have screen")
        return true
    }
}

// MARK: - One delivery loop

extension AnalyticsPublisher {

    /// Priority: offline batch → head identify → cached SDK events → analytics head.
    /// Sending reserves inFlight before calling the socket. ACKs release it and re-enter here.
    /// An empty queue simply returns: every producer runs on this queue and calls drain().
    private func drain() {
        while inFlight == nil, closing == nil, canRequestEvent {
            if offline.hasCachedEvents {
                let restoreID = UUID()
                inFlight = .restore(restoreID)
                offline.restoreEventsFromLocalStorage { [weak self] in
                    self?.onQueue { publisher in
                        guard case .restore(let activeID) = publisher.inFlight, activeID == restoreID else { return }
                        publisher.inFlight = nil
                        publisher.drain()
                    }
                }
                return
            }

            if pending.first?.event.isIdentifyEvent != true { drainSDKEvents() }
            guard let entry = pending.first else {
                if sessions.getCurrentState() == .backgroundToInitialScreen {
                    sessions.markNormal()
                    if admitReload(nil, nil, isFakeReload: false) { continue }
                }
                return
            }
            if send(entry, awaitReply: true) { return }
            pending.removeFirst() // Invalid/blocked head produced no push and cannot produce an ACK.
        }
    }

    /// Prepares the same payloads as V1. Flush also uses this path, without acquiring an ACK slot.
    private func send(_ entry: Entry, awaitReply: Bool) -> Bool {
        let event = entry.event
        guard let payload = preparePayload(for: event) else { return false }
        let sent = Send(entry: entry, payload: payload)
        if awaitReply { inFlight = .analytics(sent) }

        socket.publish(event.eventName, payload: payload, shouldSend: { !sent.isCancelled.value },
                       completion: { [weak self] _, success in
            if awaitReply { self?.didSend(sent, success: success) }
        })
        if event.isScreenEvent {
            if event.isFakeReload == true {
                suppressScreenAutocapture()
            } else {
                broadcast(event, value: event.screenTitle ?? "", properties: nil)
            }
        } else if event.isTrackEvent {
            broadcast(event, value: event.eventTitle, properties: payload)
        }
        return true
    }

    /// Builds an event's push payload, or nil when it must not be sent. Not pure: identify marks the
    /// session as awaiting its first screen; screens replace the screen session, drain SDK events,
    /// update experience screen context, and settle `startSession`.
    private func preparePayload(for event: Event) -> [String: Any]? {
        switch event.type {
        case .identify:
            guard event.userId != nil else { return nil }
            sessions.markAwaitingInitialScreen()
            return event.identifyPayload()
        case .screen:
            // Admission already reserved this screen's place. Do not reject it again during send.
            setUpScreen(event)
            return screenPayload(isFakeReload: event.isFakeReload ?? false)
        case .event, .autoCaptureEvent:
            guard !rejectsAutocapture(event) else { return nil }
            return event.trackPayload()
        }
    }

    /// The completion captures this attempt; a replaced send cannot release the current head.
    private func didSend(_ sent: Send, success: Bool) {
        onQueue { publisher in
            guard case .analytics(let active) = publisher.inFlight, active === sent,
                  publisher.pending.first?.id == sent.entry.id else { return }
            publisher.pending.removeFirst()
            publisher.inFlight = nil
            if success {
                publisher.didAcknowledge(sent)
            } else {
                publisher.logger.error("⚠️ Event not acknowledged (%{public}@), dropping and continuing queue",
                                       sent.entry.event.eventName)
            }
            publisher.drain()
        }
    }

    /// Successful identify clears its temporary snapshot and notifies listeners.
    /// An initial/generated screen becomes an ordinary queue entry with its own ACK ownership.
    private func didAcknowledge(_ sent: Send) {
        let event = sent.entry.event
        if event.isIdentifyEvent, event.userId == storage.userId {
            storage.temporaryUser = nil
            broadcast(event, value: event.userId ?? "", properties: sent.payload)
        }
        if event.isScreenEvent { sessions.markNormal() }
        if sessions.isPostIdentificationContext(event.eventName), pending.isEmpty,
           experiences?.getCurrentScreen.isNotEmpty == true {
            enqueueScreenRefresh(isFakeReload: sessions.getPostIdentificationFakeReloadConfig())
        }
    }
}

// MARK: - Internal SDK events

extension AnalyticsPublisher {

    func publishInternalSDKEvent(_ event: SDKEvent) {
        publishInternalSDKEvent(event, shouldSend: { true }, completion: nil)
    }

    /// Retain the caller's completion and cancellation, plus this user's generation, through queueing.
    func publishInternalSDKEvent(
        _ event: SDKEvent, shouldSend: @escaping () -> Bool, completion: SocketCompletion?
    ) {
        let expectedGeneration = generation.value
        let send = SDKSend(event: event, shouldSend: { [weak self] in
            self?.generation.value == expectedGeneration && shouldSend()
        }, completion: completion)
        onQueue { $0.acceptSDKEvent(send) }
    }

    /// Persist eligible SDK events offline; otherwise retain their completion until submission.
    private func acceptSDKEvent(_ send: SDKSend) {
        guard storage.userId.isNotEmpty, closing != .logout, send.shouldSend() else { return }
        if offline.shouldSaveOffline, send.event.isOfflineEligible {
            offline.saveSDKEventToLocalStorage(send.event)
            return
        }
        sdkEvents.append(send)
        if canRequestEvent {
            drain()
        } else {
            connect()
        }
    }

    /// Submit cached SDK events while joined; their completions do not occupy the analytics ACK slot.
    private func drainSDKEvents() {
        while canRequestEvent, !sdkEvents.isEmpty {
            let send = sdkEvents.removeFirst()
            socket.publish(send.event.eventName, payload: send.event.eventPayload,
                           shouldSend: send.shouldSend, completion: send.completion)
        }
    }
}

// MARK: - Screen context and generated refreshes

extension AnalyticsPublisher {

    /// Same title retains seen IDs; a new title starts empty sets. The owner queue also protects
    /// replacement of the ScreenSessionStateMachine reference, not just its internal sets.
    @discardableResult
    private func setUpScreen(_ event: Event) -> Bool {
        let changed = screen?.event.screenTitle != event.screenTitle
        if screen != nil, canRequestEvent, changed { startSession = false }
        screen = ScreenSessionStateMachine(
            event: event,
            seenExperiences: changed ? [] : (screen?.seenExperiences ?? []),
            seenSurveys: changed ? [] : (screen?.seenSurveys ?? [])
        )
        publishReadState()
        return changed
    }

    /// Mirrors screen metadata, manual-screen interaction context, and post-identify session flags.
    private func screenPayload(isFakeReload: Bool) -> [String: Any]? {
        ensureScreen()
        guard let screen else { return nil }
        drainSDKEvents() // Seen/completed/dismissed SDK events precede content re-evaluation.
        let event = screen.event
        if let title = event.screenTitle {
            if config.shouldSyncManualScreenForInteractionPayload() {
                screenTracker.updateScreen(
                    with: ScreenTrackingPayload(screenTitle: title, appFramework: config.appFramework)
                )
            }
        }
        startSession = sessions.getPostIdentificationStartSessionConfig(currentStartSession: startSession)
        publishReadState()
        let metadata: [String: Any] = [
            Constants.Analytics.isSessionStartedProperty: startSession,
            Constants.Analytics.fakeReload: isFakeReload,
            Constants.Analytics.seenContents: Array(screen.seenExperiences),
            Constants.Analytics.seenSurveys: Array(screen.seenSurveys)
        ]
        return [
            Constants.Analytics.screenTitleProperty: event.screenTitle ?? "",
            Constants.Analytics.metaDataProperty: (event.properties ?? [:]).merging(metadata) { _, new in new }
        ]
    }

    /// A returning user can have a tracked screen even when no screen session exists yet.
    private func ensureScreen() {
        guard screen == nil, storage.userId.isNotEmpty,
              let title = experiences?.getCurrentScreen, !title.isEmpty else { return }
        screen = ScreenSessionStateMachine(event: Event(type: .screen(title)))
        publishReadState()
    }

    /// Append the current screen snapshot; it waits for the same FIFO turn and ACK as user analytics.
    private func enqueueScreenRefresh(isFakeReload: Bool) {
        ensureScreen()
        guard var event = screen?.event else { return }
        event.isFakeReload = isFakeReload
        pending.append(Entry(event: event))
    }

    /// The Bool retains its existing meaning: true only after actual queue admission, including
    /// while an offline restore owns delivery. A snapshot followed by async enqueue cannot promise this.
    @discardableResult
    func publishFakeReloadScreenEvent(_ type: ExperienceType?, _ id: Int?, isFakeReload: Bool) -> Bool {
        withQueue {
            let accepted = admitReload(type, id, isFakeReload: isFakeReload)
            if accepted { drain() }
            return accepted
        }
    }

    /// A fake reload needs no queued screen and refreshes the throttle to suppress host resume screens.
    /// An existing throttle window cannot reject it; ordinary reloads retain their queue/throttle checks.
    private func admitReload(_ type: ExperienceType?, _ id: Int?, isFakeReload: Bool) -> Bool {
        guard closing == nil, canRequestEvent, let screen else { return false }
        if let type, let id { screen.recordExperiencePublished(type, id) }
        let title = screen.event.screenTitle ?? ""
        if isFakeReload {
            // A queued screen already asks for content. Other events retain FIFO ahead of this refresh.
            guard !pending.contains(where: { $0.event.isScreenEvent }) else { return false }
            throttle.recordScreenEvent(screenTitle: title)
        } else {
            guard pending.isEmpty, !throttle.shouldThrottleScreenEvent(screenTitle: title) else { return false }
        }
        enqueueScreenRefresh(isFakeReload: isFakeReload)
        return true
    }
}

// MARK: - Lifecycle and transport boundaries

extension AnalyticsPublisher {

    /// Retains the existing background policy: only latest identify survives a pending user
    /// switch; otherwise send the remaining queue directly and then close. This path is best effort,
    /// not ACK-driven, and can include the head whose earlier push has not yet resolved.
    func flush() {
        onQueue { publisher in
            let queued = publisher.pending
            publisher.pending.removeAll()
            publisher.cancelInFlight()
            let switching = publisher.sessions.isUserSwitching()
            if switching, let identify = queued.last(where: { $0.event.isIdentifyEvent }) {
                publisher.storage.temporaryUser = identify.event.toUser().toJson()
                publisher.pending = [identify]
            } else if publisher.canRequestEvent {
                queued.forEach { _ = publisher.send($0, awaitReply: false) }
            }
            publisher.close(.background)
            if !switching { publisher.sessions.markUserBackFromBackground() }
        }
    }

    /// Synchronous because Userpilot.logout() clears userId/pushToken as soon as this returns.
    /// The logout event is pushed directly, ahead of the close; every other unsent event is dropped.
    func logout() {
        withQueue {
            if canRequestEvent, let token = storage.pushToken {
                let event = UserLogoutEvent(appToken: config.token, userId: storage.userId, token: token)
                socket.publish(event.eventName, payload: event.eventPayload)
            }
            dropAllState()
            storage.temporaryUser = nil
            close(.logout)
        }
    }

    /// Recompute session-start after backgrounding, then request a reconnect unless closing.
    func resume() {
        onQueue { publisher in
            if let date = publisher.storage.sessionDate {
                publisher.storage.sessionDate = nil
                publisher.startSession = Date().timeIntervalSince(date) > Constants.Analytics.sessionDuration
            }
            publisher.connect()
        }
    }

    /// Reset session-start and throttle state without discarding queued events.
    func reset() {
        onQueue { publisher in
            publisher.startSession = true
            publisher.throttle.clear()
        }
    }

    /// Logout and user switch: drop every unsent live, initial, SDK, and offline event (nothing is
    /// flushed) and invalidate restore, request, and experience callbacks from that user.
    private func dropAllState() {
        generation.value = UUID()
        cancelInFlight()
        pending.removeAll()
        initial.removeAll()
        sdkEvents.removeAll()
        offline.clearLocalEvents()
        throttle.clear()
        startSession = true
        screen?.resetState()
        experiences?.logout()
    }

    /// SocketManager performs its own connection gating. Calling it on main keeps its Phoenix
    /// lifecycle reads on the same thread as transport creation and teardown.
    private func connect() {
        guard closing == nil, storage.userId.isNotEmpty else { return }
        performOn(.main) { [weak self] in self?.socket.connect() }
    }

    /// Submit one teardown; later calls update its reason and share the same completion.
    private func close(_ reason: CloseReason) {
        let alreadyClosing = closing != nil
        closing = reason
        guard !alreadyClosing else { return }
        socket.close { [weak self] in
            self?.onQueue { $0.didClose(fromError: false) }
        }
    }

    /// Invalidate a send attempt without removing its retained analytics entry.
    private func cancelInFlight() {
        if case .analytics(let sent) = inFlight { sent.isCancelled.value = true }
        offline.cancelRestore()
        inFlight = nil
    }

    /// Resume delivery after join unless a close has already been requested.
    func onSocketOpened() {
        onQueue { publisher in
            guard publisher.closing == nil else { return }
            publisher.drain()
        }
    }

    /// Read the Phoenix error flag on main, then return lifecycle decisions to the owner queue.
    func onSocketClosed() {
        performOnMain { [weak self] in
            guard let self else { return }
            let fromError = self.socket.didCloseFromError
            self.onQueue { publisher in
                // Explicit close settles through its completion, even if no transport existed.
                guard publisher.closing == nil else { return }
                publisher.didClose(fromError: fromError)
            }
        }
    }

    /// Release in-flight ownership but retain the head; errors await another event/resume to reconnect.
    private func didClose(fromError: Bool) {
        let reason = closing
        closing = nil
        cancelInFlight() // The retained analytics head is retried after a subsequent open.
        guard sessionMonitor?.isAppActive == true else { return }
        guard reason == .userSwitch || !fromError else { return }
        // If foreground resumed during background teardown, connect even with an empty queue
        // so the existing background-to-screen session state can produce its refresh.
        if !pending.isEmpty || reason == .background { connect() }
    }

    /// Only re-route work held for the first readiness result. Recovery alone does not reconnect.
    func networkMonitorDidUpdate(isReady: Bool, isNetworkAvailable: Bool) {
        guard isReady else { return }
        onQueue { publisher in
            let events = publisher.initial
            publisher.initial.removeAll()
            for event in events where publisher.sessionMonitor?.isAppActive == true {
                publisher.route(event)
            }
        }
    }
}

// MARK: - Main-thread effects

extension AnalyticsPublisher {

    /// Deliver host analytics callbacks on main, outside the publisher's owner queue.
    private func broadcast(_ event: Event, value: String, properties: [String: Any]?) {
        performOn(.main) { [weak self] in
            self?.userpilot?.analyticsDelegate?.didTrack(
                analytic: event.userpilotAnalytic, value: value, properties: properties
            )
        }
    }

    /// Prevent SwiftUI reappearance after SDK content from duplicating the generated screen refresh.
    private func suppressScreenAutocapture() {
        guard config.enableScreenAutoCapture, config.appFramework == .SwiftUI else { return }
        performOn(.main) {
            InstanceResolver.shared.suppressScreenAutoCaptureAfterSDKContent()
        }
    }
}

#if DEBUG
extension AnalyticsPublisher {
    /// Returns once all work already on the queue has run, so tests can assert after async entry points.
    func mockWaitForQueue() {
        withQueue {}
    }

    func mockGetEventsToFlush() -> [Event] {
        withQueue { pending.map(\.event) }
    }

    func mockGetInitialQueue() -> [Event] {
        withQueue { initial }
    }
}
#endif
// swiftlint:enable file_length
