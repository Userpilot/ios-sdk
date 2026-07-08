//
//  MockUserpilot.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 02/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications

@testable import Userpilot

// swiftlint:disable all

public typealias Payload = [String: Any]?

class MockUserpilot: Userpilot {
    init() {
        super.init(config: Userpilot.Config(token: "NX-00000"))
    }

    override init(config: Config) {
        super.init(config: config)
    }

    override func initializeContainer() {
        container.owner = self
        container.register(Userpilot.Config.self, value: config)
        // The real `AutoCaptureCoordinater` resolves `InstanceRegistering`; register
        // the shared registry (which these MockUserpilot instances register into on
        // init) so forwarding tests see the same default-resolution behavior.
        container.register(InstanceRegistering.self, value: Userpilot.Registry.shared)
        container.register(AnalyticsPublishing.self, value: analyticsPublisher)
        container.register(DataStoring.self, value: storage)
        container.register(NetworkMonitoring.self, value: networkMonitor)
        container.register(OfflineEventsHandling.self, value: offlineEventsHandler)
        container.register(EventStoring.self, value: eventStorage)
        container.registerEager(UserSessionStateManaging.self, initializer: UserSessionStateMachine.init)
        container.register(SessionMonitoring.self, value: sessionMonitor)
        container.register(PushNotificationMonitoring.self, value: pushNotificationMonitor)
        container.register(SocketManaging.self, value: socketManager)
        container.register(ExperiencesPublishing.self, value: experiencesPublisher)
        container.register(UserpilotRemoteSourcing.self, value: remoteSource)
        container.register(AutoPropertyDecoratoring.self, value: autoPropertyDecorator)
        container.register(ThemeHandling.self, value: themeHandler)
        container.register(ImageLoading.self, value: imageLoader)
        container.register(LinkOpening.self, value: linkOpener)
        experienceStateMachine = ExperienceStateMachine(container: container)
        container.register(ExperienceStateManaging.self, value: experienceStateMachine)
        // Real screen tracker + autocapture coordinator (lazy: only built when a test
        // resolves `autoCaptureCoordinator`). `ScreenNameTracker.init` ignores its
        // container, and `AutoCaptureCoordinater.init` resolves the mocks registered
        // above, so this is safe for tests that never touch autocapture.
        container.registerLazy(ScreenNameTracking.self, initializer: ScreenNameTracker.init)
        container.registerLazy(AutoCaptureCoordinating.self, initializer: AutoCaptureCoordinater.init)
    }

    var onIdentify: ((String, Payload, Payload) -> Void)?
    override func identify(userId: String, properties: Payload = nil, company: Payload = nil) {
        onIdentify?(userId, properties, company)
        super.identify(userId: userId, properties: properties, company: company)
    }

    var analyticsPublisher = MockAnalyticsPublisher()
    var storage = MockStorage()
    var networkMonitor = MockNetworkMonitor()
    var offlineEventsHandler = MockOfflineEventsHandler()
    var eventStorage = MockEventStorage()
    var sessionMonitor = MockSessionMonitor()
    var pushNotificationMonitor = MockPushNotificationMonitor()
    var socketManager = MockSocketManager()
    var experiencesPublisher = MockExperiencesPublisher()
    var remoteSource = MockUserpilotRemoteSource()
    var autoPropertyDecorator = MockAutoPropertyDecoratorer()
    var themeHandler = MockThemeHandler()
    var imageLoader = MockImageLoader()
    var linkOpener = MockLinkOpening()
    var experienceStateMachine: ExperienceStateManaging!
    var mockLogger = MockLogger()
}

// MARK: - Mock Image Loader

class MockImageLoader: ImageLoading {
    var onLoadImage: ((UIImageView, String, String?, CGSize) -> Void)?
    func loadImage(target: UIImageView, url: String, blurHash: String?, size: CGSize) {
        onLoadImage?(target, url, blurHash, size)
    }
}

// MARK: - Mock Theme Handler

class MockThemeHandler: ThemeHandling {
    var onSaveTheme: ((ThemeContent) -> Void)?
    func saveTheme(_ themeResponse: ThemeContent) {
        onSaveTheme?(themeResponse)
    }

    var onGetThemeById: ((Int) -> ThemeData?)?
    func getThemeById(_ themeId: Int) -> ThemeData? {
        return onGetThemeById?(themeId) ?? nil
    }

    var onMergeExperienceThemes: ((ThemeData?, ExperienceTheme?, ExperienceTheme?) -> ThemeData?)?
    func mergeExperienceThemes(
        _ baseTheme: ThemeData?,
        _ globalTheme: ExperienceTheme?,
        _ stepTheme: ExperienceTheme?
    ) -> ThemeData {
        return onMergeExperienceThemes?(
            baseTheme,
            globalTheme,
            stepTheme
        ) ?? ThemeData(carousel: nil, slideOut: nil, survey: nil)
    }

    var onMergeSurveyThemes: ((ThemeData?, SurveyTheme?) -> SurveyTheme?)?
    func mergeSurveyThemes(
        _ baseTheme: ThemeData?,
        _ surveyTheme: SurveyTheme?
    ) -> SurveyTheme {
        return onMergeSurveyThemes?(
            baseTheme,
            surveyTheme
        ) ?? SurveyTheme(general: nil, font: nil, progress: nil, backdrop: nil)
    }

}

// MARK: - Mock Auto Property Decoratorer

class MockAutoPropertyDecoratorer: AutoPropertyDecoratoring {
    var autoProperties: [String: Any] = [
        AutoPropertyDecorator.osKey: "iOS",
        AutoPropertyDecorator.osVersionKey: UIDevice.current.systemVersion,
        AutoPropertyDecorator.appVersionKey: Bundle.main.version,
        AutoPropertyDecorator.deviceTypeKey: UIDevice.current.modelName,
        AutoPropertyDecorator.screenWidthKey: Int(UIScreen.main.bounds.size.width),
        AutoPropertyDecorator.screenHeightKey: Int(UIScreen.main.bounds.size.height),
    ]

    var appProperties: [String: Any] = [
        AutoPropertyDecorator.appNameKey: Bundle.main.displayName,
        AutoPropertyDecorator.appIdentifierKey: Bundle.main.identifier,
    ]
}

// MARK: - Mock Experiences Publisher

class MockExperiencesPublisher: ExperiencesPublishing {
    var previewExperienceMode = false
    func isPreviewExperienceMode() -> Bool {
        return previewExperienceMode
    }

    var onGetActiveMobileContent: (() -> ExperienceContent)?
    func getActiveMobileContent() -> ExperienceContent? {
        return onGetActiveMobileContent?() ?? nil
    }

    var onPublishInternalSDKEvent: ((SDKEvent) -> Void)?
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent) {
        onPublishInternalSDKEvent?(sdkEvent)
    }

    var onTriggerExperience: ((String) -> Void)?
    func triggerExperience(_ experienceId: String) {
        onTriggerExperience?(experienceId)
    }

    var onTriggerPreviewExperience: ((String, [URLQueryItem]) -> Void)?
    func triggerPreviewExperience(_ experienceId: String, _ queryItems: [URLQueryItem]) {
        onTriggerPreviewExperience?(experienceId, queryItems)
    }

    var onEndExperience: ((Bool) -> Void)?
    func endExperience(manualClose: Bool) {
        onEndExperience?(manualClose)
    }

    var onExperienceDidFinishDismissing: (() -> Void)?
    func experienceDidFinishDismissing() {
        onExperienceDidFinishDismissing?()
    }

    var onCanRequestScreenEvent: (() -> Bool)?
    func canRequestScreenEvent() -> Bool {
        return onCanRequestScreenEvent?() ?? false
    }

    var currentScreen = ""
    var getCurrentScreen: String {
        return currentScreen
    }

    var onTriggerDeepLink: ((URL) -> Void)?
    func triggerDeepLink(url: URL) {
        onTriggerDeepLink?(url)
    }

    var onCancelPendingSurveyContent: (() -> Void)?
    func cancelPendingSurveyContent() {
        onCancelPendingSurveyContent?()
    }

    var onShowThankYouMessage: ((SurveyContent, SurveyTheme, Int64) -> Void)?
    func showThankYouMessage(_ surveyContent: SurveyContent, _ surveyTheme: SurveyTheme, _ submissionId: Int64) {
        onShowThankYouMessage?(surveyContent, surveyTheme, submissionId)
    }

    var onUpdateScreen: ((String) -> Void)?
    func updateScreen(_ screenName: String) {
        currentScreen = screenName
        onUpdateScreen?(screenName)
    }

    var onLogout: (() -> Void)?
    func logout() {
        onLogout?()
    }

}

// MARK: - Mock Userpilot Remote Source

class MockUserpilotRemoteSource: UserpilotRemoteSourcing {
    var onFetchSettings: ((@escaping (Result<Void, RemoteSourceError>) -> Void) -> Void)?
    func fetchSettings(completion: @escaping (Result<Void, RemoteSourceError>) -> Void) {
        onFetchSettings?(completion) ?? completion(.success(()))
    }

    var onFetchPreviewExperience:
        ((PreviewExperienceQueryParams, @escaping (Result<PreviewExperience, RemoteSourceError>) -> Void) -> Void)?
    func fetchPreviewExperience(
        params: PreviewExperienceQueryParams,
        completion: @escaping (Result<PreviewExperience, RemoteSourceError>) -> Void
    ) {
        onFetchPreviewExperience?(params, completion) ?? completion(.failure(.emptyResponse))
    }
}

// MARK: - Mock Link Opening

class MockLinkOpening: LinkOpening {
    var onHandleURL: ((URL) -> Void)?
    func handleURL(_ url: URL) {
        onHandleURL?(url)
    }
}

// MARK: - Mock Socket Manager

class MockSocketManager: SocketManaging {

    var isSocketOpened: Bool = false

    var isJoiningSocket: Bool = false

    var didCloseFromError: Bool = false

    var isShutdownState: Bool = false

    var isSocketConnectedWithUnknownChannel: Bool = false

    var onConnect: (() -> Void)?
    func connect() {
        onConnect?()
    }

    var onClose: (() -> Void)?
    func close() {
        onClose?()
    }

    var onRegisterCallback: ((SocketSubscription) -> Void)?
    func registerCallback(_ socketSubscription: SocketSubscription) {
        onRegisterCallback?(socketSubscription)
    }

    var onPublish: ((String, Payload) -> Void)?
    func publish(
        _ eventName: String,
        payload: Payload
    ) {
        onPublish?(eventName, payload)
    }

}

// MARK: - Mock Analytics Publisher

class MockAnalyticsPublisher: AnalyticsPublishing {
    var onPublish: ((Event) -> Void)?
    func publish(_ event: Event) {
        onPublish?(event)
    }

    var onFlush: (() -> Void)?
    func flush() {
        onFlush?()
    }

    var onResume: (() -> Void)?
    func resume() {
        onResume?()
    }

    var onReset: (() -> Void)?
    func reset() {
        onReset?()
    }

    var onLogout: ((Bool) -> Void)?
    func logout(clearCachedIdentifyEvent: Bool) {
        onLogout?(clearCachedIdentifyEvent)
    }

    var canRequestEvent: Bool = true

    var onPublishInternalSDKEvent: ((SDKEvent) -> Void)?
    func publishInternalSDKEvent(_ sdkEvent: SDKEvent) {
        onPublishInternalSDKEvent?(sdkEvent)
    }

    var onPublishFakeReloadScreenEvent: ((ExperienceType?, Int?, Bool) -> Bool)?
    func publishFakeReloadScreenEvent(
        _ experienceType: ExperienceType?,
        _ experienceId: Int?,
        isFakeReload: Bool
    ) -> Bool {
        return onPublishFakeReloadScreenEvent?(experienceType, experienceId, isFakeReload) ?? false
    }

    var onExperiencePublished: ((ExperienceType, Int) -> Void)?
    func experiencePublished(_ experienceType: ExperienceType, _ experienceId: Int) {
        onExperiencePublished?(experienceType, experienceId)
    }

    var isStartSession: Bool = false

    var screenSessionStateMachine: ScreenSessionStateMachine?
}

// MARK: - Mock Storage

class MockStorage: DataStoring {
    var socketURL: String = ""
    var pushToken: String? = ""
    var userId: String = "user-id"
    var anonymousUserId: String = ""
    var user: String = ""
    var temporaryUser: String?
    var sessionDate: Date?
    var configurationDate: Date?
}

// MARK: - Mock Session Monitor

class MockSessionMonitor: SessionMonitoring {

    var isAppActive: Bool = true

    var onReset: (() -> Void)?
    func reset() {
        onReset?()
    }
}

// MARK: - Mock Push Notification Monitor

class MockPushNotificationMonitor: PushNotificationMonitoring {

    var pushEnabled: Bool = false
    var pushAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    var onConfigureAutomatically: (() -> Void)?
    func configureAutomatically() {
        onConfigureAutomatically?()
    }

    var onSetPushToken: ((Data?) -> Void)?
    func setPushToken(_ deviceToken: Data?) {
        onSetPushToken?(deviceToken)
    }

    var onRefreshPushStatus: (() -> Void)?
    func refreshPushStatus(completion: ((UNAuthorizationStatus) -> Void)?) {
        onRefreshPushStatus?()
        completion?(pushAuthorizationStatus)
    }

    var onDidReceiveNotification: ((UNNotificationResponse) -> Bool)?
    func didReceiveNotification(
        response: UNNotificationResponse, completionHandler: @escaping () -> Void
    ) -> Bool {
        let result = onDidReceiveNotification?(response) ?? false
        if result {
            completionHandler()
        }
        return result
    }

    var onAttemptDeferredNotificationResponse: (() -> Void)?
    func attemptDeferredNotificationResponse() -> Bool {
        onAttemptDeferredNotificationResponse?()
        return false
    }
}

// MARK: - Mock Network Monitor

class MockNetworkMonitor: NetworkMonitoring {
    var isNetworkAvailable: Bool = true
    var connectionType: ConnectionType = .wifi
    var isConnectedViaWiFi: Bool { isNetworkAvailable && connectionType == .wifi }
    var isConnectedViaCellular: Bool { isNetworkAvailable && connectionType == .cellular }
    var isReady: Bool = true
    weak var delegate: NetworkMonitoringDelegate?

    var onStartMonitoring: (() -> Void)?
    func startMonitoring() {
        onStartMonitoring?()
    }

    var onStopMonitoring: (() -> Void)?
    func stopMonitoring() {
        onStopMonitoring?()
    }
}

// MARK: - Mock Offline Events Handler

class MockOfflineEventsHandler: OfflineEventsHandling {
    var shouldSaveOffline: Bool = false
    var hasCachedEvents: Bool = false
    var savedEvents: [(event: Event, clearStoredEventsFirst: Bool)] = []
    var didRestoreEvents = false
    var didClearLocalEvents = false

    func saveEventToLocalStorage(event: Event, clearStoredEventsFirst: Bool) {
        savedEvents.append((event, clearStoredEventsFirst))
    }

    func restoreEventsFromLocalStorage(completion: (() -> Void)?) {
        didRestoreEvents = true
        completion?()
    }

    func clearLocalEvents() {
        didClearLocalEvents = true
        savedEvents.removeAll()
    }
}

// MARK: - Mock Event Storage

class MockEventStorage: EventStoring {
    var events: [EventStorage] = []
    var didDeleteAllEvents = false

    func saveEvent(_ activity: EventStorage, completion: @escaping (Bool) -> Void) {
        events.append(activity)
        completion(true)
    }

    func getAllEventsAndDelete(completion: @escaping ([EventStorage]) -> Void) {
        let storedEvents = events
        events.removeAll()
        completion(storedEvents)
    }

    func deleteEvent(_ activity: EventStorage) {
        events.removeAll { $0.requestId == activity.requestId }
    }

    func deleteAllEvents() {
        didDeleteAllEvents = true
        events.removeAll()
    }

    func getStorageStats() -> DatabaseStats {
        let totalSize = events.reduce(Int64(0)) { $0 + Int64($1.sizeBytes) }
        return DatabaseStats(
            eventCount: events.count,
            totalSizeBytes: totalSize,
            maxEventCount: Constants.Database.maxEventCount,
            maxSizeBytes: Constants.Database.maxSizeBytes,
            isCountLimitReached: events.count >= Constants.Database.maxEventCount,
            isSizeLimitReached: totalSize >= Constants.Database.maxSizeBytes
        )
    }

    func hasEvents() -> Bool {
        !events.isEmpty
    }
}

// MARK: - Mock Logger

class MockLogger: Logging {
    var loggedDebugs: [String] = []
    var loggedInfos: [String] = []
    var loggedLogs: [String] = []
    var loggedErrors: [String] = []
    var loggedFaults: [String] = []

    var onDebug: ((StaticString, any CVarArg) -> Void)?
    func debug(_ message: StaticString, _ args: any CVarArg...) {
        let formatted = String(format: String(describing: message), arguments: args)
        loggedDebugs.append(formatted)
        onDebug?(message, args)
    }

    var onInfo: ((StaticString, any CVarArg) -> Void)?
    func info(_ message: StaticString, _ args: any CVarArg...) {
        let formatted = String(format: String(describing: message), arguments: args)
        loggedInfos.append(formatted)
        onInfo?(message, args)
    }

    var onLog: ((StaticString, any CVarArg) -> Void)?
    func log(_ message: StaticString, _ args: any CVarArg...) {
        let formatted = String(format: String(describing: message), arguments: args)
        loggedLogs.append(formatted)
        onLog?(message, args)
    }

    var onError: ((StaticString, any CVarArg) -> Void)?
    func error(_ message: StaticString, _ args: any CVarArg...) {
        let formatted = String(format: String(describing: message), arguments: args)
        loggedErrors.append(formatted)
        onError?(message, args)
    }

    var onFault: ((StaticString, any CVarArg) -> Void)?
    func fault(_ message: StaticString, _ args: any CVarArg...) {
        let formatted = String(format: String(describing: message), arguments: args)
        loggedFaults.append(formatted)
        onFault?(message, args)
    }

}

// MARK: - Mock Navigation Delegate

class MockNavigationDelegate: UserpilotNavigationDelegate {
    var onNavigate: ((URL) -> Void)?
    func navigate(to url: URL) {
        onNavigate?(url)
    }
}

// MARK: - Mock SDKEvent

class MockSDKEvent: SDKEvent {
    var eventName: String
    var eventPayload: [String: Any]
    var hasDeepLink: Bool

    var isCloseNPSEvent = false
    var isCloseEvent = false

    init(
        eventName: String = "test-event",
        eventPayload: [String: Any] = [:],
        hasDeepLink: Bool = false
    ) {
        self.eventName = eventName
        self.eventPayload = eventPayload
        self.hasDeepLink = hasDeepLink
    }

    func isEventForCloseNPSExperience() -> Bool {
        return isCloseNPSEvent
    }

    func isEventForCloseExperience() -> Bool {
        return isCloseEvent
    }
}

// MARK: - Mock UPExperience

class MockUPExperience: UIViewController, UPExperience {
    var onTriggerClose: ((Bool) -> Void)?

    func triggerCloseExperience(
        manualClose: Bool,
        completion: (() -> Void)?
    ) {
        onTriggerClose?(manualClose)
        completion?()
    }
}

// MARK: - Mock Socket Subscription

class MockSocketSubscription: SocketSubscription {
    var onSocketClosedCalled: (() -> Void)?
    var onSocketOpenedCalled: (() -> Void)?
    var onSocketEventSentCalled: ((String, [String: Any]?, Message, Bool) -> Void)?
    var onNewMessageCalled: ((Message) -> Void)?

    func onSocketClosed() {
        onSocketClosedCalled?()
    }

    func onSocketOpened() {
        onSocketOpenedCalled?()
    }

    func onSocketEventSent(
        _ event: String, _ payload: [String: Any]?, _ message: Message, _ status: Bool
    ) {
        onSocketEventSentCalled?(event, payload, message, status)
    }

    func onNewMessage(_ message: Message) {
        onNewMessageCalled?(message)
    }
}

// swiftlint:enable all
