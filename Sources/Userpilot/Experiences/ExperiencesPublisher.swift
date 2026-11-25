//
//  ExperiencesPublisher.swift
//  Userpilot SDK
//
//  Created by Userpilot on 02/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Registered for ExperiencesPublishing in `Userpilot.initializeContainer()`.
//  Coordinates when backend-selected experiences (flows, surveys, NPS) may use the UI. One operation
//  owns the UI from acceptance to final dismissal; any other experience arriving meanwhile is dropped,
//  except a server push: the latest one waits in `HeldPushCoordinator` and starts when the operation finishes.
//  Only a QR preview interrupts it: it cancels preparation or dismisses the UI, then takes over.
//  While Builder capture mode is on in any instance, nothing is admitted or presented.
//

// swiftlint:disable file_length
import Foundation
import UIKit

/*
 The `ExperiencesPublishing` protocol defines the required methods for managing experiences,
 such as starting the service, retrieving active carousel experience, and sending socket requests.
 */
internal protocol ExperiencesPublishing: AnyObject {

    /// Manually trigger experience
    func triggerExperience(_ experienceId: String)

    /// Preview experience
    func triggerPreviewExperience(_ experienceId: String, _ queryItems: [URLQueryItem])

    /// Updates the current screen used for experience targeting
    func updateScreen(_ screenName: String)

    /// Reports an app screen immediately, independently of analytics delivery.
    @discardableResult
    func updateScreen(_ event: Event) -> UUID?

    /// Original latest native event, including local visit correlation for generated requests.
    var currentScreenEvent: Event? { get }

    /// Opt-in responses arrive through the originating analytics send, retaining its visit identity.
    func receiveScreenResponse(_ payload: Payload, _ message: Message, success: Bool, visitID: UUID?)

    /// The current screen used for experience targeting
    var getCurrentScreen: String { get }

    /// The host app's close (`manualClose: true`): a seen experience is dismissed with its state, then the
    /// screen reloads.
    func endExperience(manualClose: Bool)

    /// Whether an operation has handed a renderer to UIKit, including dismissal.
    var isExperienceVisible: Bool { get }

    /// Completes on main after the current operation has released its renderer.
    func endExperience(manualClose: Bool, completion: (() -> Void)?)

    /// The SDK-driven close Builder capture uses, the same one as navigation, logout and QR preview: no
    /// dismissal, host callback, step event or fake reload, and any held push is dropped. `completion` runs on
    /// main after the current operation has released its renderer.
    func closeSilently(completion: (() -> Void)?)

    /// True when idle and outside the cooldown for a repeat host screen event.
    func canRequestScreenEvent() -> Bool

    /// Records the selected completion link; navigation waits for final native dismissal.
    func setCompletionDeepLink(_ deepLink: String?, rendererID: UUID?)

    /// Invalidates callbacks and closes current experience without requesting a screen refresh.
    func logout()

    /// Renderers capture this identity at construction and return it with every callback.
    var activeRendererID: UUID? { get }

    /// The renderer's experience; nil for any renderer other than the current presentation.
    func getActiveExperience(rendererID: UUID?) -> ExperienceContent?

    /// True while the renderer's running flow still owes a step, so its experience is not finished.
    func hasNextFlowStep(rendererID: UUID?) -> Bool

    /// Sends the renderer's experience event to the backend.
    func publishInternalSDKEvent(_ sdkEvent: ExperienceEvent, rendererID: UUID?)

    /// Notifies that the renderer's view finished dismissing.
    func experienceDidFinishDismissing(rendererID: UUID?)

    /// Shows the renderer's survey thank-you message.
    func showThankYouMessage(
        _ survey: SurveyContent, _ theme: SurveyTheme, _ submissionId: Int64, rendererID: UUID?
    )

    /// Keeps a Flow step outcome's run on the renderer's operation, then publishes its events in order.
    /// Renderers call it when the user's action is committed, before any fade.
    func publishFlowStepOutcome(_ outcome: FlowStepOutcome, rendererID: UUID?)

}

/// Default overloads preserve the basic contract for service substitutes.
extension ExperiencesPublishing {
    var isExperienceVisible: Bool { activeRendererID != nil }
    func endExperience(manualClose: Bool, completion: (() -> Void)?) {
        endExperience(manualClose: manualClose)
        completion?()
    }

    func closeSilently(completion: (() -> Void)?) {
        endExperience(manualClose: false, completion: completion)
    }

    var currentScreenEvent: Event? { nil }

    func receiveScreenResponse(_ payload: Payload, _ message: Message, success: Bool, visitID: UUID?) {}

    @discardableResult
    func updateScreen(_ event: Event) -> UUID? {
        guard event.isFakeReload == nil, let screenName = event.screenTitle else { return nil }
        updateScreen(screenName)
        return nil
    }

    var activeRendererID: UUID? { nil }
}

/// Owns experience admission, preparation and presentation until the final renderer is removed.
/// An accepted operation blocks new experiences through dismissal, including a survey's thank-you.
/// `experienceQueue` owns orchestration state; main owns UIKit and renderer references.
/// Synchronous queries read the `reads` snapshot, so neither thread ever waits on the other.
/// The backend selects eligible experience; the once-per-screen NPS limit is the only local presentation rule.
internal final class ExperiencesPublisher: ExperiencesPublishing, SocketSubscriptionDelegate {

    /// Where an operation came from. Manual fetches match their own reply; preview suppresses analytics.
    private enum Trigger {
        case automatic, manual, preview
    }

    /// Preparation steps of the one accepted operation, not separate admission gates.
    private enum Phase {
        case experience
        case theme(ThemeKey)
        case delay
        case waitingForHost
        case visible
        case dismissing
    }

    /// Grace period before every SDK-driven close, letting a navigated-to screen become visible first (Android
    /// `SCREEN_TRANSITION_CLOSE_DELAY_MS`).
    static let screenTransitionCloseDelay: TimeInterval = 0.5

    /// One accepted experience, including a survey's thank-you screen. Holding it as `current`
    /// keeps admission closed. Main receives its presentation, never its mutable state.
    private final class Operation {
        let trigger: Trigger
        let generation: UUID
        let screenVisitID: UUID?
        var presentation: Presentation?
        let isCancelled = AtomicReference(false)
        var experience: ExperienceContent?
        var phase: Phase = .experience
        var needsThankYou = false
        var dismissalCompletions: [() -> Void] = []
        /// SDK-driven closes (navigation, logout, QR preview, Builder capture) skip the post-dismissal fake reload.
        var refreshAfterDismissal = true
        /// Decides the post-dismissal fake reload; receiving it does not release ownership.
        var closeEvent: ExperienceEvent?
        /// The selected action's link, consumed only after the final renderer is gone.
        var completionDeepLink: URL?
        /// The Flow payload walked segment by segment; cleared to pause the walk, so no later segment opens.
        /// nil for other content.
        var flowWalk: FlowWalk?
        /// The Flow's run on this device, tracked apart from any overlay; every reported step outcome replaces it.
        var flowRun = FlowRun()
        /// The in-app debugger's identity for this Flow walk; nil for other content.
        var debugFlow: DebugFlowContext?
        /// This held push started in place of the previous operation's fake reload, so its own `finish` owes
        /// it, unless the reload policy cancels it.
        var owedReload = false

        /// True once a Flow walk presented a segment, paused or not, so its end follows the walk's reload rule.
        var isFlowWalk: Bool { experience?.flowSegment() != nil }

        init(trigger: Trigger, generation: UUID, experience: ExperienceContent? = nil, screenVisitID: UUID? = nil) {
            self.trigger = trigger
            self.generation = generation
            self.experience = experience
            self.screenVisitID = screenVisitID
        }
    }

    /// Latest QR request, waiting for the outgoing renderer to finish dismissing.
    private struct PreviewRequest {
        let experienceID: String
        let contentType: String
    }

    /// Any-thread snapshot for analytics and renderer queries.
    private struct ReadState {
        var screen = ""
        var screenEvent: Event?
        var experience: ExperienceContent?
        var presentation: Presentation?
        var generation: UUID?
        /// Main may present the current operation only while this is true.
        var isVisible = false
        /// Covers fetch, delay, presentation, thank-you, dismissal, and a waiting preview.
        var busy = false
        var needsThankYou = false
        var suppressScreenUntil: DispatchTime?
    }

    private enum PresentationStyle {
        case fullScreen, dialog, bottomSheet, anchored
    }

    /// One UI presentation, distinct from the backend experience ID. ViewModels return this identity
    /// so a late event from a removed renderer cannot affect its replacement. Only main touches the controller.
    private final class Presentation {
        let id = UUID()
        let screenVisitID: UUID?
        weak var controller: UIViewController?

        init(screenVisitID: UUID? = nil) { self.screenVisitID = screenVisitID }
    }

    private weak var container: DIContainer?
    private weak var userpilot: Userpilot?
    private let analytics: AnalyticsPublishing
    /// The in-app debugger's log; Flow walks record their runs and outcomes here.
    private let debugEventStore: DebugEventStoring
    private let remote: UserpilotRemoteSourcing
    private let themes: ThemeHandling
    private let links: LinkOpening
    private let lifecycleMonitor: LifecycleMonitoring
    private let config: Userpilot.Config
    private let logger: Logging

    private let reads = AtomicReference(ReadState())
    private let generation = AtomicReference(UUID())
    private static let queueLabel = "com.userpilot.experience-queue"

    private let experienceQueue = DispatchQueue(
        label: ExperiencesPublisher.queueLabel,
        qos: .userInteractive
    )

    // Owned by experienceQueue. `current != nil` is the admission gate.
    /// Display and thank-you delays. Its actions fire on main and hop back to the queue.
    private lazy var delayUtils = DelayUtils()
    private var current: Operation?
    private var replacementPreview: PreviewRequest?
    private var npsShownOnCurrentScreen = false
    /// The latest server push that arrived while another experience was active.
    private lazy var heldPush = HeldPushCoordinator(
        logger: logger,
        start: { [weak self] experience, owedReload in
            self?.accept(experience, owedReload: owedReload) ?? false
        },
        publishFakeReload: { [weak self] in self?.analytics.publishFakeReloadScreenEvent() }
    )

    // Owned by main.
    private weak var previewErrorAlert: UIAlertController?
    /// `screenTransitionCloseDelay`, replaceable in tests.
    private var sdkCloseDelay = ExperiencesPublisher.screenTransitionCloseDelay
    /// Presentation host when no overlay window exists; replaceable in tests.
    internal var topViewControllerProvider: () -> UIViewController? = {
        UIApplication.shared.topViewController()
    }

    /// Resolves collaborators and subscribes to socket results. Performs no UI work.
    init(container: DIContainer) {
        let config = container.resolve(Userpilot.Config.self)
        self.container = container
        self.userpilot = container.owner
        self.analytics = container.resolve(AnalyticsPublishing.self)
        self.debugEventStore = container.resolve(DebugEventStoring.self)
        self.remote = container.resolve(UserpilotRemoteSourcing.self)
        self.themes = container.resolve(ThemeHandling.self)
        self.links = container.resolve(LinkOpening.self)
        self.lifecycleMonitor = container.resolve(LifecycleMonitoring.self)
        self.config = config
        self.logger = config.logger

        let socket: SocketManaging = container.resolve(SocketManaging.self)
        socket.registerCallback(self)
        lifecycleMonitor.addDelegate(self, replayCurrentState: false)
    }

    deinit {
        lifecycleMonitor.removeDelegate(self)
    }

    // MARK: - Thread boundary and synchronous queries

    /// Enter the owner queue and drop work submitted before logout; dismissal cleanup may bypass that check.
    private func onQueue(checkGeneration: Bool = true, _ action: @escaping (ExperiencesPublisher) -> Void) {
        let expectedGeneration = generation.value
        experienceQueue.async { [weak self] in
            guard let self, !checkGeneration || self.generation.value == expectedGeneration else { return }
            tryCatch { action(self) }
        }
    }

    /// Runs inline when already on main; otherwise hops asynchronously.
    private func onMain(_ action: @escaping (ExperiencesPublisher) -> Void) {
        performOnMain { [weak self] in
            guard let self else { return }
            action(self)
        }
    }

    /// Debug-only ownership checks; release builds never trap the host app.
    private func assertOnQueue() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(experienceQueue))
        #endif
    }

    private func assertOnMain() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
    }

    /// Blocks normal responses for an active preview and for one waiting to replace current work.
    private var isPreviewing: Bool {
        replacementPreview != nil || current?.trigger == .preview
    }

    /// Publishes the current operation for synchronous queries. Screen and cooldown keep their own writers.
    private func publishReadState() {
        assertOnQueue()
        let operation = current
        let waitingPreview = replacementPreview != nil
        reads.update {
            var state = $0
            state.busy = operation != nil || waitingPreview
            state.experience = operation?.experience
            state.presentation = operation?.presentation
            state.generation = operation?.generation
            state.isVisible = false
            if let operation, case .visible = operation.phase { state.isVisible = true }
            state.needsThankYou = operation?.needsThankYou == true
            return state
        }
    }

    var getCurrentScreen: String { reads.value.screen }

    var currentScreenEvent: Event? { reads.value.screenEvent }

    /// Captured by each ViewModel at construction; invalidated synchronously by logout.
    var activeRendererID: UUID? {
        let state = reads.value
        return state.generation == generation.value ? state.presentation?.id : nil
    }

    /// Return experience only to the current presentation and user generation, including during dismissal.
    func getActiveExperience(rendererID: UUID?) -> ExperienceContent? {
        let state = reads.value
        guard rendererID != nil, state.presentation?.id == rendererID,
              state.generation == generation.value else { return nil }
        return state.experience
    }

    /// A matching survey renderer may continue to thank-you without releasing the experience gate.
    func hasNextFlowStep(rendererID: UUID?) -> Bool {
        let state = reads.value
        return rendererID != nil && state.presentation?.id == rendererID
            && state.generation == generation.value && state.needsThankYou
    }

    /// Recheck after asynchronous work: reference identity rejects replacement, generation rejects logout.
    private func owns(_ operation: Operation) -> Bool {
        current === operation && operation.generation == generation.value
            && (operation.screenVisitID == nil || operation.screenVisitID == currentScreenEvent?.screenVisitID)
    }

    /// Resolve UI callbacks once on the owning queue, then pass the validated operation onward.
    private func onPresentation(
        _ shown: Presentation,
        _ action: @escaping (ExperiencesPublisher, Operation) -> Void
    ) {
        onQueue { publisher in
            guard let operation = publisher.current, publisher.owns(operation),
                  operation.presentation === shown else { return }
            action(publisher, operation)
        }
    }

    /// Analytics' gate for repeat screen requests: idle, and at least one second after a close event.
    /// Builder capture mode deliberately does not affect it, so screen events keep flowing.
    func canRequestScreenEvent() -> Bool {
        let state = reads.value
        return !state.busy && (state.suppressScreenUntil.map { DispatchTime.now() >= $0 } ?? true)
    }

    /// Builder capture mode blocks every instance's experiences at admission and again before presenting.
    /// It is a separate check from `busy`; nothing dropped here is cached or replayed afterwards.
    private func isBlockedByCaptureMode() -> Bool {
        guard BuilderCaptureMode.isActive else { return false }
        logger.info("Experience dropped - Builder capture mode is on")
        return true
    }
}

// MARK: - Admission

extension ExperiencesPublisher {

    /// Manual API entry. Claims ownership before requesting experience; dropped while busy or capturing.
    func triggerExperience(_ experienceId: String) {
        guard !reads.value.busy else { return }
        onQueue { publisher in
            guard !publisher.isBlockedByCaptureMode() else { return }
            guard publisher.current == nil, !publisher.isPreviewing else {
                publisher.logger.info("Manual experience dropped - another experience is in progress")
                return
            }
            let operation = Operation(trigger: .manual, generation: publisher.generation.value,
                                      screenVisitID: publisher.currentScreenEvent?.screenVisitID)
            publisher.current = operation
            publisher.publishReadState()
            publisher.request(FetchExperienceEvent(experienceId: experienceId), for: operation)
        }
    }

    /// Admits backend-selected screen or track experience. Idle starts preparation; busy or capturing drops it.
    /// Returns true when the experience took ownership, carrying `owedReload` before preparation can end it.
    @discardableResult
    private func accept(
        _ experience: ExperienceContent,
        screenVisitID: UUID? = nil,
        owedReload: Bool = false
    ) -> Bool {
        assertOnQueue()
        guard !isBlockedByCaptureMode() else { return false }
        guard !isPreviewing else { return false }
        guard !isSuppressedNPS(experience) else {
            logger.info("NPS suppressed - already shown on the current screen")
            return false
        }
        guard current == nil else {
            logger.info("Experience dropped - another experience is in progress")
            return false
        }
        let operation = Operation(trigger: .automatic, generation: generation.value, experience: experience,
                                  screenVisitID: screenVisitID ?? currentScreenEvent?.screenVisitID)
        operation.owedReload = owedReload
        current = operation
        publishReadState()
        prepare(operation)
        return true
    }

    /// Socket push carrying a server-triggered experience; one arriving while another is active is held.
    /// A non-null `request_id` answers a request instead, so only a missing or null one is a push.
    func onNewMessage(_ message: Message) {
        onQueue { publisher in
            guard !publisher.isPreviewing,
                  let payload = message.payload["payload"] as? [String: Any],
                  (payload["request_id"] ?? NSNull()) is NSNull,
                  let response = payload.toJSONString(),
                  let experience = response.experienceCandidates(logger: publisher.logger).first else { return }
            if publisher.current == nil {
                publisher.accept(experience)
            } else if !publisher.isBlockedByCaptureMode() {
                publisher.heldPush.hold(experience)
            }
        }
    }

    /// Screen replies remain shared notifications; experience/theme requests own their completions.
    func onSocketEventSent(_ eventName: String, _ payload: Payload, _ message: Message, _ eventSent: Bool) {
        // Class-aware mode consumes per-send completions, never the same response twice.
        guard !config.enableScreenClassIdentity else { return }
        guard eventName == Constants.Event.screenEvent, !reads.value.busy else { return }
        onQueue { publisher in
            guard !publisher.isPreviewing else { return }
            publisher.receiveScreen(payload, message, success: eventSent)
        }
    }

    func receiveScreenResponse(_ payload: Payload, _ message: Message, success: Bool, visitID: UUID?) {
        guard !reads.value.busy else { return }
        onQueue { publisher in
            guard !publisher.isPreviewing,
                  visitID == nil || visitID == publisher.currentScreenEvent?.screenVisitID else { return }
            publisher.receiveScreen(payload, message, success: success, visitID: visitID)
        }
    }

    /// Admits a screen reply unless a newer screen event waits in the analytics queue, meaning the user has
    /// moved on; the reply is then not even decoded. This is the only screen check, for every content type.
    private func receiveScreen(_ payload: Payload, _ message: Message, success: Bool, visitID: UUID? = nil) {
        assertOnQueue()
        guard success else { return }
        if analytics.hasQueuedScreenEvent(payload) {
            logger.info("Screen response ignored - a newer screen event is queued")
            return
        }
        guard let response = message.payload.toJSONString(),
              let experience = response.experienceCandidates(logger: logger).first else { return }
        accept(experience, screenVisitID: visitID)
    }

    /// Continues the current manual fetch. A failed or empty reply releases the gate.
    /// Equal experience tokens from an older request cannot release this operation.
    private func receiveManualExperience(_ operation: Operation, _ message: Message, success: Bool) {
        assertOnQueue()
        guard operation.trigger == .manual, case .experience = operation.phase else { return }
        guard success, let response = message.payload.toJSONString(),
              let experience = response.experienceCandidates(logger: logger).first else {
            logger.info("Manual experience request returned no content")
            finish(operation)
            return
        }
        operation.experience = experience
        publishReadState()
        prepare(operation)
    }

    /// Continues the operation waiting for this theme. A failed app theme reply falls back to the
    /// experience's own theme; any other failed reply releases the gate.
    private func receiveTheme(_ operation: Operation, _ message: Message, success: Bool) {
        assertOnQueue()
        guard case .theme(let key) = operation.phase else { return }
        let response = message.payload.toJSONString()
        logger.debug("🎨 Theme response for %{public}@ (success: %{public}@): %{public}@",
                     String(describing: key), String(success), response ?? "nil")
        let theme = success ? response?.toMobileTheme(logger: logger) : nil
        switch key {
        case .id(let themeID):
            guard let theme, theme.id == themeID else {
                logger.info("Experience dropped - theme request failed")
                finish(operation)
                return
            }
            themes.saveTheme(theme)
        case .title(let title):
            guard let theme, themes.saveAppTheme(theme, title: title) else {
                logger.info("App theme %@ unavailable - using the experience's own theme", title)
                themes.markAppThemeUnavailable(title)
                prepare(operation)
                return
            }
        }
        schedulePresentation(operation)
    }

    /// Each connection fetches the app theme again, so dashboard edits reach the next experience.
    func onSocketOpened() {
        themes.resetAppThemes()
    }

    /// Socket loss abandons preparation still waiting for a experience/theme reply.
    /// Delayed or visible UI and HTTP-based preview work continue.
    func onSocketClosed() {
        onQueue { publisher in
            guard let operation = publisher.current, operation.trigger != .preview else { return }
            switch operation.phase {
            case .experience, .theme:
                publisher.finish(operation)
            default:
                break
            }
        }
    }
}

// MARK: - Preparation

extension ExperiencesPublisher {

    /// NPS and cached themes go straight to the display delay; otherwise request the one missing theme,
    /// which is the app theme while one is selected and available.
    private func prepare(_ operation: Operation) {
        assertOnQueue()
        guard let experience = operation.experience else {
            finish(operation)
            return
        }
        guard !isSuppressedNPS(experience) else {
            logger.info("NPS suppressed - already shown on the current screen")
            finish(operation)
            return
        }
        guard let themeKey = themes.requiredThemeKey(for: experience) else {
            schedulePresentation(operation)
            return
        }
        guard analytics.canRequestEvent else {
            logger.info("Experience dropped - socket unavailable to fetch its theme")
            finish(operation)
            return
        }
        operation.phase = .theme(themeKey)
        request(FetchThemeEvent(key: themeKey, token: config.token), for: operation)
    }

    /// The completion belongs to this operation; cancellation also covers time in the SDK queue.
    private func request(_ event: SDKEvent, for operation: Operation) {
        guard owns(operation) else { return }
        let eventName = event.eventName
        analytics.publishInternalSDKEvent(event, shouldSend: { [weak self] in
            self?.generation.value == operation.generation && !operation.isCancelled.value
        }, completion: { [weak self] message, success in
            self?.onQueue { publisher in
                guard publisher.owns(operation) else { return }
                if eventName == SDKEventsName.fetchExperienceContent.rawValue {
                    publisher.receiveManualExperience(operation, message, success: success)
                } else {
                    publisher.receiveTheme(operation, message, success: success)
                }
            }
        })
    }

    /// Apply this experience's display delay; the scheduled continuation rechecks operation ownership.
    private func schedulePresentation(_ operation: Operation) {
        guard let experience = operation.experience else { finish(operation); return }
        schedule(operation, after: experience.resolvedDelay()) { $0.openExperience($1) }
    }

    /// One delay at a time (initial display or thank-you). DelayUtils fires on main, so the action
    /// returns to the queue and runs only if this operation is still current and waiting.
    private func schedule(
        _ operation: Operation,
        after interval: TimeInterval,
        action: @escaping (ExperiencesPublisher, Operation) -> Void
    ) {
        assertOnQueue()
        operation.phase = .delay
        publishReadState()
        delayUtils.delayAction(delayTime: interval) { [weak self, weak operation] in
            self?.onQueue { publisher in
                guard let operation, publisher.owns(operation),
                      case .delay = operation.phase else { return }
                action(publisher, operation)
            }
        }
    }

    /// Do not repeat NPS within the same screen visit, even if the backend returns it again.
    private func isSuppressedNPS(_ experience: ExperienceContent) -> Bool {
        experience.asNPSContent() != nil && npsShownOnCurrentScreen
    }
}

// MARK: - Renderers

extension ExperiencesPublisher {

    /// Picks the existing renderer and presentation style. UIKit work happens later on main.
    private func openExperience(_ operation: Operation) {
        guard let experience = operation.experience else { finish(operation); return }
        switch experience {
        case .flow(let flow, _):
            openFlow(flow, operation)
        case .survey(let survey):
            openSurvey(survey, operation)
        case .nps:
            showExperience(operation, makeViewModel: NPSViewModel.init,
                           makeViewController: NPSBottomSheetViewController.init, style: .bottomSheet)
        }
    }

    /// Choose the flow's carousel or themed slideout renderer; creation remains on main. A whole Flow
    /// starts a walk, whose segments come back here as carousel, slideout or tooltip content.
    private func openFlow(_ flow: FlowContent, _ operation: Operation) {
        switch flow.type {
        case .carousel:
            showExperience(operation, makeViewModel: ExperienceViewModel.init,
                           makeViewController: CarouselExperienceViewController.init, style: .fullScreen)
        case .slideout where flow.isBottomSheet(using: themes):
            showExperience(operation, makeViewModel: ExperienceViewModel.init,
                           makeViewController: SlideOutBottomSheetViewController.init, style: .bottomSheet)
        case .slideout:
            showExperience(operation, makeViewModel: ExperienceViewModel.init,
                           makeViewController: SlideOutDialogViewController.init, style: .dialog)
        case .tooltip:
            guard flow.tooltipSteps != nil else { finish(operation); return }
            showExperience(operation, makeViewModel: TooltipViewModel.init,
                           makeViewController: TooltipViewController.init, style: .anchored)
        case .flow:
            startFlowWalk(flow, operation)
        }
    }

    /// One operation walks the whole Flow payload. Consecutive tooltip steps form one segment and a modal or
    /// slideout step is its own; each segment reuses a renderer through its projection.
    private func startFlowWalk(_ flow: FlowContent, _ operation: Operation) {
        let context = DebugFlowContext(flow: flow, isPreview: operation.trigger == .preview,
                                       generation: operation.generation)
        operation.debugFlow = context
        debugEventStore.recordFlow(context, outcome: nil, screen: nil)
        operation.flowWalk = FlowWalk(flow: flow)
        openFlowSegment(operation)
    }

    /// Presents the walk's current segment on the current screen; the projection's type picks the renderer.
    private func openFlowSegment(_ operation: Operation) {
        let screen = currentScreenEvent?.screenTitle
        guard let segment = operation.flowWalk?.current(screen: screen, run: operation.flowRun),
              let flow = segment.asFlowContent() else {
            finish(operation)
            return
        }
        guard !flow.steps.isEmpty else {
            logger.info("‼️ Flow %{public}@ dropped - it has no steps", String(flow.id))
            finish(operation)
            return
        }
        operation.experience = segment
        publishReadState()
        openFlow(flow, operation)
    }

    /// Choose the list or themed survey renderer; showExperience reserves any thank-you continuation.
    private func openSurvey(_ survey: SurveyContent, _ operation: Operation) {
        switch survey.type {
        case .list:
            showExperience(operation, makeViewModel: SurveyViewModel.init,
                           makeViewController: SurveyListViewController.init, style: .fullScreen)
        case .step where survey.isBottomSheet(using: themes):
            showExperience(operation, makeViewModel: SurveyViewModel.init,
                           makeViewController: SurveyBottomSheetViewController.init, style: .bottomSheet)
        case .step:
            showExperience(operation, makeViewModel: SurveyViewModel.init,
                           makeViewController: SurveyDialogViewController.init, style: .dialog)
        }
    }

    /// A list survey with an enabled completion module reserves its thank-you step up front.
    private func showExperience<VM, VC: UIViewController>(
        _ operation: Operation,
        makeViewModel: @escaping (DIContainer) -> VM,
        makeViewController: @escaping (VM) -> VC,
        style: PresentationStyle
    ) {
        guard let experience = operation.experience else {
            finish(operation)
            return
        }
        if let survey = experience.asSurveyContent(), survey.type == .list,
           let last = survey.modules.last, last.type == .completed, last.metadata?.enabled != false {
            operation.needsThankYou = true
        }
        enqueuePresentation(operation, style: style) { publisher, _ in
            guard let container = publisher.container else { return nil }
            return makeViewController(makeViewModel(container))
        }
    }

    /// Marks the operation visible, then hands creation to main with only immutable values.
    /// Cancelling a visible operation waits for main to skip or dismiss its renderer.
    private func enqueuePresentation(
        _ operation: Operation,
        style: PresentationStyle,
        makeController: @escaping (ExperiencesPublisher, Presentation) -> UIViewController?
    ) {
        assertOnQueue()
        guard owns(operation) else { return }
        let shown = Presentation(screenVisitID: operation.screenVisitID)
        operation.presentation = shown
        operation.phase = .visible
        publishReadState()
        let screen = getCurrentScreen
        onMain { publisher in
            publisher.presentOnMain(shown, screen: screen, style: style, makeController: makeController)
        }
    }

    /// Skips a cancelled handoff, clears a preview error alert, then builds and presents the renderer.
    /// A preview without a host waits for lifecycle recovery; renderer failures release ownership.
    private func presentOnMain(
        _ shown: Presentation,
        screen: String,
        style: PresentationStyle,
        makeController: @escaping (ExperiencesPublisher, Presentation) -> UIViewController?
    ) {
        assertOnMain()
        let state = reads.value
        guard state.isVisible, state.presentation === shown,
              state.generation == generation.value,
              shown.screenVisitID == nil || shown.screenVisitID == state.screenEvent?.screenVisitID else { return }
        // Work that was preparing or delayed when capture mode started never shows or sends a seen event.
        guard !isBlockedByCaptureMode() else {
            didDismissOnMain(shown)
            return
        }
        if let alert = previewErrorAlert {
            previewErrorAlert = nil
            alert.dismiss(animated: false) { [weak self] in
                self?.presentOnMain(shown, screen: screen, style: style, makeController: makeController)
            }
            return
        }
        guard let host = presentationHost() else {
            logger.info("Experience not shown - no free presentation host")
            waitForPresentationHost(shown)
            return
        }
        guard host.presentedViewController == nil,
              let controller = makeController(self, shown) else {
            logger.info("Experience not shown - no free presentation host")
            didDismissOnMain(shown)
            return
        }
        if let tooltip = controller as? TooltipViewController {
            guard let targetWindow = tooltip.admitTargetHost() else {
                didDismissOnMain(shown)
                return
            }
            // Target coordinates and the overlay must belong to the same admitted app window.
            userpilot?.experienceOverlayWindow.prepareForPresentation(in: targetWindow)
            // The focused input belongs to the app window, not the SDK overlay.
            targetWindow.endEditing(true)
        }
        shown.controller = controller
        onPresentation(shown) { publisher, operation in
            publisher.recordExperienceShown(operation)
            guard operation.experience?.asNPSContent() != nil,
                  publisher.getCurrentScreen == screen else { return }
            publisher.npsShownOnCurrentScreen = true
        }
        presentController(controller, on: host, style: style)
    }

    /// Each renderer keeps its existing native presentation and dismissal mechanism.
    private func presentController(
        _ controller: UIViewController, on host: UIViewController, style: PresentationStyle
    ) {
        assertOnMain()
        switch style {
        case .fullScreen:
            controller.modalPresentationStyle = .fullScreen
            host.present(controller, animated: true)
        case .dialog:
            host.presentDialog(viewController: controller)
        case .bottomSheet:
            host.presentBottomSheet(viewController: controller)
        case .anchored:
            host.present(controller, animated: false)
        }
    }

    /// This SDK instance's overlay root, or the provider's controller when no overlay exists.
    private func presentationHost() -> UIViewController? {
        assertOnMain()
        if let overlay = userpilot?.experienceOverlayWindow {
            overlay.prepareForPresentation()
            guard overlay.isReadyForPresentation(in: UIApplication.shared.windows) else { return nil }
            return overlay.rootViewController
        }
        return topViewControllerProvider()
    }

    /// No renderer was created. Normal content ends like any other unshown renderer, so a Flow walk pauses
    /// without a reload; a preview retains its loaded content and theme.
    private func waitForPresentationHost(_ shown: Presentation) {
        onPresentation(shown) { publisher, operation in
            guard case .visible = operation.phase else { return }
            operation.presentation = nil
            guard operation.trigger == .preview else { publisher.continueFlowWalk(operation); return }
            operation.phase = .waitingForHost
            publisher.publishReadState()
            // The host can become ready before this queue receives the failed main-thread attempt.
            publisher.resumeWaitingPreview()
        }
    }

    /// Continue only the matching survey after its UIKit dismissal; keep ownership through thank-you delay.
    func showThankYouMessage(
        _ survey: SurveyContent, _ theme: SurveyTheme, _ submissionId: Int64, rendererID: UUID?
    ) {
        guard let rendererID else { return }
        onMain { publisher in
            guard let shown = publisher.reads.value.presentation, shown.id == rendererID,
                  shown.controller?.presentingViewController == nil else { return }
            publisher.onPresentation(shown) { publisher, operation in
                guard operation.needsThankYou,
                      operation.experience?.asSurveyContent()?.id == survey.id else { return }
                operation.needsThankYou = false
                operation.presentation = nil
                let interval = Constants.Theme.delayTimeForExperience
                publisher.schedule(operation, after: interval) { publisher, operation in
                    publisher.presentThankYou(operation, survey: survey, theme: theme, submissionID: submissionId)
                }
            }
        }
    }

    /// The survey's final renderer. Its dismissal callback releases the operation.
    private func presentThankYou(
        _ operation: Operation,
        survey: SurveyContent,
        theme: SurveyTheme,
        submissionID: Int64
    ) {
        enqueuePresentation(operation, style: .bottomSheet) { publisher, shown in
            let controller = ThankYouBottomSheetViewController(surveyContent: survey, surveyTheme: theme)
            controller.actionButtonClicked = { [weak publisher] deepLink in
                publisher?.onPresentation(shown) { publisher, operation in
                    guard case .visible = operation.phase else { return }
                    operation.completionDeepLink = deepLink.flatMap { $0.isEmpty ? nil : URL(string: $0) }
                    let completed = SurveyExperienceActionEvent.completed(
                        surveyId: survey.id, submissionId: submissionID, hasDeepLink: deepLink != nil
                    )
                    publisher.publish([completed], operation: operation)
                }
            }
            controller.onDismissCompleted = { [weak publisher] in
                publisher?.onMain { $0.didDismissOnMain(shown) }
            }
            return controller
        }
    }
}

// MARK: - Final dismissal and cancellation

extension ExperiencesPublisher {

    /// Accept dismissal only for the named presentation after UIKit has detached its controller.
    /// A completed/dismissed analytics event alone cannot release the operation or request the next experience.
    func experienceDidFinishDismissing(rendererID: UUID?) {
        guard let rendererID else { return }
        onMain { publisher in
            guard let shown = publisher.reads.value.presentation, shown.id == rendererID,
                  shown.controller?.presentingViewController == nil else { return }
            publisher.didDismissOnMain(shown)
        }
    }

    /// Close request. Returning does not mean the renderer has finished dismissing.
    func endExperience(manualClose: Bool) {
        onQueue { $0.closeCurrent(manualClose: manualClose, refresh: true) }
    }

    /// Completes once the current operation released its renderer.
    func endExperience(manualClose: Bool, completion: (() -> Void)?) {
        onQueue(checkGeneration: false) { publisher in
            publisher.closeCurrent(manualClose: manualClose, refresh: true, completion: completion)
        }
    }

    /// Builder capture waits for native teardown instead of photographing a closing experience.
    func closeSilently(completion: (() -> Void)?) {
        onQueue(checkGeneration: false) { publisher in
            publisher.heldPush.clear()
            publisher.closeCurrent(manualClose: false, refresh: false, completion: completion)
        }
    }

    /// The one close every SDK-driven cause shares (navigation, logout, QR preview, Builder capture), for every
    /// content type and Flow step: renderers close without reporting, no host callback fires, the held push is
    /// dropped and nothing reloads, so an open Flow run pauses.
    private func closeSilently() {
        assertOnQueue()
        heldPush.clear()
        closeCurrent(manualClose: false, refresh: false)
    }

    /// Teardown waiters still complete when logout invalidated queued experience work.
    private func closeCurrent(manualClose: Bool, refresh: Bool, completion: (() -> Void)?) {
        assertOnQueue()
        guard let operation = current else {
            onMain { _ in completion?() }
            return
        }
        if let completion { operation.dismissalCompletions.append(completion) }
        closeCurrent(manualClose: manualClose, refresh: refresh)
    }

    /// Work not yet handed to main finishes immediately; a handed-off renderer keeps ownership until main
    /// confirms it is gone. Repeated calls never start a second dismissal.
    private func closeCurrent(manualClose: Bool, refresh: Bool) {
        assertOnQueue()
        delayUtils.cancelDelay()
        guard let operation = current else { startWaitingPreview(); return }
        operation.isCancelled.value = true
        operation.completionDeepLink = nil
        operation.refreshAfterDismissal = refresh
        operation.needsThankYou = false
        operation.flowWalk = nil
        switch operation.phase {
        case .dismissing:
            publishReadState()
        case .visible:
            operation.phase = .dismissing
            publishReadState() // Invalidates presentation work that main has not started yet.
            guard let shown = operation.presentation else { finish(operation); return }
            onMain { $0.dismissOnMain(shown, manualClose: manualClose) }
        default:
            finish(operation)
        }
    }

    /// Every SDK-driven close waits `screenTransitionCloseDelay` so a navigated-to screen becomes visible first,
    /// then closes only if this presentation is still current; the user's and the host app's closes run at once.
    /// Logout's new generation does not cancel it.
    private func dismissOnMain(_ shown: Presentation, manualClose: Bool) {
        assertOnMain()
        guard !manualClose, sdkCloseDelay > 0 else {
            dismissRendererOnMain(shown, manualClose: manualClose)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + sdkCloseDelay) { [weak self] in
            guard let self, self.reads.value.presentation === shown else { return }
            self.dismissRendererOnMain(shown, manualClose: false)
        }
    }

    /// Dismisses this operation's renderer. A natural dismissal already running reports through
    /// the renderer's own callback; the operation stays busy until dismissal is confirmed.
    private func dismissRendererOnMain(_ shown: Presentation, manualClose: Bool) {
        assertOnMain()
        guard let renderer = shown.controller, renderer.presentingViewController != nil else {
            didDismissOnMain(shown)
            return
        }
        guard !renderer.isBeingDismissed else { return }
        let completed: () -> Void = { [weak self] in
            self?.onMain { $0.didDismissOnMain(shown) }
        }
        if let experience = renderer as? UPExperienceDelegate {
            experience.triggerCloseExperience(manualClose: manualClose, completion: completed)
        } else if let sheet = renderer as? BottomSheetViewController {
            sheet.dismissBottomSheet(completion: completed)
        } else {
            renderer.dismiss(animated: true, completion: completed)
        }
    }

    /// Cleanup also runs after logout, but only for the presentation that actually dismissed.
    private func didDismissOnMain(_ shown: Presentation) {
        assertOnMain()
        shown.controller = nil
        onQueue(checkGeneration: false) { publisher in
            guard let operation = publisher.current, operation.presentation === shown else { return }
            operation.presentation = nil
            publisher.continueFlowWalk(operation)
        }
    }

    /// Presents the next segment in this operation once every step of the removed one ended and the run is
    /// still open; otherwise finishes. A segment removed before its steps ended, while the run is still open,
    /// closed silently, which pauses the walk; one whose run ended early (`end_flow`) still reloads.
    private func continueFlowWalk(_ operation: Operation) {
        assertOnQueue()
        let hasOpenSteps = operation.flowWalk?.isCurrentSegmentEnded(operation.flowRun) == false
        if hasOpenSteps, !operation.flowRun.hasEnded { operation.flowWalk = nil }
        guard !operation.flowRun.hasEnded, operation.closeEvent == nil,
              let next = operation.flowWalk?.next() else {
            finish(operation)
            return
        }
        operation.flowWalk = next
        schedule(operation, after: Constants.Theme.delayTimeForExperience) { $0.openFlowSegment($1) }
    }

    /// Release ownership and start a waiting preview, then a held push in place of the fake reload,
    /// which then owes that reload; otherwise enqueue the reload. Generation, reload policy and deep-link
    /// checks prevent an outgoing operation from refreshing another context.
    private func finish(_ operation: Operation) {
        assertOnQueue()
        guard current === operation else { return }
        if let context = operation.debugFlow { debugEventStore.pauseFlow(operationID: context.operationID) }
        operation.isCancelled.value = true
        delayUtils.cancelDelay()
        current = nil
        let completions = operation.dismissalCompletions
        operation.dismissalCompletions.removeAll()
        publishReadState()
        onMain { _ in completions.forEach { $0() } }
        onMain { $0.userpilot?.existingExperienceOverlayWindow?.hideIfIdle() }
        startWaitingPreview()
        let opensDeepLink = operation.completionDeepLink != nil
        openCompletionDeepLink(operation)
        if opensDeepLink { heldPush.clear() }
        heldPush.onOperationFinished(owesReload: owesReload(operation, opensDeepLink: opensDeepLink))
    }

    /// Whether `operation`'s ending calls for a fake reload: one a held push inherited, a walk that ran out of
    /// segments, ended its run or was closed by the user, or an eligible close event. A walk that closed silently
    /// without a close event pauses instead; a deep link, a new context (logout, a newer operation) or a skipped
    /// refresh owes none.
    private func owesReload(_ operation: Operation, opensDeepLink: Bool) -> Bool {
        guard !opensDeepLink, current == nil, operation.refreshAfterDismissal,
              operation.generation == generation.value else { return false }
        if operation.owedReload { return true }
        if operation.isFlowWalk { return operation.flowWalk != nil || operation.closeEvent != nil }
        guard let close = operation.closeEvent else { return false }
        return close.isEventForCloseExperience() && !close.hasDeepLink
    }

    /// Starts the latest QR request once the outgoing operation has released ownership.
    private func startWaitingPreview() {
        assertOnQueue()
        guard current == nil, let preview = replacementPreview else { return }
        replacementPreview = nil
        guard !isBlockedByCaptureMode() else {
            publishReadState()
            return
        }
        beginPreview(preview)
    }

    /// Routes a named screen through the same navigation rules as a full screen event.
    func updateScreen(_ screenName: String) {
        updateScreen(Event(type: .screen(screenName)))
    }

    /// Publishes an app screen immediately; on a screen change the queue then resets NPS, drops the held push
    /// and closes the current experience silently. Repeated identities and generated reloads retain the visit;
    /// preview survives navigation.
    @discardableResult
    func updateScreen(_ event: Event) -> UUID? {
        guard event.isFakeReload == nil, let screenName = event.screenTitle else { return nil }
        var changed = false
        var visitID: UUID?
        reads.update {
            var state = $0
            changed = config.enableScreenClassIdentity
                ? state.screenEvent?.screenIdentityKey(classAware: true) != event.screenIdentityKey(classAware: true)
                : state.screen != screenName
            var captured = event
            if config.enableScreenClassIdentity, event.nativeSwiftUIScreenClass != nil {
                visitID = changed ? UUID() : (state.screenEvent?.screenVisitID ?? UUID())
            }
            captured.screenVisitID = visitID
            state.screenEvent = captured
            state.screen = screenName
            return state
        }
        guard changed else { return visitID }
        onQueue { publisher in
            // A newer background screen update can overtake this queued transition.
            guard publisher.getCurrentScreen == screenName,
                  visitID == publisher.currentScreenEvent?.screenVisitID else { return }
            publisher.npsShownOnCurrentScreen = false
            publisher.heldPush.clear()
            guard !publisher.isPreviewing else { return }
            publisher.closeSilently()
        }
        return visitID
    }

    /// Drops any preview or held push, resets the NPS limit, and closes silently.
    func logout() {
        generation.value = UUID() // Stop old renderer/service callbacks before asynchronous teardown.
        reads.update {
            var state = $0
            if state.screenEvent?.screenVisitID != nil { state.screenEvent?.screenVisitID = UUID() }
            return state
        }
        onQueue(checkGeneration: false) { publisher in
            publisher.replacementPreview = nil
            publisher.npsShownOnCurrentScreen = false
            publisher.closeSilently()
            // An idle overlay can outlive its operation; collapse it without constructing a new window.
            publisher.onMain { $0.userpilot?.existingExperienceOverlayWindow?.hideIfIdle() }
        }
    }
}

// MARK: - Preview owns admission from the scan through final dismissal

extension ExperiencesPublisher: LifecycleDelegate {
    func onAppActive() { resumeWaitingPreview() }
    func onSceneActive() { resumeWaitingPreview() }
    func onWindowBecameKey() { resumeWaitingPreview() }

    /// Inspect UIKit on main, then claim the retry on the operation queue. Repeated lifecycle
    /// signals cannot schedule twice, and logout or replacement invalidates the original operation.
    private func resumeWaitingPreview() {
        onQueue { publisher in
            guard let operation = publisher.current, case .waitingForHost = operation.phase else { return }
            publisher.onMain { [weak operation] publisher in
                guard let operation, !operation.isCancelled.value,
                      operation.generation == publisher.generation.value,
                      publisher.presentationHost() != nil else { return }
                publisher.onQueue { publisher in
                    guard publisher.owns(operation), case .waitingForHost = operation.phase else { return }
                    publisher.schedulePresentation(operation)
                }
            }
        }
    }
}

extension ExperiencesPublisher {

    /// QR entry, the only input that interrupts the current operation. Preparation (experience or theme
    /// fetch, display delay) is cancelled at once; a visible renderer finishes dismissing first.
    /// The latest scan wins, including over an older preview and a held push. Builder capture mode drops it.
    func triggerPreviewExperience(_ experienceId: String, _ queryItems: [URLQueryItem]) {
        onQueue { publisher in
            publisher.heldPush.clear()
            guard !publisher.isBlockedByCaptureMode() else { return }
            publisher.replacementPreview = PreviewRequest(
                experienceID: experienceId,
                contentType: queryItems.first { $0.name == "type" }?.value ?? ""
            )
            publisher.publishReadState()
            publisher.closeSilently()
        }
    }

    /// Claims the gate before fetching. The response bundles its theme, so no theme request follows.
    /// Results for a replaced preview are ignored.
    private func beginPreview(_ request: PreviewRequest) {
        assertOnQueue()
        let operation = Operation(trigger: .preview, generation: generation.value)
        current = operation
        publishReadState()
        remote.fetchPreviewExperience(
            params: PreviewExperienceQueryParams(
                baseUrl: Environment.getExperienceContentUrl(), appToken: config.token,
                contentType: request.contentType, contentId: request.experienceID
            )
        ) { [weak self, weak operation] result in
            self?.onQueue { publisher in
                guard let operation, publisher.owns(operation) else { return }
                switch result {
                case .success(let preview):
                    let experience = preview.flow.map { ExperienceContent.flow(content: $0) }
                        ?? preview.survey.map { ExperienceContent.survey(content: $0) }
                    guard let experience, let theme = preview.theme else {
                        publisher.logger.info("Preview dropped - response has no content or theme")
                        publisher.finish(operation)
                        return
                    }
                    operation.experience = experience
                    publisher.themes.saveTheme(theme)
                    publisher.publishReadState()
                    publisher.schedulePresentation(operation)
                case .failure(let error):
                    let expectedGeneration = operation.generation
                    publisher.finish(operation)
                    publisher.onMain { publisher in
                        guard publisher.generation.value == expectedGeneration else { return }
                        publisher.showPreviewError(error.localizedDescription)
                    }
                }
            }
        }
    }

    /// Shown only while idle and the host is free, so it never competes with an accepted experience.
    private func showPreviewError(_ message: String) {
        assertOnMain()
        guard !reads.value.busy, let host = presentationHost(), host.presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Preview Experience", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default))
        previewErrorAlert = alert
        host.present(alert, animated: true)
    }
}

// MARK: - Renderer events and links

extension ExperiencesPublisher {

    /// Resolve the named presentation, then validate operation ownership on the experience queue.
    func publishInternalSDKEvent(_ sdkEvent: ExperienceEvent, rendererID: UUID?) {
        guard let rendererID else { return }
        let state = reads.value
        guard let shown = state.presentation, shown.id == rendererID else { return }
        onPresentation(shown) { $0.publish([sdkEvent], operation: $1) }
    }

    /// The run and its events land together, so the next segment and the reload rule read this outcome's run.
    func publishFlowStepOutcome(_ outcome: FlowStepOutcome, rendererID: UUID?) {
        let state = reads.value
        guard let rendererID, let shown = state.presentation, shown.id == rendererID else { return }
        let screen = state.screenEvent?.screenTitle
        onPresentation(shown) { publisher, operation in
            operation.flowRun = outcome.run
            publisher.publish(outcome.events, flowOutcome: (outcome, screen), operation: operation)
        }
    }

    /// The one exit for experience events: a Flow step outcome updates the debugger's run, then each event
    /// is sent, or for a preview only recorded in the debugger.
    private func publish(
        _ events: [ExperienceEvent],
        flowOutcome: (outcome: FlowStepOutcome, screen: String?)? = nil,
        operation: Operation
    ) {
        assertOnQueue()
        if let flowOutcome, let context = operation.debugFlow {
            debugEventStore.recordFlow(context, outcome: flowOutcome.outcome, screen: flowOutcome.screen)
        }
        events.forEach { publishEvent($0, operation: operation) }
    }

    /// Close events record reload policy; ownership is released only after UIKit dismissal.
    private func publishEvent(_ sdkEvent: ExperienceEvent, operation: Operation) {
        if operation.trigger == .preview {
            debugEventStore.recordPreview(sdkEvent)
        } else {
            analytics.publishInternalSDKEvent(sdkEvent)
        }
        guard sdkEvent.isEventForCloseExperience() || sdkEvent.isEventForCloseNPSExperience() else { return }
        reads.update {
            var state = $0
            state.suppressScreenUntil = .now() + 1
            return state
        }
        operation.closeEvent = sdkEvent
    }

    /// Records a Flow or survey in the screen's seen content as its renderer is handed to UIKit, so the fake
    /// reload carries no content of its own; a walked segment records its Flow's id. Previews and NPS record nothing.
    private func recordExperienceShown(_ operation: Operation) {
        assertOnQueue()
        guard operation.trigger != .preview else { return }
        switch operation.experience {
        case .flow(let flow, let segment): analytics.experiencePublished(.flow, segment?.flowId ?? flow.id)
        case .survey(let survey): analytics.experiencePublished(.survey, survey.id)
        case .nps, nil: break
        }
    }

    /// Capture the selected link before dismissal. An old or closing renderer cannot replace it.
    func setCompletionDeepLink(_ deepLink: String?, rendererID: UUID?) {
        guard let rendererID, let shown = reads.value.presentation, shown.id == rendererID else { return }
        onPresentation(shown) { _, operation in
            guard case .visible = operation.phase else { return }
            operation.completionDeepLink = deepLink.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        }
    }

    /// Final removal starts the navigation delay; logout still invalidates the outgoing user's link.
    private func openCompletionDeepLink(_ operation: Operation) {
        guard let url = operation.completionDeepLink else { return }
        operation.completionDeepLink = nil
        let expectedGeneration = operation.generation
        delay(Constants.Theme.delayTimeForDeepLink) { [weak self] in
            guard let self, self.generation.value == expectedGeneration else { return }
            self.links.handleURL(url)
        }
    }
}

#if DEBUG
extension ExperiencesPublisher {
    /// Test-thread barrier; the optional action orders submissions before the queue drains again.
    /// Never call from the owner queue.
    func mockWaitForQueue(_ action: () -> Void = {}) {
        experienceQueue.sync(execute: action)
    }

    /// Set on main before delivering events so tests control when display and thank-you delays fire.
    /// SDK-driven closes then skip `screenTransitionCloseDelay` unless `sdkCloseDelay` says otherwise.
    func mockSetDelayUtils(_ delayUtils: DelayUtils, sdkCloseDelay: TimeInterval = 0) {
        assertOnMain()
        self.delayUtils = delayUtils
        self.sdkCloseDelay = sdkCloseDelay
    }
}
#endif

// swiftlint:enable file_length
