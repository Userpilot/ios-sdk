//
//  ExperiencesPublisher.swift
//  Userpilot SDK
//
//  Created by Userpilot on 02/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Registered for ExperiencesPublishing in `Userpilot.initializeContainer()`.
//  Coordinates when backend-selected experiences (flows, surveys, NPS) may use the UI. One operation
//  owns the UI from acceptance to final dismissal; any other content arriving meanwhile is dropped.
//  Only a QR preview interrupts it: it cancels preparation or dismisses the UI, then takes over.
//

// swiftlint:disable file_length
import Foundation
import UIKit

/*
 The `ExperiencesPublishing` protocol defines the required methods for managing experiences,
 such as starting the service, retrieving active carousel content, and sending socket requests.
 */
internal protocol ExperiencesPublishing: AnyObject {

    /// Whether the publisher is currently processing a preview experience.

    /// Get current experience
    func getActiveMobileContent() -> ExperienceContent?

    /// Send experience event to backend
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent)

    /// Manually trigger experience
    func triggerExperience(_ experienceId: String)

    /// Preview experience
    func triggerPreviewExperience(_ experienceId: String, _ queryItems: [URLQueryItem])

    /// Updates the current screen used for experience targeting
    func updateScreen(_ screenName: String)

    /// Reports an app screen immediately, independently of analytics delivery.
    func updateScreen(_ event: Event)

    /// The current screen used for experience targeting
    var getCurrentScreen: String { get }

    /// Manually end experience
    func endExperience(manualClose: Bool)

    /// Notify that an experience view finished dismissing
    func experienceDidFinishDismissing()

    /// True when idle and outside the cooldown for a repeat host screen event.
    func canRequestScreenEvent() -> Bool

    /// Try to handle the deep link internally
    func triggerDeepLink(url: URL)

    /// Invalidates callbacks and closes current content without requesting a screen refresh.
    func logout()

    /// Show thank you message
    func showThankYouMessage(_ surveyContent: SurveyContent, _ surveyTheme: SurveyTheme, _ submissionId: Int64)

    /// True while the running flow still owes a step, so its experience is not finished.
    func hasNextFlowStep() -> Bool

    /// Renderers capture this identity at construction and return it with every callback.
    var activeRendererID: UUID? { get }
    func getActiveMobileContent(rendererID: UUID?) -> ExperienceContent?
    func hasNextFlowStep(rendererID: UUID?) -> Bool
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent, rendererID: UUID?)
    func experienceDidFinishDismissing(rendererID: UUID?)
    func showThankYouMessage(
        _ survey: SurveyContent, _ theme: SurveyTheme, _ submissionId: Int64, rendererID: UUID?
    )

}

/// Default overloads preserve the basic contract for service substitutes.
extension ExperiencesPublishing {
    func updateScreen(_ event: Event) {
        guard event.isFakeReload == nil, let screenName = event.screenTitle else { return }
        updateScreen(screenName)
    }

    var activeRendererID: UUID? { nil }
    func getActiveMobileContent(rendererID: UUID?) -> ExperienceContent? { getActiveMobileContent() }
    func hasNextFlowStep(rendererID: UUID?) -> Bool { hasNextFlowStep() }
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent, rendererID: UUID?) { publishInternalSDKEvent(sdkEvent) }
    func experienceDidFinishDismissing(rendererID: UUID?) { experienceDidFinishDismissing() }
    func showThankYouMessage(
        _ survey: SurveyContent, _ theme: SurveyTheme, _ submissionId: Int64, rendererID: UUID?
    ) {
        showThankYouMessage(survey, theme, submissionId)
    }
}

/// `experienceQueue` owns orchestration state; main owns UIKit and renderer references.
/// Synchronous queries read the `reads` snapshot, so neither thread ever waits on the other.
/// The backend selects eligible content; the once-per-screen NPS limit is the only local presentation rule.
internal final class ExperiencesPublisher: ExperiencesPublishing, SocketSubscription {

    /// Where an operation came from. Manual fetches match their own reply; preview suppresses analytics.
    private enum Trigger {
        case automatic, manual, preview
    }

    /// Preparation steps of the one accepted operation, not separate admission gates.
    private enum Phase {
        case content
        case theme(Int)
        case delay
        case visible
        case dismissing
    }

    /// One accepted experience, including a survey's thank-you screen. Holding it as `current`
    /// keeps admission closed. Main receives its presentation, never its mutable state.
    private final class Operation {
        let trigger: Trigger
        let generation: UUID
        var presentation: Presentation?
        let isCancelled = AtomicReference(false)
        var content: ExperienceContent?
        var phase: Phase = .content
        var needsThankYou = false
        /// Screen changes, logout, and preview replacement skip the post-dismissal fake reload.
        var refreshAfterDismissal = true
        /// Decides the post-dismissal fake reload; receiving it does not release ownership.
        var closeEvent: SDKEvent?

        init(trigger: Trigger, generation: UUID, content: ExperienceContent? = nil) {
            self.trigger = trigger
            self.generation = generation
            self.content = content
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
        var content: ExperienceContent?
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
        case fullScreen, dialog, bottomSheet
    }

    /// One UI presentation. The ID crosses the ViewModel boundary; only main touches the controller.
    private final class Presentation {
        let id = UUID()
        weak var controller: UIViewController?
    }

    private weak var container: DIContainer?
    private weak var userpilot: Userpilot?
    private let analytics: AnalyticsPublishing
    private let remote: UserpilotRemoteSourcing
    private let themes: ThemeHandling
    private let links: LinkOpening
    private let config: Userpilot.Config
    private let logger: Logging

    private let reads = AtomicReference(ReadState())
    private let generation = AtomicReference(UUID())
    private let experienceQueue = DispatchQueue(
        label: Constants.DispatchQueues.experienceQueue,
        qos: .userInteractive
    )

    // Owned by experienceQueue. `current != nil` is the admission gate.
    /// Display and thank-you delays. Its actions fire on main and hop back to the queue.
    private lazy var delayUtils = DelayUtils()
    private var current: Operation?
    private var replacementPreview: PreviewRequest?
    private var npsShownOnCurrentScreen = false

    // Owned by main.
    private weak var previewErrorAlert: UIAlertController?
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
        self.remote = container.resolve(UserpilotRemoteSourcing.self)
        self.themes = container.resolve(ThemeHandling.self)
        self.links = container.resolve(LinkOpening.self)
        self.config = config
        self.logger = config.logger

        let socket: SocketManaging = container.resolve(SocketManaging.self)
        socket.registerCallback(self)
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
            state.content = operation?.content
            state.presentation = operation?.presentation
            state.generation = operation?.generation
            state.isVisible = false
            if let operation, case .visible = operation.phase { state.isVisible = true }
            state.needsThankYou = operation?.needsThankYou == true
            return state
        }
    }

    var getCurrentScreen: String { reads.value.screen }

    /// Captured by each ViewModel at construction; invalidated synchronously by logout.
    var activeRendererID: UUID? {
        let state = reads.value
        return state.generation == generation.value ? state.presentation?.id : nil
    }

    func getActiveMobileContent() -> ExperienceContent? {
        getActiveMobileContent(rendererID: activeRendererID)
    }

    /// Return content only to the current presentation and user generation, including during dismissal.
    func getActiveMobileContent(rendererID: UUID?) -> ExperienceContent? {
        let state = reads.value
        guard rendererID != nil, state.presentation?.id == rendererID,
              state.generation == generation.value else { return nil }
        return state.content
    }

    func hasNextFlowStep() -> Bool { hasNextFlowStep(rendererID: activeRendererID) }

    /// A matching survey renderer may continue to thank-you without releasing the experience gate.
    func hasNextFlowStep(rendererID: UUID?) -> Bool {
        let state = reads.value
        return rendererID != nil && state.presentation?.id == rendererID
            && state.generation == generation.value && state.needsThankYou
    }

    /// Recheck after asynchronous work: reference identity rejects replacement, generation rejects logout.
    private func owns(_ operation: Operation) -> Bool {
        current === operation && operation.generation == generation.value
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
    func canRequestScreenEvent() -> Bool {
        let state = reads.value
        return !state.busy && (state.suppressScreenUntil.map { DispatchTime.now() >= $0 } ?? true)
    }
}

// MARK: - Admission

extension ExperiencesPublisher {

    /// Manual API entry. Claims ownership before requesting content; dropped while busy.
    func triggerExperience(_ experienceId: String) {
        guard !reads.value.busy else { return }
        onQueue { publisher in
            guard publisher.current == nil, !publisher.isPreviewing else {
                publisher.logger.info("Manual experience dropped - another experience is in progress")
                return
            }
            let operation = Operation(trigger: .manual, generation: publisher.generation.value)
            publisher.current = operation
            publisher.publishReadState()
            publisher.request(ExperienceContentEvent(experienceId: experienceId), for: operation)
        }
    }

    /// Admits backend-selected screen or track content. Idle starts preparation; busy drops it.
    private func accept(_ content: ExperienceContent) {
        assertOnQueue()
        guard !isPreviewing else { return }
        guard !isSuppressedNPS(content) else {
            logger.info("NPS suppressed - already shown on the current screen")
            return
        }
        guard current == nil else {
            logger.info("Experience dropped - another experience is in progress")
            return
        }
        let operation = Operation(trigger: .automatic, generation: generation.value, content: content)
        current = operation
        publishReadState()
        prepare(operation)
    }

    /// Socket push carrying track-triggered content.
    func onNewMessage(_ message: Message) {
        guard !reads.value.busy else { return }
        onQueue { publisher in
            guard !publisher.isPreviewing,
                  let payload = message.payload["payload"] as? [String: Any],
                  payload.keys.contains("request_id"), payload["request_id"] as? Int == nil,
                  let response = payload.toJSONString(),
                  let content = response.experienceCandidates(logger: publisher.logger).first else { return }
            publisher.accept(content)
        }
    }

    /// Screen replies remain shared notifications; content/theme requests own their completions.
    func onSocketEventSent(_ eventName: String, _ payload: Payload, _ message: Message, _ eventSent: Bool) {
        guard eventName == Constants.Event.screenEvent, !reads.value.busy else { return }
        onQueue { publisher in
            guard !publisher.isPreviewing else { return }
            publisher.receiveScreen(payload, message, success: eventSent)
        }
    }

    /// Admits a screen reply unless the user already left that screen; its content would
    /// otherwise appear on the new one.
    private func receiveScreen(_ payload: Payload, _ message: Message, success: Bool) {
        assertOnQueue()
        guard success, let response = message.payload.toJSONString(),
              let content = response.experienceCandidates(logger: logger).first else { return }
        if let sentScreen = payload?[Constants.Analytics.screenTitleProperty] as? String,
           sentScreen != getCurrentScreen {
            logger.info("Screen response ignored - the screen has changed")
            return
        }
        accept(content)
    }

    /// Continues the current manual fetch. A failed or empty reply releases the gate.
    /// Equal content tokens from an older request cannot release this operation.
    private func receiveManualContent(_ operation: Operation, _ message: Message, success: Bool) {
        assertOnQueue()
        guard operation.trigger == .manual, case .content = operation.phase else { return }
        guard success, let response = message.payload.toJSONString(),
              let content = response.experienceCandidates(logger: logger).first else {
            logger.info("Manual experience request returned no content")
            finish(operation)
            return
        }
        operation.content = content
        publishReadState()
        prepare(operation)
    }

    /// Continues the operation waiting for this theme. A failed reply releases the gate.
    private func receiveTheme(_ operation: Operation, _ message: Message, success: Bool) {
        assertOnQueue()
        guard case .theme(let themeID) = operation.phase else { return }
        guard success, let theme = message.payload.toJSONString()?.toMobileTheme(logger: logger),
              theme.id == themeID else {
            logger.info("Experience dropped - theme request failed")
            finish(operation)
            return
        }
        themes.saveTheme(theme)
        schedulePresentation(operation)
    }

    /// Socket loss abandons preparation still waiting for a content/theme reply.
    /// Delayed or visible UI and HTTP-based preview work continue.
    func onSocketClosed() {
        onQueue { publisher in
            guard let operation = publisher.current, operation.trigger != .preview else { return }
            switch operation.phase {
            case .content, .theme:
                publisher.finish(operation)
            default:
                break
            }
        }
    }
}

// MARK: - Preparation

extension ExperiencesPublisher {

    /// NPS and cached themes go straight to the display delay; otherwise request the one missing theme.
    private func prepare(_ operation: Operation) {
        assertOnQueue()
        guard let content = operation.content else {
            finish(operation)
            return
        }
        guard !isSuppressedNPS(content) else {
            logger.info("NPS suppressed - already shown on the current screen")
            finish(operation)
            return
        }
        if content.asNPSContent() != nil || themes.getThemeById(content.experienceThemeId()) != nil {
            schedulePresentation(operation)
            return
        }
        guard analytics.canRequestEvent else {
            logger.info("Experience dropped - socket unavailable to fetch its theme")
            finish(operation)
            return
        }
        let themeID = content.experienceThemeId()
        operation.phase = .theme(themeID)
        request(ThemeContentEvent(themeId: themeID, token: config.token), for: operation)
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
                    publisher.receiveManualContent(operation, message, success: success)
                } else {
                    publisher.receiveTheme(operation, message, success: success)
                }
            }
        })
    }

    /// Apply this content's display delay; the scheduled continuation rechecks operation ownership.
    private func schedulePresentation(_ operation: Operation) {
        guard let content = operation.content else { finish(operation); return }
        schedule(operation, after: content.resolvedDelay()) { $0.openExperience($1) }
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
    private func isSuppressedNPS(_ content: ExperienceContent) -> Bool {
        content.asNPSContent() != nil && npsShownOnCurrentScreen
    }
}

// MARK: - Renderers

extension ExperiencesPublisher {

    /// Picks the existing renderer and presentation style. UIKit work happens later on main.
    private func openExperience(_ operation: Operation) {
        guard let content = operation.content else { finish(operation); return }
        switch content {
        case .flow(let flow):
            openFlow(flow, operation)
        case .survey(let survey):
            openSurvey(survey, operation)
        case .nps:
            showExperience(operation, makeViewModel: NPSViewModel.init,
                           makeViewController: NPSBottomSheetViewController.init, style: .bottomSheet)
        }
    }

    /// Choose the flow's carousel or themed slideout renderer; creation remains on main.
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
        }
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
        guard let content = operation.content else {
            finish(operation)
            return
        }
        if let survey = content.asSurveyContent(), survey.type == .list,
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
        let shown = Presentation()
        operation.presentation = shown
        operation.phase = .visible
        publishReadState()
        let screen = getCurrentScreen
        onMain { publisher in
            publisher.presentOnMain(shown, screen: screen, style: style, makeController: makeController)
        }
    }

    /// Skips a cancelled handoff, clears a preview error alert, then builds and presents the renderer.
    /// If nothing can be shown, reports completion so the queue releases ownership.
    private func presentOnMain(
        _ shown: Presentation,
        screen: String,
        style: PresentationStyle,
        makeController: @escaping (ExperiencesPublisher, Presentation) -> UIViewController?
    ) {
        assertOnMain()
        let state = reads.value
        guard state.isVisible, state.presentation === shown,
              state.generation == generation.value else { return }
        if let alert = previewErrorAlert {
            previewErrorAlert = nil
            alert.dismiss(animated: false) { [weak self] in
                self?.presentOnMain(shown, screen: screen, style: style, makeController: makeController)
            }
            return
        }
        guard let host = presentationHost(), host.presentedViewController == nil,
              let controller = makeController(self, shown) else {
            logger.info("Experience not shown - no free presentation host")
            didDismissOnMain(shown)
            return
        }
        shown.controller = controller
        onPresentation(shown) { publisher, operation in
            guard operation.content?.asNPSContent() != nil,
                  publisher.getCurrentScreen == screen else { return }
            publisher.npsShownOnCurrentScreen = true
        }
        switch style {
        case .fullScreen:
            controller.modalPresentationStyle = .fullScreen
            host.present(controller, animated: true)
        case .dialog:
            host.presentDialog(viewController: controller)
        case .bottomSheet:
            host.presentBottomSheet(viewController: controller)
        }
    }

    /// This SDK instance's overlay root, or the provider's controller when no overlay exists.
    private func presentationHost() -> UIViewController? {
        assertOnMain()
        if let overlay = userpilot?.experienceOverlayWindow {
            overlay.prepareForPresentation()
            return overlay.rootViewController
        }
        return topViewControllerProvider()
    }

    /// Legacy calls without a renderer identity cannot continue whichever survey is current.
    func showThankYouMessage(_ survey: SurveyContent, _ theme: SurveyTheme, _ submissionId: Int64) {
        showThankYouMessage(survey, theme, submissionId, rendererID: nil)
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
                      operation.content?.asSurveyContent()?.id == survey.id else { return }
                operation.needsThankYou = false
                operation.presentation = nil
                let interval = ThemeHandler.DefaultValues.delayTimeForExperience
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
                    let expectedGeneration = operation.generation
                    let completed = ExperienceSurveyCompletedEvent(
                        surveyId: survey.id, submissionId: submissionID, hasDeepLinkContent: deepLink != nil
                    )
                    publisher.publishEvent(completed, operation: operation)
                    delay(ThemeHandler.DefaultValues.delayTimeForExperience) { [weak publisher] in
                        guard let publisher, publisher.generation.value == expectedGeneration else { return }
                        if let deepLink, let url = URL(string: deepLink) { publisher.triggerDeepLink(url: url) }
                    }
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

    /// Uncorrelated legacy callbacks cannot claim whichever renderer happens to be current.
    func experienceDidFinishDismissing() { experienceDidFinishDismissing(rendererID: nil) }

    /// Accept dismissal only for the named presentation after UIKit has detached its controller.
    /// A completed/dismissed analytics event alone cannot release the operation or request the next content.
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

    /// Work not yet handed to main finishes immediately; a handed-off renderer keeps ownership until main
    /// confirms it is gone. Repeated calls never start a second dismissal.
    private func closeCurrent(manualClose: Bool, refresh: Bool) {
        assertOnQueue()
        delayUtils.cancelDelay()
        guard let operation = current else { startWaitingPreview(); return }
        operation.isCancelled.value = true
        operation.refreshAfterDismissal = refresh
        operation.needsThankYou = false
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

    /// Dismisses this operation's renderer. A natural dismissal already running reports through
    /// the renderer's own callback; the operation stays busy until dismissal is confirmed.
    private func dismissOnMain(_ shown: Presentation, manualClose: Bool) {
        assertOnMain()
        guard let renderer = shown.controller, renderer.presentingViewController != nil else {
            didDismissOnMain(shown)
            return
        }
        guard !renderer.isBeingDismissed else { return }
        let completed: () -> Void = { [weak self] in
            self?.onMain { $0.didDismissOnMain(shown) }
        }
        if let experience = renderer as? UPExperience {
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
            publisher.finish(operation)
        }
    }

    /// Release ownership and start a waiting preview; otherwise enqueue the eligible close event's fake reload.
    /// Generation, reload policy and deep-link checks prevent an outgoing operation from refreshing another context.
    private func finish(_ operation: Operation) {
        assertOnQueue()
        guard current === operation else { return }
        operation.isCancelled.value = true
        delayUtils.cancelDelay()
        current = nil
        publishReadState()
        onMain { $0.userpilot?.existingExperienceOverlayWindow?.hideIfIdle() }
        startWaitingPreview()
        guard current == nil, operation.generation == generation.value, operation.refreshAfterDismissal,
              let close = operation.closeEvent, close.isEventForCloseExperience(), !close.hasDeepLink else { return }
        analytics.publishFakeReloadScreenEvent(close.getContentType(), close.getContentId())
    }

    /// Starts the latest QR request once the outgoing operation has released ownership.
    private func startWaitingPreview() {
        assertOnQueue()
        guard current == nil, let preview = replacementPreview else { return }
        replacementPreview = nil
        beginPreview(preview)
    }

    /// Routes a named screen through the same navigation rules as a full screen event.
    func updateScreen(_ screenName: String) {
        updateScreen(Event(type: .screen(screenName)))
    }

    /// Publishes an app screen immediately, then resets NPS and closes normal UI on the queue.
    /// Repeated titles and generated reloads do not start a new visit; preview survives navigation.
    func updateScreen(_ event: Event) {
        guard event.isFakeReload == nil, let screenName = event.screenTitle else { return }
        var changed = false
        reads.update {
            var state = $0
            changed = state.screen != screenName
            state.screen = screenName
            return state
        }
        guard changed else { return }
        onQueue { publisher in
            // A newer background screen update can overtake this queued transition.
            guard publisher.getCurrentScreen == screenName else { return }
            publisher.npsShownOnCurrentScreen = false
            guard !publisher.isPreviewing else { return }
            publisher.closeCurrent(manualClose: true, refresh: false)
        }
    }

    /// Drops any preview, resets the NPS limit, and closes without a fake reload.
    func logout() {
        generation.value = UUID() // Stop old renderer/service callbacks before asynchronous teardown.
        onQueue(checkGeneration: false) { publisher in
            publisher.replacementPreview = nil
            publisher.npsShownOnCurrentScreen = false
            publisher.closeCurrent(manualClose: true, refresh: false)
            // An idle overlay can outlive its operation; collapse it without constructing a new window.
            publisher.onMain { $0.userpilot?.existingExperienceOverlayWindow?.hideIfIdle() }
        }
    }
}

// MARK: - Preview owns admission from the scan through final dismissal

extension ExperiencesPublisher {

    /// QR entry, the only input that interrupts the current operation. Preparation (content or theme
    /// fetch, display delay) is cancelled at once; a visible renderer finishes dismissing first.
    /// The latest scan wins, including over an older preview.
    func triggerPreviewExperience(_ experienceId: String, _ queryItems: [URLQueryItem]) {
        onQueue { publisher in
            publisher.replacementPreview = PreviewRequest(
                experienceID: experienceId,
                contentType: queryItems.first { $0.name == "type" }?.value ?? ""
            )
            publisher.publishReadState()
            publisher.closeCurrent(manualClose: true, refresh: false)
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
                    let content = preview.flow.map { ExperienceContent.flow(content: $0) }
                        ?? preview.survey.map { ExperienceContent.survey(content: $0) }
                    guard let content, let theme = preview.theme else {
                        publisher.logger.info("Preview dropped - response has no content or theme")
                        publisher.finish(operation)
                        return
                    }
                    operation.content = content
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

    /// Legacy calls without a renderer identity cannot publish for whichever presentation is current.
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent) {
        publishInternalSDKEvent(sdkEvent, rendererID: nil)
    }

    /// Resolve the named presentation, then validate operation ownership on the experience queue.
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent, rendererID: UUID?) {
        guard let rendererID else { return }
        let state = reads.value
        guard let shown = state.presentation, shown.id == rendererID else { return }
        onPresentation(shown) { $0.publishEvent(sdkEvent, operation: $1) }
    }

    /// Close events record reload policy; ownership is released only after UIKit dismissal.
    private func publishEvent(_ sdkEvent: SDKEvent, operation: Operation) {
        assertOnQueue()
        if operation.trigger != .preview {
            analytics.publishInternalSDKEvent(sdkEvent)
            if sdkEvent.isSeenContentEvent(), let id = sdkEvent.getContentId() {
                analytics.experiencePublished(sdkEvent.getContentType(), id)
            }
        }
        guard sdkEvent.isEventForCloseExperience() || sdkEvent.isEventForCloseNPSExperience() else { return }
        reads.update {
            var state = $0
            state.suppressScreenUntil = .now() + 1
            return state
        }
        operation.closeEvent = sdkEvent
    }

    /// Keep the navigation delay on main; logout invalidates a deep link still waiting to run.
    func triggerDeepLink(url: URL) {
        let expectedGeneration = generation.value
        delay(ThemeHandler.DefaultValues.delayTimeForDeepLink) { [weak self] in
            guard let self, self.generation.value == expectedGeneration else { return }
            self.links.handleURL(url)
        }
    }
}

#if DEBUG
extension ExperiencesPublisher {
    /// Test-thread barrier for work already submitted to the owner queue; never call from that queue.
    func mockWaitForQueue() {
        experienceQueue.sync {}
    }

    /// Set before delivering events so tests control when display and thank-you delays fire.
    func mockSetDelayUtils(_ delayUtils: DelayUtils) {
        self.delayUtils = delayUtils
    }
}
#endif
// swiftlint:enable file_length
