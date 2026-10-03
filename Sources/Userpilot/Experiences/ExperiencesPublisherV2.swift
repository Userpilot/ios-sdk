//
//  ExperiencesPublisherV2.swift
//  Userpilot SDK
//
//  Created on 02/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Registered for ExperiencesPublishing in `Userpilot.initializeContainer()` in place of
//  `ExperiencesPublisher`, which stays in the target as the fallback.
//  [Brief Description]
//  Coordinates when backend-selected experiences (flows, surveys, NPS) may use the UI. One operation
//  owns the UI from acceptance to final dismissal; any other content arriving meanwhile is dropped.
//  Only a QR preview interrupts it: it cancels preparation or dismisses the UI, then takes over.
//

// swiftlint:disable file_length
import Foundation
import UIKit

/// `experienceQueue` owns orchestration state; main owns UIKit and renderer references.
/// Synchronous queries read the `reads` snapshot, so neither thread ever waits on the other.
/// The backend selects eligible content; the once-per-screen NPS limit is the only local presentation rule.
internal final class ExperiencesPublisherV2: ExperiencesPublishing, SocketSubscription {

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
    /// keeps admission closed. Only its immutable `id` crosses to main.
    private final class Operation {
        let id = UUID()
        let trigger: Trigger
        /// Manual request token, matched against the content reply.
        let requestID: String?
        var content: ExperienceContent?
        var phase: Phase = .content
        var needsThankYou = false
        /// Screen changes, logout, and preview replacement skip the post-dismissal fake reload.
        var refreshAfterDismissal = true
        /// Decides the post-dismissal fake reload; receiving it does not release ownership.
        var closeEvent: SDKEvent?

        init(trigger: Trigger, requestID: String? = nil, content: ExperienceContent? = nil) {
            self.trigger = trigger
            self.requestID = requestID
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
        var operationID: UUID?
        var isPreview = false
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

    /// The renderer main presented for an operation.
    private struct Presentation {
        let operationID: UUID
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
    private var presentation: Presentation?
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

    /// Entry point for every external mutation and service callback.
    private func onQueue(_ action: @escaping (ExperiencesPublisherV2) -> Void) {
        experienceQueue.async { [weak self] in
            guard let self else { return }
            tryCatch { action(self) }
        }
    }

    /// Runs inline when already on main; otherwise hops asynchronously.
    private func onMain(_ action: @escaping (ExperiencesPublisherV2) -> Void) {
        if Thread.isMainThread {
            action(self)
        } else {
            performOn(.main) { [weak self] in
                guard let self else { return }
                action(self)
            }
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
            state.operationID = operation?.id
            state.isPreview = operation?.trigger == .preview
            state.isVisible = false
            if let operation, case .visible = operation.phase { state.isVisible = true }
            state.needsThankYou = operation?.needsThankYou == true
            return state
        }
    }

    var getCurrentScreen: String { reads.value.screen }

    /// Read by renderer view models; stays available through thank-you and dismissal.
    func getActiveMobileContent() -> ExperienceContent? { reads.value.content }

    /// Asked by a list survey after it dismisses: true continues to its thank-you screen.
    func hasNextFlowStep() -> Bool { reads.value.needsThankYou }

    /// Analytics' gate for repeat screen requests: idle, and at least one second after a close event.
    func canRequestScreenEvent() -> Bool {
        let state = reads.value
        return !state.busy && (state.suppressScreenUntil.map { DispatchTime.now() >= $0 } ?? true)
    }
}

// MARK: - Admission

extension ExperiencesPublisherV2 {

    /// Manual API entry. Claims ownership before requesting content; dropped while busy.
    func triggerExperience(_ experienceId: String) {
        onQueue { publisher in
            guard publisher.current == nil, !publisher.isPreviewing else {
                publisher.logger.info("Manual experience dropped - another experience is in progress")
                return
            }
            let operation = Operation(trigger: .manual, requestID: experienceId)
            publisher.current = operation
            publisher.publishReadState()
            publisher.analytics.publishInternalSDKEvent(ExperienceContentEvent(experienceId: experienceId))
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
        let operation = Operation(trigger: .automatic, content: content)
        current = operation
        publishReadState()
        prepare(operation)
    }

    /// Socket push carrying track-triggered content.
    func onNewMessage(_ message: Message) {
        onQueue { publisher in
            guard !publisher.isPreviewing,
                  let payload = message.payload["payload"] as? [String: Any],
                  payload.keys.contains("request_id"), payload["request_id"] as? Int == nil,
                  let response = payload.toJSONString(),
                  let content = publisher.candidates(response).first else { return }
            publisher.accept(content)
        }
    }

    /// Socket replies. Content/theme replies continue the current operation, even while busy.
    func onSocketEventSent(_ eventName: String, _ payload: Payload, _ message: Message, _ eventSent: Bool) {
        onQueue { publisher in
            guard !publisher.isPreviewing else { return }
            switch eventName {
            case SDKEventsName.fetchExperienceTheme.rawValue:
                publisher.receiveTheme(payload, message, success: eventSent)
            case SDKEventsName.fetchExperienceContent.rawValue:
                publisher.receiveManualContent(payload, message, success: eventSent)
            case Constants.Event.screenEvent:
                publisher.receiveScreen(payload, message, success: eventSent)
            default:
                break
            }
        }
    }

    /// Admits a screen reply unless the user already left that screen; its content would
    /// otherwise appear on the new one.
    private func receiveScreen(_ payload: Payload, _ message: Message, success: Bool) {
        assertOnQueue()
        guard success, let response = message.payload.toJSONString(),
              let content = candidates(response).first else { return }
        if let sentScreen = payload?[Constants.Analytics.screenTitleProperty] as? String,
           sentScreen != getCurrentScreen {
            logger.info("Screen response ignored - the screen has changed")
            return
        }
        accept(content)
    }

    /// Continues the current manual fetch. A failed or empty reply releases the gate.
    /// Replies carry the requested ID, not request identity; see the .md before integration.
    private func receiveManualContent(_ payload: Payload, _ message: Message, success: Bool) {
        assertOnQueue()
        guard let operation = current, operation.trigger == .manual,
              case .content = operation.phase,
              payload?["mobile_content_token"] as? String == operation.requestID else { return }
        guard success, let response = message.payload.toJSONString(),
              let content = candidates(response).first else {
            logger.info("Manual experience request returned no content")
            finish(operation)
            return
        }
        operation.content = content
        publishReadState()
        prepare(operation)
    }

    /// Continues the operation waiting for this theme. A failed reply releases the gate.
    private func receiveTheme(_ payload: Payload, _ message: Message, success: Bool) {
        assertOnQueue()
        guard let operation = current, case .theme(let themeID) = operation.phase,
              payload?["theme_id"] as? Int == themeID else { return }
        guard success, let theme = message.payload.toJSONString()?.toMobileTheme(), theme.id == themeID else {
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

extension ExperiencesPublisherV2 {

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
        analytics.publishInternalSDKEvent(ThemeContentEvent(themeId: themeID, token: config.token))
    }

    private func schedulePresentation(_ operation: Operation) {
        guard let content = operation.content else { finish(operation); return }
        schedule(operation, after: resolvedDelay(content)) { $0.openExperience($1) }
    }

    /// One delay at a time (initial display or thank-you). DelayUtils fires on main, so the action
    /// returns to the queue and runs only if this operation is still current and waiting.
    private func schedule(
        _ operation: Operation,
        after interval: TimeInterval,
        action: @escaping (ExperiencesPublisherV2, Operation) -> Void
    ) {
        assertOnQueue()
        operation.phase = .delay
        publishReadState()
        delayUtils.delayAction(delayTime: interval) { [weak self, weak operation] in
            self?.onQueue { publisher in
                guard let operation, publisher.current === operation,
                      case .delay = operation.phase else { return }
                action(publisher, operation)
            }
        }
    }

    /// Do not repeat NPS within the same screen visit, even if the backend returns it again.
    private func isSuppressedNPS(_ content: ExperienceContent) -> Bool {
        content.asNPSContent() != nil && npsShownOnCurrentScreen
    }

    /// Survey/NPS configured delay, falling back to the default for flows and non-positive values.
    private func resolvedDelay(_ content: ExperienceContent) -> TimeInterval {
        let configured = content.asSurveyContent()?.delayDuration ?? content.asNPSContent()?.delayDuration ?? 0
        return configured > 0 ? configured : ThemeHandler.DefaultValues.delayTimeForExperience
    }
}

// MARK: - Renderers

extension ExperiencesPublisherV2 {

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

    private func openFlow(_ flow: FlowContent, _ operation: Operation) {
        switch flow.type {
        case .carousel:
            showExperience(operation, makeViewModel: ExperienceViewModel.init,
                           makeViewController: CarouselExperienceViewController.init, style: .fullScreen)
        case .slideout where isBottomSheet(flow):
            showExperience(operation, makeViewModel: ExperienceViewModel.init,
                           makeViewController: SlideOutBottomSheetViewController.init, style: .bottomSheet)
        case .slideout:
            showExperience(operation, makeViewModel: ExperienceViewModel.init,
                           makeViewController: SlideOutDialogViewController.init, style: .dialog)
        }
    }

    private func openSurvey(_ survey: SurveyContent, _ operation: Operation) {
        switch survey.type {
        case .list:
            showExperience(operation, makeViewModel: SurveyViewModel.init,
                           makeViewController: SurveyListViewController.init, style: .fullScreen)
        case .step where isBottomSheet(survey):
            showExperience(operation, makeViewModel: SurveyViewModel.init,
                           makeViewController: SurveyBottomSheetViewController.init, style: .bottomSheet)
        case .step:
            showExperience(operation, makeViewModel: SurveyViewModel.init,
                           makeViewController: SurveyDialogViewController.init, style: .dialog)
        }
    }

    /// Theme data decides first; otherwise the cached theme does.
    private func isBottomSheet(_ flow: FlowContent) -> Bool {
        if let themeData = flow.mobileTheme.themeData {
            return themeData.general?.contentAlignment == .bottom
        }
        return themes.getThemeById(flow.mobileTheme.id)?.isDialogExperience == false
    }

    private func isBottomSheet(_ survey: SurveyContent) -> Bool {
        if let position = survey.surveyTheme.themeData?.general?.position {
            return position == .bottom
        }
        return themes.getThemeById(survey.surveyTheme.id)?.isDialogSurvey == false
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
        enqueuePresentation(operation, style: style) { publisher in
            guard let container = publisher.container else { return nil }
            return makeViewController(makeViewModel(container))
        }
    }

    /// Marks the operation visible, then hands creation to main with only immutable values.
    /// Cancelling a visible operation waits for main to skip or dismiss its renderer.
    private func enqueuePresentation(
        _ operation: Operation,
        style: PresentationStyle,
        makeController: @escaping (ExperiencesPublisherV2) -> UIViewController?
    ) {
        assertOnQueue()
        operation.phase = .visible
        publishReadState()
        let operationID = operation.id
        let screen = getCurrentScreen
        onMain { publisher in
            publisher.presentOnMain(operationID, screen: screen, style: style, makeController: makeController)
        }
    }

    /// Skips a cancelled handoff, clears a preview error alert, then builds and presents the renderer.
    /// If nothing can be shown, reports completion so the queue releases ownership.
    private func presentOnMain(
        _ operationID: UUID,
        screen: String,
        style: PresentationStyle,
        makeController: @escaping (ExperiencesPublisherV2) -> UIViewController?
    ) {
        assertOnMain()
        let state = reads.value
        guard state.isVisible, state.operationID == operationID else { return }
        if let alert = previewErrorAlert {
            previewErrorAlert = nil
            alert.dismiss(animated: false) { [weak self] in
                self?.presentOnMain(operationID, screen: screen, style: style, makeController: makeController)
            }
            return
        }
        guard let host = presentationHost(), host.presentedViewController == nil,
              let controller = makeController(self) else {
            logger.info("Experience not shown - no free presentation host")
            didDismissOnMain(operationID)
            return
        }
        presentation = Presentation(operationID: operationID, controller: controller)
        onQueue { publisher in
            guard let operation = publisher.current, operation.id == operationID,
                  operation.content?.asNPSContent() != nil, publisher.getCurrentScreen == screen else { return }
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

    /// Called by a list survey after its own dismissal. The operation stays current across the
    /// handoff, so no other content can be admitted between the survey and its thank-you screen.
    func showThankYouMessage(_ survey: SurveyContent, _ theme: SurveyTheme, _ submissionId: Int64) {
        onMain { publisher in
            guard let shown = publisher.presentation, shown.controller?.presentingViewController == nil else { return }
            let operationID = shown.operationID
            publisher.presentation = nil
            publisher.onQueue { publisher in
                guard let operation = publisher.current, operation.id == operationID,
                      operation.needsThankYou, operation.content?.asSurveyContent()?.id == survey.id else { return }
                operation.needsThankYou = false
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
        let operationID = operation.id
        let fromPreview = operation.trigger == .preview
        enqueuePresentation(operation, style: .bottomSheet) { publisher in
            let controller = ThankYouBottomSheetViewController(surveyContent: survey, surveyTheme: theme)
            controller.actionButtonClicked = { [weak publisher] deepLink in
                publisher?.onQueue { publisher in
                    let completed = ExperienceSurveyCompletedEvent(
                        surveyId: survey.id, submissionId: submissionID, hasDeepLinkContent: deepLink != nil
                    )
                    publisher.publishEvent(completed, operationID: operationID, fromPreview: fromPreview)
                    delay(ThemeHandler.DefaultValues.delayTimeForExperience) { [weak publisher] in
                        if let deepLink, let url = URL(string: deepLink) { publisher?.triggerDeepLink(url: url) }
                    }
                }
            }
            controller.onDismissCompleted = { [weak publisher] in
                publisher?.onMain { $0.didDismissOnMain(operationID) }
            }
            return controller
        }
    }
}

// MARK: - Final dismissal and cancellation

extension ExperiencesPublisherV2 {

    /// Renderers call this after UIKit dismissal. It carries no renderer ID, so the main-owned
    /// presentation is captured here and ignored while its renderer is still presented.
    func experienceDidFinishDismissing() {
        onMain { publisher in
            guard let shown = publisher.presentation, shown.controller?.presentingViewController == nil else { return }
            publisher.didDismissOnMain(shown.operationID)
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
        operation.refreshAfterDismissal = refresh
        operation.needsThankYou = false
        switch operation.phase {
        case .dismissing:
            publishReadState()
        case .visible:
            operation.phase = .dismissing
            publishReadState() // Invalidates presentation work that main has not started yet.
            let operationID = operation.id
            onMain { $0.dismissOnMain(operationID, manualClose: manualClose) }
        default:
            finish(operation)
        }
    }

    /// Dismisses this operation's renderer. A natural dismissal already running reports through
    /// the renderer's own callback; the operation stays busy until dismissal is confirmed.
    private func dismissOnMain(_ operationID: UUID, manualClose: Bool) {
        assertOnMain()
        guard let shown = presentation, shown.operationID == operationID,
              let renderer = shown.controller, renderer.presentingViewController != nil else {
            didDismissOnMain(operationID)
            return
        }
        guard !renderer.isBeingDismissed else { return }
        let completed: () -> Void = { [weak self] in
            self?.onMain { $0.didDismissOnMain(operationID) }
        }
        if let experience = renderer as? UPExperience {
            experience.triggerCloseExperience(manualClose: manualClose, completion: completed)
        } else if let sheet = renderer as? BottomSheetViewController {
            sheet.dismissBottomSheet(completion: completed)
        } else {
            renderer.dismiss(animated: true, completion: completed)
        }
    }

    /// Releases the matching renderer reference, then reports its ID; a stale ID cannot end a newer operation.
    private func didDismissOnMain(_ operationID: UUID) {
        assertOnMain()
        if presentation?.operationID == operationID { presentation = nil }
        onQueue { publisher in
            guard let operation = publisher.current, operation.id == operationID else { return }
            publisher.finish(operation)
        }
    }

    /// Terminal step: releases ownership, starts a waiting preview, otherwise sends the fake reload
    /// the close event asked for. Duplicate or stale calls are harmless.
    private func finish(_ operation: Operation) {
        assertOnQueue()
        guard current === operation else { return }
        delayUtils.cancelDelay()
        current = nil
        publishReadState()
        onMain { $0.userpilot?.existingExperienceOverlayWindow?.hideIfIdle() }
        startWaitingPreview()
        guard current == nil, operation.refreshAfterDismissal,
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

    /// Publishes the name immediately (analytics reads it synchronously), then on the queue resets
    /// the NPS limit and closes normal UI. Preview survives navigation.
    func updateScreen(_ screenName: String) {
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
        onQueue { publisher in
            publisher.replacementPreview = nil
            publisher.npsShownOnCurrentScreen = false
            publisher.closeCurrent(manualClose: true, refresh: false)
        }
    }
}

// MARK: - Preview owns admission from the scan through final dismissal

extension ExperiencesPublisherV2 {

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
        let operation = Operation(trigger: .preview)
        current = operation
        publishReadState()
        remote.fetchPreviewExperience(
            params: PreviewExperienceQueryParams(
                baseUrl: Environment.getExperienceContentUrl(), appToken: config.token,
                contentType: request.contentType, contentId: request.experienceID
            )
        ) { [weak self, weak operation] result in
            self?.onQueue { publisher in
                guard let operation, publisher.current === operation else { return }
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
                    publisher.finish(operation)
                    publisher.onMain { $0.showPreviewError(error.localizedDescription) }
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

extension ExperiencesPublisherV2 {

    /// Renderer analytics are always forwarded, except from a preview, even after their operation
    /// ended. The snapshot only decides which operation a close event belongs to.
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent) {
        let state = reads.value
        onQueue { $0.publishEvent(sdkEvent, operationID: state.operationID, fromPreview: state.isPreview) }
    }

    /// A close event starts the screen-request cooldown and records the owning operation's reload
    /// policy. It never releases ownership; final dismissal does.
    private func publishEvent(_ sdkEvent: SDKEvent, operationID: UUID?, fromPreview: Bool) {
        assertOnQueue()
        if !fromPreview {
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
        guard let operation = current, operation.id == operationID else { return }
        operation.closeEvent = sdkEvent
    }

    /// Keeps the existing short delay before LinkOpener handles navigation on main.
    func triggerDeepLink(url: URL) {
        delay(ThemeHandler.DefaultValues.delayTimeForDeepLink) { [weak self] in
            self?.links.handleURL(url)
        }
    }
}

// MARK: - Content selection

extension ExperiencesPublisherV2 {

    /// Decodes supported content in the existing flow → survey → NPS order; callers take the first.
    private func candidates(_ response: String) -> [ExperienceContent] {
        var contents: [ExperienceContent] = []
        if let flow = response.toFlowContent()?.flowContent { contents.append(.flow(content: flow)) }
        if let survey = response.toSurveyContent()?.surveyContent { contents.append(.survey(content: survey)) }
        if let nps = response.toNPSContent()?.npsContent { contents.append(.nps(content: nps)) }
        return contents
    }
}

#if DEBUG
extension ExperiencesPublisherV2 {
    /// Set before delivering events so tests control when display and thank-you delays fire.
    func mockSetDelayUtils(_ delayUtils: DelayUtils) {
        self.delayUtils = delayUtils
    }
}
#endif
// swiftlint:enable file_length
