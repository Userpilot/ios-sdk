//
//  AnalyticsPublisherV2.swift
//  Userpilot SDK
//
//  Created on 02/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Registered for AnalyticsPublishing in `Userpilot.initializeContainer()` in place of
//  `AnalyticsPublisher`, which stays in the target as the fallback.
//  One serial queue owns admission, buffers, identity transitions, and ACK progression.
//  See .agents/features/analytics-v2-design.md for preserved behavior and integration limitations.
//

// swiftlint:disable file_length
import Foundation

/// Queue-owned processing with one in-flight operation. Main delivers delegate callbacks,
/// push-token resync, and socket lifecycle calls whose implementation accesses Phoenix state.
/// Ordinary entry points enqueue work; the few synchronous contracts use withQueue.
internal final class AnalyticsPublisherV2: AnalyticsPublishing, SocketSubscription, NetworkMonitoringDelegate {

    private struct Entry {
        let id = UUID()
        let event: Event
    }

    private struct Send {
        let entry: Entry
        let payload: [String: Any]
    }

    /// Waiting for an offline batch and waiting for an analytics ACK both hold the same gate.
    /// Internal SDK pushes have their own consumers and never occupy the analytics ACK slot.
    private enum InFlight {
        case restore(UUID)
        case analytics(Send)
    }

    private enum CloseReason {
        case userSwitch, background, logout
    }

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
    private var pushMonitor: PushNotificationMonitoring? { container?.resolve(PushNotificationMonitoring.self) }

    // A dedicated serial instance; the existing event-queue label does not share queue ownership.
    private let queue = DispatchQueue(label: Constants.DispatchQueues.eventQueue, qos: .userInitiated)
    private let queueKey = DispatchSpecificKey<Bool>()
    private let reads = AtomicReference(ReadState())
    private let throttle = EventThrottle(throttleDuration: 1.0)

    // Only queue accesses these values. No separate atomic busy flag or locked EventQueues.
    private var initial: [Event] = []
    private var pending: [Entry] = []
    private var sdkEvents: [SDKEvent] = []
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
    private func onQueue(_ action: @escaping (AnalyticsPublisherV2) -> Void) {
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

    var canRequestEvent: Bool { socket.isSocketOpened } // SocketManager already locks this getter.
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

    func experiencePublished(_ type: ExperienceType, _ id: Int) {
        withQueue { markSeen(type, id) }
    }

    private func markSeen(_ type: ExperienceType, _ id: Int) {
        if type == .flow {
            screen?.updateSeenFlowExperiences(id)
        } else {
            screen?.updateSeenSurveyExperiences(id)
        }
    }
}

// MARK: - Admission and identity

extension AnalyticsPublisherV2 {

    /// Screen context and active/inactive admission retain their call-time semantics. Accepted
    /// events then join the owner queue, including an event submitted just before backgrounding.
    /// Identify waits for admission so a following push-token call observes the newly selected user.
    func publish(_ event: Event) {
        if let title = event.screenTitle { experiences?.updateScreen(title) }
        guard sessionMonitor?.isAppActive == true else { return }
        if event.isIdentifyEvent {
            withQueue { accept(event) }
        } else {
            onQueue { $0.accept(event) }
        }
    }

    private func accept(_ event: Event) {
        guard let switched = admitIdentity(event) else { return }
        // A new login can arrive before the previous logout's transport finishes closing.
        // Retain its identify and let that existing close reconnect for the selected user.
        if event.isIdentifyEvent, event.userId?.isNotEmpty == true, closing == .logout {
            closing = .userSwitch
        }
        route(event, switchedUser: switched)
    }

    /// nil means duplicate identify. A switch drops all of the previous user's work, like logout,
    /// before adopting the new ID; route() then retains the new identify before transport teardown.
    private func admitIdentity(_ event: Event) -> Bool? {
        guard event.isIdentifyEvent else { return false }
        let matchesStored = storage.user.isNotEmpty && User.fromJson(storage.user).isSameIdentifyEvent(event: event)
        let matchesPending = storage.temporaryUser.map { User.fromJson($0).isSameIdentifyEvent(event: event) } ?? false
        guard !matchesStored, !matchesPending else { return nil }
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
        if event.isScreenEvent, throttle.shouldThrottleScreenEvent(screenTitle: event.screenTitle ?? "") { return }
        if event.isTrackEvent {
            if throttle.shouldThrottle(eventTitle: event.trackEventThrottleKey()) { return }
        }
        pending.append(Entry(event: event))
    }

    private func rejectsAutocapture(_ event: Event) -> Bool {
        guard event.type == .autoCaptureEvent, event.screen?.isEmpty ?? true else { return false }
        logger.error("❗ Event Error, Auto capture event must have screen")
        return true
    }
}

// MARK: - One delivery loop

extension AnalyticsPublisherV2 {

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
        if awaitReply { inFlight = .analytics(Send(entry: entry, payload: payload)) }

        if event.isTrackEvent {
            broadcast(event, value: event.eventTitle, properties: payload)
        }
        socket.publish(event.eventName, payload: payload)
        if event.isScreenEvent {
            if event.isFakeReload == true {
                suppressScreenAutocapture()
            } else {
                broadcast(event, value: event.screenTitle ?? "", properties: nil)
            }
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
            var payload: [String: Any] = [Constants.Analytics.metaDataProperty: event.properties ?? [:]]
            if let company = event.company, !company.isEmpty {
                payload[Constants.Analytics.identifyCompanyProperty] = company
            }
            return payload
        case .screen:
            let changed = setUpScreen(event)
            let allowed = event.isFakeReload != nil || changed || experiences?.canRequestScreenEvent() == true
            guard allowed else { return nil }
            return screenPayload(isFakeReload: event.isFakeReload ?? false)
        case .event, .autoCaptureEvent:
            guard !rejectsAutocapture(event) else { return nil }
            var payload: [String: Any] = [Constants.Analytics.metaDataProperty: event.properties ?? [:]]
            payload[Constants.Analytics.eventNameProperty] = event.type == .autoCaptureEvent
                ? event.interactionEventName : event.eventTitle
            if let screen = event.screen { payload[Constants.Analytics.screenProperty] = screen }
            return payload
        }
    }

    /// SDK replies cannot release an analytics send. Name + original payload filter unrelated
    /// ACKs; identical late sends still need a per-request transport identity before integration.
    func onSocketEventSent(_ name: String, _ payload: Payload, _ message: Message, _ success: Bool) {
        onQueue { publisher in
            guard case .analytics(let sent) = publisher.inFlight,
                  name == sent.entry.event.eventName,
                  NSDictionary(dictionary: sent.payload).isEqual(to: payload ?? [:]),
                  publisher.pending.first?.id == sent.entry.id else { return }
            publisher.pending.removeFirst()
            publisher.inFlight = nil
            if success {
                publisher.didAcknowledge(sent)
            } else {
                publisher.logger.error("⚠️ Event not acknowledged (%{public}@), dropping and continuing queue", name)
            }
            publisher.drain()
        }
    }

    /// Successful identify adopts user properties, notifies listeners, and re-pairs the push token.
    /// An initial/generated screen becomes an ordinary queue entry with its own ACK ownership.
    private func didAcknowledge(_ sent: Send) {
        let event = sent.entry.event
        if event.isIdentifyEvent, event.userId == storage.userId {
            var user = User.fromJson(storage.user)
            storage.user = user.updateUser(event: event).toJson() ?? ""
            logger.info("👤 USER %{public}@", storage.user) // V1 parity for testing; user JSON is PII.
            storage.temporaryUser = nil
            broadcast(event, value: event.userId ?? "", properties: sent.payload)
            if canRequestEvent {
                let userID = storage.userId
                performOn(.main) { [weak self] in
                    guard let self, self.storage.userId == userID else { return }
                    self.pushMonitor?.resyncPushToken()
                }
            }
        }
        if event.isScreenEvent { sessions.markNormal() }
        if sessions.isPostIdentificationContext(event.eventName), pending.isEmpty,
           experiences?.getCurrentScreen.isNotEmpty == true {
            enqueueScreenRefresh(isFakeReload: sessions.getPostIdentificationFakeReloadConfig())
        }
    }
}

// MARK: - Internal SDK events

extension AnalyticsPublisherV2 {

    func publishInternalSDKEvent(_ event: SDKEvent) {
        onQueue { $0.acceptSDKEvent(event) }
    }

    /// Persist eligible SDK events offline; otherwise keep them until replay and any head identify finish.
    private func acceptSDKEvent(_ event: SDKEvent) {
        if offline.shouldSaveOffline, event.isOfflineEligible {
            offline.saveSDKEventToLocalStorage(event)
            return
        }
        sdkEvents.append(event)
        if canRequestEvent {
            drain()
        } else {
            connect()
        }
    }

    private func drainSDKEvents() {
        while canRequestEvent, !sdkEvents.isEmpty {
            let event = sdkEvents.removeFirst()
            socket.publish(event.eventName, payload: event.eventPayload)
        }
    }
}

// MARK: - Screen context and generated refreshes

extension AnalyticsPublisherV2 {

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
            let syncManualScreen = config.isWrapperSDK
                ? !config.isWrapperScreenAutoCaptureEnabled && config.isWrapperInteractionAutoCaptureEnabled
                : !config.enableScreenAutoCapture && config.enableInteractionAutoCapture
            if syncManualScreen {
                screenTracker.updateScreen(
                    with: ScreenTrackingPayload(screenTitle: title, appFramework: config.appFramework)
                )
            }
            experiences?.updateScreen(title)
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

    private func admitReload(_ type: ExperienceType?, _ id: Int?, isFakeReload: Bool) -> Bool {
        guard closing == nil, canRequestEvent, pending.isEmpty, let screen else { return false }
        if let type, let id { markSeen(type, id) }
        guard !throttle.shouldThrottleScreenEvent(screenTitle: screen.event.screenTitle ?? "") else { return false }
        enqueueScreenRefresh(isFakeReload: isFakeReload)
        return true
    }
}

// MARK: - Lifecycle and transport boundaries

extension AnalyticsPublisherV2 {

    /// Retains the existing background policy: only latest identify survives a pending user
    /// switch; otherwise send the remaining queue directly and then close. This path is best effort,
    /// not ACK-driven, and can include the head whose earlier push has not yet resolved.
    func flush() {
        onQueue { publisher in
            let queued = publisher.pending
            publisher.pending.removeAll()
            publisher.inFlight = nil
            let switching = publisher.sessions.isUserSwitching()
            if switching, let identify = queued.last(where: { $0.event.isIdentifyEvent }) {
                publisher.storage.temporaryUser = identify.event.toUser().toJson()
                publisher.pending = [identify]
            } else {
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

    func resume() {
        onQueue { publisher in
            if let date = publisher.storage.sessionDate {
                publisher.storage.sessionDate = nil
                publisher.startSession = Date().timeIntervalSince(date) > Constants.Analytics.sessionDuration
            }
            publisher.connect()
        }
    }

    func reset() {
        onQueue { publisher in
            publisher.startSession = true
            publisher.throttle.clear()
        }
    }

    /// Logout and user switch: drop every unsent live, initial, SDK, and offline event (nothing is
    /// flushed) and reset per-user session, screen, throttle, and experience state. Clearing `inFlight`
    /// also invalidates a pending restore completion; OfflineEventsHandler still owns cancellation of
    /// a batch already decoded for transmission.
    private func dropAllState() {
        pending.removeAll()
        initial.removeAll()
        sdkEvents.removeAll()
        inFlight = nil
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

    private func close(_ reason: CloseReason) {
        let alreadyClosing = closing != nil
        closing = reason
        guard !alreadyClosing else { return }
        performOn(.main) { [weak self] in
            guard let self else { return }
            if self.socket.isShutdownState { return } // Its existing close callback will settle this request.
            if self.socket.isSocketOpened || self.socket.isJoiningSocket {
                self.socket.close()
            } else {
                // No live transport can produce a close notification.
                self.socket.close()
                self.onQueue { $0.didClose(fromError: false) }
            }
        }
    }

    func onSocketOpened() {
        onQueue { publisher in
            guard publisher.closing == nil else { return }
            publisher.drain()
        }
    }

    /// Read the Phoenix error flag on main, then return lifecycle decisions to the owner queue.
    func onSocketClosed() {
        let capture = { [weak self] in
            guard let self else { return }
            let fromError = self.socket.didCloseFromError
            self.onQueue { $0.didClose(fromError: fromError) }
        }
        if Thread.isMainThread {
            capture()
        } else {
            performOn(.main, closure: capture)
        }
    }

    private func didClose(fromError: Bool) {
        let reason = closing
        closing = nil
        inFlight = nil // The retained analytics head is retried after a subsequent open.
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

extension AnalyticsPublisherV2 {

    private func broadcast(_ event: Event, value: String, properties: [String: Any]?) {
        performOn(.main) { [weak self] in
            self?.userpilot?.analyticsDelegate?.didTrack(
                analytic: event.userpilotAnalytic, value: value, properties: properties
            )
        }
    }

    private func suppressScreenAutocapture() {
        guard config.enableScreenAutoCapture, config.appFramework == .SwiftUI else { return }
        performOn(.main) {
            InstanceResolver.shared.suppressScreenAutoCaptureAfterSDKContent()
        }
    }
}

#if DEBUG
extension AnalyticsPublisherV2 {
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
