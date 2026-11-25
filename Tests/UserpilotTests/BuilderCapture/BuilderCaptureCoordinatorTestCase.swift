//
//  BuilderCaptureCoordinatorTestCase.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Shared coordinator fixture: a real coordinator with recorded uploads, dialogs, waits and background time.
//

import XCTest
@testable import Userpilot

/// Builds a real `BuilderCaptureCoordinator` whose transport, dialogs, retry timer and background time are
/// recorded, so tests drive each attempt and each wait themselves (virtual time, no sleeps).
class BuilderCaptureCoordinatorTestCase: XCTestCase {
    var owner: MockUserpilot!
    var container: DIContainer!
    var window: UIWindow!
    var targeting: CaptureTargetingStub!
    var snapshotter: CaptureSnapshotStub!
    var encoder: CaptureEncoderStub!
    var dialogs: CaptureDialogSpy!
    var coordinator: BuilderCaptureCoordinator!
    /// Completions of the silent closes capture mode asked for, held so a test decides when each finishes.
    var dismissals: [() -> Void] = []
    var backgroundTasks: [CaptureBackgroundTaskSpy] = []
    /// Every wait the coordinator asked for, in order, and its pending work.
    var delays: [TimeInterval] = []
    var waits: [DispatchWorkItem] = []

    var remote: MockUserpilotRemoteSource { owner.remoteSource }

    override func setUp() {
        super.setUp()
        BuilderCaptureMode.reset()
        owner = MockUserpilot.make(config: Userpilot.Config(token: "NX-\(UUID().uuidString)").defaultInstance(false))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        window.rootViewController = UIViewController()
        targeting = CaptureTargetingStub(host: ElementTargetHost(window: window, owner: owner))
        snapshotter = CaptureSnapshotStub()
        encoder = CaptureEncoderStub()
        dialogs = CaptureDialogSpy()
        owner.analyticsPublisher.screenSessionStateMachine = ScreenSessionStateMachine(
            event: Event(type: .screen("Home")))
        owner.experiencesPublisher.isExperienceVisible = true
        owner.experiencesPublisher.onCloseSilently = { [weak self] completion in
            if let completion { self?.dismissals.append(completion) }
        }
        container = makeContainer(for: owner)
        coordinator = makeCoordinator(container: container, owner: owner)
    }

    override func tearDown() {
        coordinator.stop()
        coordinator = nil
        BuilderCaptureMode.reset()
        container = nil
        window = nil
        owner = nil
        dismissals.removeAll()
        backgroundTasks.removeAll()
        delays.removeAll()
        waits.removeAll()
        super.tearDown()
    }

    /// The coordinator's own services; the registry is the process one, as in production.
    func makeContainer(for owner: MockUserpilot) -> DIContainer {
        let container = DIContainer()
        container.register(Userpilot.Config.self, value: owner.config)
        container.register(ElementTargeting.self, value: targeting)
        container.register(ScreenSnapshotting.self, value: snapshotter)
        container.register(CaptureEncoding.self, value: encoder)
        container.register(UserpilotRemoteSourcing.self, value: owner.remoteSource)
        container.register(ExperiencesPublishing.self, value: owner.experiencesPublisher)
        container.register(AnalyticsPublishing.self, value: owner.analyticsPublisher)
        container.register(DataStoring.self, value: owner.storage)
        container.register(InstanceRegistering.self, value: UserpilotRuntime.shared.instanceRegistry)
        return container
    }

    /// Registers the coordinator in the owner's container too, so logout reaches it.
    func makeCoordinator(container: DIContainer, owner: MockUserpilot) -> BuilderCaptureCoordinator {
        let coordinator = BuilderCaptureCoordinator(container: container)
        coordinator.dialogs = dialogs
        coordinator.scheduleRetry = { [weak self] delay, work in
            self?.delays.append(delay)
            self?.waits.append(work)
        }
        coordinator.makeBackgroundTask = { [weak self] in
            let task = CaptureBackgroundTaskSpy()
            self?.backgroundTasks.append(task)
            return task
        }
        owner.container.register(BuilderCaptureCoordinating.self, value: coordinator)
        return coordinator
    }

    func makeLink(_ captureID: String = UUID().uuidString, token: String = "token-a") -> CaptureLink {
        guard let link = CaptureLink.from(captureID: captureID, platform: "ios", token: token) else {
            fatalError("Invalid fixture link")
        }
        return link
    }

    /// Takes a capture through to Save, as the operator would.
    func save(named name: String = "Typed name") throws {
        owner.experiencesPublisher.isExperienceVisible = false
        snapshotter.screenshot = CaptureSnapshotStub.makeScreenshot()
        coordinator.capture()
        let confirm = try XCTUnwrap(dialogs.confirmations.last, "The confirmation sheet did not open")
        confirm(.save(screenName: name))
    }

    /// Finishes one recorded upload attempt with `result`.
    func finish(_ index: Int, _ result: Result<Void, CaptureUploadError>) throws {
        let upload = try XCTUnwrap(remote.uploads.indices.contains(index) ? remote.uploads[index] : nil)
        upload.completion(result)
    }

    /// Ends the most recent wait, as the timer would.
    func fireLastWait() throws {
        try XCTUnwrap(waits.last).perform()
    }
}

// MARK: - Doubles

/// Always admits `host` and captures an empty root; `valid` false makes that host stale.
final class CaptureTargetingStub: ElementTargeting {
    let host: ElementTargetHost
    var valid = true
    init(host: ElementTargetHost) { self.host = host }
    func admitHost() -> ElementTargetHost? { host }
    func admitHost(in window: UIWindow) -> ElementTargetHost? { host }
    func isValid(_ host: ElementTargetHost) -> Bool { valid }
    func captureLayout(in host: ElementTargetHost, completion: @escaping (ElementNode?) -> Void) {
        completion(ElementNode(nodeID: "root", nativeType: "UIWindow", displayName: nil,
            bounds: .zero, visibleBounds: nil, selector: nil, children: [], view: nil))
    }
    func findMatches(
        for selector: UserpilotElementSelector, in tree: ElementNode, host: ElementTargetHost
    ) -> [ElementMatch] { [] }
    func isScreenAtEnd(in host: ElementTargetHost, completion: @escaping (Bool) -> Void) { completion(false) }
}

final class CaptureSnapshotStub: ScreenSnapshotting {
    var calls = 0
    /// Nil fails the capture.
    var screenshot: UserpilotScreenshot?

    func snapshot(of window: UIWindow) -> UserpilotScreenshot? {
        calls += 1
        return screenshot
    }

    static func makeScreenshot() -> UserpilotScreenshot {
        let size = CGSize(width: 4, height: 4)
        let image = UIGraphicsImageRenderer(size: size).image { _ in }
        return UserpilotScreenshot(image: image, size: size, insets: .zero)
    }
}

/// Records each document; prepares a tiny upload under the document's capture id, or fails.
final class CaptureEncoderStub: CaptureEncoding {
    var failure: CaptureEncodingError?
    private(set) var documents: [CaptureDocument] = []

    func prepareUpload(
        document: CaptureDocument,
        screenshot: UIImage,
        completion: @escaping (Result<CaptureUpload, CaptureEncodingError>) -> Void
    ) {
        documents.append(document)
        if let failure {
            completion(.failure(failure))
        } else {
            completion(.success(CaptureUpload(
                captureID: document.captureID, screenshot: Data([0x89]), document: Data("{}".utf8))))
        }
    }
}

/// Shows nothing: holds each confirmation's completion and each alert's action for the test to answer.
final class CaptureDialogSpy: CaptureDialogShowing {
    private(set) var confirmations: [(CaptureConfirmationViewController.Outcome) -> Void] = []
    private(set) var progressCount = 0
    private(set) var alerts: [CaptureUploadAlert] = []
    private var actions: [(CaptureUploadAlert.Action) -> Void] = []

    func showConfirmation(
        annotatedScreenshot: UIImage,
        targetableElementCount: Int,
        suggestedScreenName: String,
        from presenter: UIViewController,
        completion: @escaping (CaptureConfirmationViewController.Outcome) -> Void
    ) {
        confirmations.append(completion)
    }

    func showProgress(from presenter: UIViewController?) {
        progressCount += 1
    }

    func showAlert(
        _ alert: CaptureUploadAlert,
        from presenter: UIViewController?,
        onAction: @escaping (CaptureUploadAlert.Action) -> Void
    ) {
        alerts.append(alert)
        actions.append(onAction)
    }

    /// Taps a button of the last alert.
    func tap(_ action: CaptureUploadAlert.Action) {
        actions.last?(action)
    }
}

/// Records the upload's background task; `expire()` plays the system running out of time.
final class CaptureBackgroundTaskSpy: CaptureUploadBackgroundTasking {
    private(set) var begins = 0
    private(set) var isRunning = false
    private var onExpiration: (() -> Void)?

    func begin(onExpiration: @escaping () -> Void) {
        begins += 1
        isRunning = true
        self.onExpiration = onExpiration
    }

    func end() {
        isRunning = false
    }

    /// The system ran out of background time.
    func expire() {
        onExpiration?()
        end()
    }
}
