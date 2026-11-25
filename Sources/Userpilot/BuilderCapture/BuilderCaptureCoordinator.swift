//
//  BuilderCaptureCoordinator.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owns the QR capture session, capture mode, admitted hosts, confirmation and the upload run.
//

// swiftlint:disable file_length
import UIKit

/// Drives capture mode, which starts only from a QR deep link. Entry points accept any thread and run
/// on main, which owns every session, upload and UI state.
internal protocol BuilderCaptureCoordinating: AnyObject {
    /// Whether this instance owns the process's capture session. Read on main.
    var isActive: Bool { get }
    /// Starts capture mode for a validated link. The same `capture_id` refreshes the token; a different
    /// one replaces the session. A spent `capture_id` shows "QR code already used" instead.
    func start(link: CaptureLink)
    /// A capture link with a missing or invalid value: cancels this instance's capture mode and shows
    /// "Invalid QR code".
    func rejectInvalidLink()
    /// A capture link created for Android: cancels this instance's capture mode and shows "QR code for Android".
    func rejectOtherPlatformLink()
    /// Ends capture mode and spends its `capture_id`: Close, logout and instance teardown.
    func stop()
    /// Takes one capture; it needs an identified user on a tracked screen.
    func capture()
}

/// Owns one Builder session and one capture slot on main, independently of autocapture settings.
/// Capture mode starts only from a QR link and is process-wide (`BuilderCaptureMode`): starting it
/// silently closes the current experience of every instance, and every publisher admits none while it is on.
/// A capture keeps its admitted host through experience dismissal, snapshotting and confirmation;
/// Save encodes it in memory and uploads it in one retry run.
internal final class BuilderCaptureCoordinator: BuilderCaptureCoordinating {

    /// Reserves the capture slot before any asynchronous experience dismissal.
    fileprivate final class Capture {
        let session: CaptureSession
        let host: ElementTargetHost
        /// The last screen event when Capture was tapped; the document's `screen`.
        let screen: ScreenPayload

        init(session: CaptureSession, host: ElementTargetHost, screen: ScreenPayload) {
            self.session = session
            self.host = host
            self.screen = screen
        }
    }

    /// One confirmed capture from Save until saved, Cancel, OK, stop or replacement. Main-confined.
    fileprivate final class PendingUpload {
        let session: CaptureSession
        /// Nil until the encoder has prepared the capture; every attempt and Retry send these bytes.
        var upload: CaptureUpload?
        var request: CaptureUploadCancellable?
        /// The wait before the run's next attempt.
        var retryWork: DispatchWorkItem?
        /// Spans one whole run, waits and retries included.
        let backgroundTask: CaptureUploadBackgroundTasking
        /// Attempts made in the current run, and whether one of them was throttled.
        var attempt = 0
        var throttled = false
        /// Bumped by every send, wait and cancel; a callback from an older step is ignored.
        var step = 0

        init(session: CaptureSession, backgroundTask: CaptureUploadBackgroundTasking) {
            self.session = session
            self.backgroundTask = backgroundTask
        }
    }

    private weak var container: DIContainer?
    private let logger: Logging
    private let targeting: ElementTargeting
    private let snapshotter: ScreenSnapshotting
    private let encoder: CaptureEncoding
    private let remote: UserpilotRemoteSourcing
    private let storage: DataStoring
    private let registry: InstanceRegistering
    private let lifecycleMonitor: LifecycleMonitoring
    private var analytics: AnalyticsPublishing? { container?.resolve(AnalyticsPublishing.self) }
    // The publisher can resolve Builder through deep-link routing; keep that peer deferred.
    private var experiences: ExperiencesPublishing? { container?.resolve(ExperiencesPublishing.self) }
    private var session: CaptureSession?
    private var pending: Capture?
    private var upload: PendingUpload?
    private var captureWindow: BuilderCaptureWindow?
    private weak var buttonController: CaptureFloatingButtonViewController?

    // Replaceable in tests: dialogs, the wait between attempts, background time and the presenter
    // of alerts shown without a capture window.
    var dialogs: CaptureDialogShowing = CaptureUploadDialogs()
    var scheduleRetry: (TimeInterval, DispatchWorkItem) -> Void = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    var makeBackgroundTask: () -> CaptureUploadBackgroundTasking = { CaptureUploadBackgroundTask() }
    var topControllerGetting: TopControllerGetting = UIApplication.shared

    // No deinit teardown: `BuilderCaptureMode.owner` keeps this coordinator alive while its session runs,
    // and the facade's deinit stops that session.
    init(container: DIContainer) {
        self.container = container
        logger = container.resolve(Userpilot.Config.self).logger
        targeting = container.resolve(ElementTargeting.self)
        snapshotter = container.resolve(ScreenSnapshotting.self)
        encoder = container.resolve(CaptureEncoding.self)
        remote = container.resolve(UserpilotRemoteSourcing.self)
        storage = container.resolve(DataStoring.self)
        registry = container.resolve(InstanceRegistering.self)
        lifecycleMonitor = container.resolve(LifecycleMonitoring.self)
    }

    var isActive: Bool { session != nil }

    func start(link: CaptureLink) {
        performOnMain { [weak self] in self?.startOnMain(link) }
    }

    func rejectInvalidLink() {
        rejectLink(showing: .invalidLink)
    }

    func rejectOtherPlatformLink() {
        rejectLink(showing: .otherPlatformLink)
    }

    private func rejectLink(showing alert: CaptureUploadAlert) {
        performOnMain { [weak self] in
            guard let self else { return }
            // Cancels only this instance's session, without spending its capture id.
            if self.session != nil {
                self.endSession(spendingCaptureID: false)
                self.logger.info("📸 Capture mode ended")
            }
            self.showAlert(alert)
        }
    }

    func stop() {
        performOnMain { [weak self] in
            guard let self, self.session != nil else { return }
            self.endSession(spendingCaptureID: true)
            self.logger.info("📸 Capture mode ended")
        }
    }

    func capture() {
        performOnMain { [weak self] in self?.captureOnMain() }
    }
}

// MARK: - Session

private extension BuilderCaptureCoordinator {

    /// One QR code is one capture; one capture session runs in the process.
    func startOnMain(_ link: CaptureLink) {
        guard !BuilderCaptureMode.endedCaptureIDs.contains(link.captureID) else {
            logger.info("📸 Capture link refused: QR code already used")
            showAlert(.linkAlreadyUsed)
            return
        }
        if let session, session.captureID == link.captureID {
            // The credential stays in memory for this session and is sent only as the upload's bearer header.
            session.refresh(with: link)
            logger.info("📸 Capture session refreshed")
            return
        }
        // One session per process: another instance's session is stopped like Close, which spends its id.
        // This instance's older QR code is replaced without spending it.
        if let owner = BuilderCaptureMode.owner, owner !== self { owner.stop() }
        endSession(spendingCaptureID: false)
        guard let host = targeting.admitHost(), let window = host.window else {
            logger.error("📸 Capture failed: no host window")
            return
        }
        session = CaptureSession(link)
        BuilderCaptureMode.begin(self)
        closeExperiencesInEveryInstance()
        presentCaptureButton(in: window)
        lifecycleMonitor.addDelegate(self, replayCurrentState: false)
        logger.info("📸 Capture mode started")
    }

    /// Ends this instance's session: cancels the upload run, removes the capture window with its dialogs
    /// and turns capture mode off. Close, logout, Saved and 401 also spend the capture id.
    func endSession(spendingCaptureID: Bool) {
        guard let session else { return }
        cancelUpload()
        if spendingCaptureID { BuilderCaptureMode.markEnded(session.captureID) }
        self.session = nil
        pending = nil
        BuilderCaptureMode.end(self)
        lifecycleMonitor.removeDelegate(self)
        if let window = captureWindow { Self.tearDown(window) }
        captureWindow = nil
        buttonController = nil
    }

    /// Capture mode closes the current experience of every registered instance, visible or still preparing,
    /// silently like a QR preview: no dismissal, host callback or reload. `BuilderCaptureMode` then keeps
    /// each publisher from admitting or presenting another one.
    func closeExperiencesInEveryInstance() {
        let candidates = [experiences]
            + registry.allInstances.map { $0.container.resolveIfCreated(ExperiencesPublishing.self) }
        var closed = Set<ObjectIdentifier>()
        for publisher in candidates.compactMap({ $0 }) where closed.insert(ObjectIdentifier(publisher)).inserted {
            publisher.closeSilently(completion: nil)
        }
    }

    static func tearDown(_ window: BuilderCaptureWindow) {
        window.rootViewController?.dismiss(animated: false)
        window.isHidden = true
        window.rootViewController = nil
        window.windowScene = nil
    }

    func presentCaptureButton(in hostWindow: UIWindow) {
        let controller = CaptureFloatingButtonViewController(
            onCapture: { [weak self] in self?.capture() },
            onExit: { [weak self] in self?.stop() }
        )
        buttonController = controller
        captureWindow = BuilderCaptureWindow(
            rootViewController: controller, hostWindow: hostWindow, owningInstance: container?.owner
        )
    }

    /// Alerts with nothing left to act on: invalid link, used QR code, "Can't capture yet", Saved and 401.
    /// Their OK changes nothing.
    func showAlert(_ alert: CaptureUploadAlert) {
        let presenter = captureWindow?.rootViewController ?? topControllerGetting.topViewController()
        dialogs.showAlert(alert, from: presenter) { _ in }
    }
}

// MARK: - LifecycleDelegate

extension BuilderCaptureCoordinator: LifecycleDelegate {

    /// Closing the scene that holds the capture controls ends capture mode, so experiences show again.
    /// The QR code is not spent, so the operator can scan it again in another window.
    func onSceneDisconnected(_ scene: UIScene) {
        guard session != nil, scene === captureWindow?.windowScene else { return }
        endSession(spendingCaptureID: false)
        logger.info("📸 Capture mode ended: its window closed")
    }
}

// MARK: - Capture

private extension BuilderCaptureCoordinator {

    /// Reserves the capture slot before waiting for actual experience removal; repeated taps cannot race it.
    func captureOnMain() {
        guard let session else { return }
        guard pending == nil else {
            logger.debug("📸 Capture ignored: confirmation already showing")
            return
        }
        guard upload == nil else {
            logger.debug("📸 Capture ignored: upload in progress")
            return
        }
        guard let screen = trackedScreen else {
            logger.info("📸 Capture refused: no identified user or tracked screen")
            showAlert(.cannotCaptureYet)
            return
        }
        guard let host = targeting.admitHost(), host.window?.windowScene === captureWindow?.windowScene else {
            reportCaptureFailure("no host window")
            return
        }
        let capture = Capture(session: session, host: host, screen: screen)
        pending = capture
        if experiences?.isExperienceVisible == true {
            logger.debug("📸 Dismissing active experience before capturing")
            experiences?.closeSilently { [weak self] in
                performOnMain { [weak self] in self?.performCapture(capture) }
            }
        } else {
            performCapture(capture)
        }
    }

    /// The last screen event, when an identified user is on a screen the SDK tracked.
    var trackedScreen: ScreenPayload? {
        guard storage.userId.isNotEmpty,
              let screen = analytics?.screenSessionStateMachine?.screenPayload,
              screen.title.isNotEmpty else { return nil }
        return screen
    }

    /// Rejects callbacks from an ended session, replaced capture or detached host without selecting a new host.
    func isCurrent(_ capture: Capture) -> Bool {
        session === capture.session && pending === capture && targeting.isValid(capture.host)
    }

    func performCapture(_ capture: Capture) {
        guard isCurrent(capture), let window = capture.host.window else {
            if pending === capture { pending = nil }
            return
        }
        targeting.captureLayout(in: capture.host) { [weak self, weak window] tree in
            guard let self else { return }
            guard self.isCurrent(capture), let window else {
                if self.pending === capture { self.pending = nil }
                return
            }
            guard let tree, let screenshot = self.snapshotter.snapshot(of: window) else {
                self.pending = nil
                self.reportCaptureFailure("could not read the view hierarchy")
                return
            }
            let document = CaptureDocument.make(
                captureID: capture.session.captureID, screenshot: screenshot, elementTree: tree, screen: capture.screen
            )
            self.presentConfirmation(capture, document: document, screenshot: screenshot.image, tree: tree)
        }
    }

    func presentConfirmation(
        _ capture: Capture, document: CaptureDocument, screenshot: UIImage, tree: ElementNode
    ) {
        guard let presenter = captureWindow?.rootViewController, presenter.presentedViewController == nil else {
            pending = nil
            reportCaptureFailure("no presenter for the confirmation sheet")
            return
        }
        let rects = tree.targetableRects()
        buttonController?.setButtonHidden(true)
        dialogs.showConfirmation(
            annotatedScreenshot: screenshot.annotated(with: rects),
            targetableElementCount: rects.count,
            suggestedScreenName: document.displayName,
            from: presenter
        ) { [weak self] outcome in
            guard let self, self.pending === capture else { return }
            let valid = self.isCurrent(capture)
            self.pending = nil
            guard valid else {
                self.buttonController?.setButtonHidden(false)
                return
            }
            switch outcome {
            case let .save(screenName):
                // The button stays hidden until the upload's result is handled.
                self.beginUpload(
                    document: document.named(screenName), screenshot: screenshot, session: capture.session
                )
            case .retry:
                self.buttonController?.setButtonHidden(false)
                self.logger.debug("📸 Capture discarded, retrying")
            case .cancel:
                self.buttonController?.setButtonHidden(false)
                self.logger.debug("📸 Capture cancelled")
            }
        }
    }

    func reportCaptureFailure(_ reason: StaticString) {
        logger.error("📸 Capture failed: %{public}@", "\(reason)")
        buttonController?.showMessage(BuilderCaptureStrings.captureFailedTitle)
    }
}

// MARK: - Upload run

private extension BuilderCaptureCoordinator {

    /// Save: hold the upload slot, show progress, encode off main, then start the first run.
    func beginUpload(document: CaptureDocument, screenshot: UIImage, session: CaptureSession) {
        let pendingUpload = PendingUpload(session: session, backgroundTask: makeBackgroundTask())
        upload = pendingUpload
        dialogs.showProgress(from: captureWindow?.rootViewController)
        // The encoder owns its inputs until encoding finishes.
        encoder.prepareUpload(document: document, screenshot: screenshot) { [weak self] result in
            performOnMain { [weak self] in
                guard let self, self.upload === pendingUpload else { return }
                switch result {
                case let .success(prepared):
                    pendingUpload.upload = prepared
                    self.startRun(pendingUpload)
                // Too large is reported like a 413; anything else could not be encoded. Nothing was sent.
                case .failure(.tooLarge):
                    self.logger.error("📸 Capture upload failed: %{public}@",
                                      CaptureUploadError.tooLarge.logDescription(statusCode: nil, details: nil))
                    self.showUploadAlert(.failure(.tooLarge), for: pendingUpload)
                case .failure:
                    self.logger.error("📸 Capture upload failed: preparationFailed")
                    self.showUploadAlert(.preparationFailed, for: pendingUpload)
                }
            }
        }
    }

    /// One run: at most `CaptureUploadRetryPolicy.maxAttempts` attempts under one background task.
    func startRun(_ pendingUpload: PendingUpload) {
        pendingUpload.attempt = 0
        pendingUpload.throttled = false
        dialogs.showProgress(from: captureWindow?.rootViewController)
        pendingUpload.backgroundTask.begin { [weak self, weak pendingUpload] in
            guard let self, let pendingUpload else { return }
            self.expireBackgroundRun(pendingUpload)
        }
        send(pendingUpload)
    }

    /// One attempt to the environment's capture upload URL with the session's token at send time; a rescan
    /// of the same QR code refreshes the token.
    func send(_ pendingUpload: PendingUpload) {
        guard let prepared = pendingUpload.upload else { return }
        guard let url = URL(string: Environment.getCaptureUploadUrl()) else {
            endRun(pendingUpload)
            logger.error("📸 Capture upload failed: preparationFailed")
            showUploadAlert(.preparationFailed, for: pendingUpload)
            return
        }
        pendingUpload.attempt += 1
        pendingUpload.step += 1
        let step = pendingUpload.step
        let session = pendingUpload.session
        pendingUpload.request = remote.uploadCapture(
            prepared, token: session.token, url: url
        ) { [weak self] result in
            performOnMain { [weak self] in
                guard let self, self.upload === pendingUpload, pendingUpload.step == step else { return }
                pendingUpload.request = nil
                self.didFinishAttempt(pendingUpload, result: result)
            }
        }
    }

    /// Saved ends the run at once; a failure waits for the next attempt or ends the run with its alert.
    func didFinishAttempt(_ pendingUpload: PendingUpload, result: Result<Void, CaptureUploadError>) {
        switch result {
        case .success:
            endRun(pendingUpload)
            finishRun(pendingUpload, with: .saved)
        case let .failure(error):
            guard let delay = CaptureUploadRetryPolicy.nextDelay(
                after: error, attempt: pendingUpload.attempt, throttledAlready: pendingUpload.throttled
            ) else {
                endRun(pendingUpload)
                finishRun(pendingUpload, with: .failure(error))
                return
            }
            if error == .throttled { pendingUpload.throttled = true }
            waitForNextAttempt(pendingUpload, delay: delay)
        }
    }

    /// The progress dialog stays up through the wait. Stop, logout or replacement invalidate the step.
    func waitForNextAttempt(_ pendingUpload: PendingUpload, delay: TimeInterval) {
        pendingUpload.step += 1
        let step = pendingUpload.step
        let work = DispatchWorkItem { [weak self, weak pendingUpload] in
            guard let self, let pendingUpload, self.upload === pendingUpload, pendingUpload.step == step else {
                return
            }
            pendingUpload.retryWork = nil
            self.send(pendingUpload)
        }
        pendingUpload.retryWork = work
        scheduleRetry(delay, work)
    }

    /// Saved and the token failures end capture mode at once; their alert then only informs.
    func finishRun(_ pendingUpload: PendingUpload, with alert: CaptureUploadAlert) {
        guard alert.endsSession else {
            showUploadAlert(alert, for: pendingUpload)
            return
        }
        endSession(spendingCaptureID: true)
        logger.info("📸 Capture mode ended")
        showAlert(alert)
    }

    /// Ends the run's wait and background time; the prepared bytes stay for Retry.
    func endRun(_ pendingUpload: PendingUpload) {
        pendingUpload.retryWork?.cancel()
        pendingUpload.retryWork = nil
        pendingUpload.backgroundTask.end()
    }

    /// Drops the prepared bytes; nothing of the capture stays in memory.
    func releaseBytes(of pendingUpload: PendingUpload) {
        pendingUpload.upload = nil
        if upload === pendingUpload { upload = nil }
    }

    func handle(_ action: CaptureUploadAlert.Action, for pendingUpload: PendingUpload) {
        guard session === pendingUpload.session else { return }
        switch action {
        case .retry:
            guard upload === pendingUpload else { return }
            startRun(pendingUpload)
        case .discard:
            releaseBytes(of: pendingUpload)
            buttonController?.setButtonHidden(false)
        case .endSession:
            endSession(spendingCaptureID: true)
            logger.info("📸 Capture mode ended")
        }
    }

    /// Invalidates callbacks first, then cancels the request, the wait and the background time.
    func cancelUpload() {
        guard let pendingUpload = upload else { return }
        pendingUpload.step += 1
        pendingUpload.request?.cancel()
        pendingUpload.request = nil
        endRun(pendingUpload)
        releaseBytes(of: pendingUpload)
    }

    func showUploadAlert(_ alert: CaptureUploadAlert, for pendingUpload: PendingUpload) {
        dialogs.showAlert(alert, from: captureWindow?.rootViewController) { [weak self] action in
            performOnMain { [weak self] in self?.handle(action, for: pendingUpload) }
        }
    }

    /// Out of background time: stop the request and end the run like a lost connection. UIKit shows the
    /// Retry alert when the app returns.
    func expireBackgroundRun(_ pendingUpload: PendingUpload) {
        guard upload === pendingUpload else { return }
        pendingUpload.step += 1
        pendingUpload.request?.cancel()
        pendingUpload.request = nil
        endRun(pendingUpload)
        logger.error("📸 Capture upload failed: transient (background time expired)")
        showUploadAlert(.failure(.transient(statusCode: nil)), for: pendingUpload)
    }
}
// swiftlint:enable file_length
