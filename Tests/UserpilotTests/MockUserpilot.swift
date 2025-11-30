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
        container.register(AnalyticsPublishing.self, value: analyticsPublisher)
        container.register(DataStoring.self, value: storage)
        container.register(SessionMonitoring.self, value: sessionMonitor)
        container.register(PushNotificationMonitoring.self, value: pushNotificationMonitor)
        container.register(SocketManaging.self, value: socketManager)
        container.register(ExperiencesPublishing.self, value: experiencesPublisher)
        container.register(AutoPropertyDecoratoring.self, value: autoPropertyDecorator)
        container.register(UserpilotRemoteSourcing.self, value: remoteSource)
        container.register(ThemeHandling.self, value: themeHandler)
        container.register(ImageLoading.self, value: imageLoader)
        container.register(NetworkMonitoring.self, value: networkMonitor)
        container.register(OfflineEventsHandling.self, value: offlineEventsHandler)
        container.register(EventStoring.self, value: eventStoring)
        container.register(DeepLinkHandling.self, value: deepLinkHandler)
        linkOpener.userpilot = self
        container.register(LinkOpening.self, value: linkOpener as LinkOpening)
        container.register(UserSessionStateManaging.self, value: mockUserSessionStateManager)
        container.register(ExperienceStateManaging.self, value: mockExperienceStateManager)
    }

    var onIdentify: ((String, Payload, Payload) -> Void)?
    override func identify(userId: String, properties: Payload = nil, company: Payload = nil) {
        onIdentify?(userId, properties, company)
        super.identify(userId: userId, properties: properties, company: company)
    }

    var analyticsPublisher = MockAnalyticsPublisher()
    var storage = MockStorage()
    var sessionMonitor = MockSessionMonitor()
    var pushNotificationMonitor = MockPushNotificationMonitor()
    var socketManager = MockSocketManager()
    var experiencesPublisher = MockExperiencesPublisher()
    var autoPropertyDecorator = MockAutoPropertyDecoratorer()
    var remoteSource = MockRemoteSource()
    var themeHandler = MockThemeHandler()
    var imageLoader = MockImageLoader()
    var mockLogger = MockLogger()
    var linkOpener = MockLinkOpener()
    var deepLinkHandler = MockDeepLinkHandler()
    var networkMonitor = MockNetworkMonitor()
    var offlineEventsHandler = MockOfflineEventsHandler()
    var eventStoring = MockEventStoring()
    var mockUserSessionStateManager = MockUserSessionStateManager()
    var mockExperienceStateManager = MockExperienceStateManager()
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

// MARK: - Mock Remote Source

class MockRemoteSource: UserpilotRemoteSourcing {

    /// Optional hook used by tests to control how `fetchSettings` behaves.
    /// The closure receives the original completion handler so tests can
    /// decide when and with what `Result` value to call it.
    var onFetchSettings: (((@escaping (Result<Void, RemoteSourceError>) -> Void) -> Void))?
    func fetchSettings(completion: @escaping (Result<Void, RemoteSourceError>) -> Void) {
        if let handler = onFetchSettings {
            // Let tests invoke the completion with a custom result and timing.
            handler(completion)
        } else {
            // Default behavior: immediately succeed.
            completion(.success(()))
        }
    }

    var onFetchPreviewExperience: ((Result<PreviewExperience, RemoteSourceError>) -> Void)?
    func fetchPreviewExperience(
        params: PreviewExperienceQueryParams,
        completion: @escaping (Result<PreviewExperience, RemoteSourceError>) -> Void
    ) {
        if let handler = onFetchPreviewExperience {
            handler(.failure(.networkError("Mock error")))
            completion(.failure(.networkError("Mock error")))
        } else {
            completion(.failure(.networkError("Not implemented")))
        }
    }
}

// MARK: - Mock Auto Property Decoratorer

class MockAutoPropertyDecoratorer: AutoPropertyDecoratoring {
    var autoProperties: [String: Any] = [
        Constants.AutoProperty.osKey: "iOS",
        Constants.AutoProperty.osVersionKey: UIDevice.current.systemVersion,
        Constants.AutoProperty.appVersionKey: Bundle.main.version,
        Constants.AutoProperty.deviceTypeKey: UIDevice.current.modelName,
        Constants.AutoProperty.screenWidthKey: Int(UIScreen.main.bounds.size.width),
        Constants.AutoProperty.screenHeightKey: Int(UIScreen.main.bounds.size.height),
    ]

    var appProperties: [String: Any] = [
        Constants.AutoProperty.appNameKey: Bundle.main.displayName,
        Constants.AutoProperty.appIdentifierKey: Bundle.main.identifier,
    ]
}

// MARK: - Mock Experiences Publisher

class MockExperiencesPublisher: ExperiencesPublishing {
    var onIsPreviewExperienceMode: (() -> Bool)?
    func isPreviewExperienceMode() -> Bool {
        return onIsPreviewExperienceMode?() ?? false
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

    var onUpdateScreen: ((String) -> Void)?
    func updateScreen(_ screenName: String) {
        onUpdateScreen?(screenName)
    }

    var onEndExperience: ((Bool, UPExperience?) -> Void)?
    func endExperience(isInternalEvent: Bool, component: UPExperience? = nil) {
        onEndExperience?(isInternalEvent, component)
    }

    var onCanRequestScreenEvent: (() -> Bool)?
    func canRequestScreenEvent() -> Bool {
        return onCanRequestScreenEvent?() ?? false
    }

    var onTriggerDeepLink: ((URL) -> Void)?
    func triggerDeepLink(url: URL) {
        onTriggerDeepLink?(url)
    }

    var onResetState: (() -> Void)?
    func resetState() {
        onResetState?()
    }

    var getCurrentScreen: String = ""

    var onShowThankYouMessage: ((SurveyContent, SurveyTheme) -> Void)?
    func showThankYouMessage(_ surveyContent: SurveyContent, _ surveyTheme: SurveyTheme) {
        onShowThankYouMessage?(surveyContent, surveyTheme)
    }

}

// MARK: - Mock Socket Manager

class MockSocketManager: SocketManaging {

    var isSocketOpened: Bool = false

    var isJoiningSocket: Bool = false

    var didCloseFromError: Bool = false

    var isShutdownState: Bool = false

    var isAllowToOpenSocket: Bool = true

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

    var onPublish: ((String, Payload, Bool) -> Void)?
    func publish(
        _ eventName: String,
        payload: Payload,
        isClosingSocket: Bool
    ) {
        onPublish?(eventName, payload, isClosingSocket)
    }

}

// MARK: - Mock Analytics Publisher

class MockAnalyticsPublisher: AnalyticsPublishing {
    var onPublish: ((Event, Bool) -> Void)?
    func publish(_ event: Event, isInternalEvent: Bool = false) {
        onPublish?(event, isInternalEvent)
    }

    var onFlush: (() -> Void)?
    func flush() {
        onFlush?()
    }

    var onResume: (() -> Void)?
    func resume() {
        onResume?()
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

    var onPublishFakeReloadScreenEvent: ((ExperienceType?, Int?) -> Void)?
    func publishFakeReloadScreenEvent(_ experienceType: ExperienceType?, _ experienceId: Int?) {
        onPublishFakeReloadScreenEvent?(experienceType, experienceId)
    }

    var onExperiencePublished: ((ExperienceType?, Int?) -> Void)?
    func experiencePublished(_ experienceType: ExperienceType?, _ experienceId: Int?) {
        onExperiencePublished?(experienceType, experienceId)
    }

    var isStartSession: Bool = false

    var screenEntity: ScreenViewEntity?
}

// MARK: - Mock Storage

class MockStorage: DataStoring {
    var socketURL: String = ""
    var pushToken: String? = nil
    var userId: String = ""
    var anonymousUserId: String = ""
    var user: String = ""
    var temporaryUser: String? = nil
    var sessionDate: Date? = nil
    var configurationDate: Date? = nil
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

// MARK: - Mock Logger

class MockLogger: Logging {
    // Thread-safe storage using a serial queue for synchronization
    private let queue = DispatchQueue(label: "com.userpilot.mocklogger", attributes: [])
    private var _loggedDebugs: [String] = []
    private var _loggedInfos: [String] = []
    private var _loggedLogs: [String] = []
    private var _loggedErrors: [String] = []
    private var _loggedFaults: [String] = []

    var loggedDebugs: [String] {
        get { queue.sync { _loggedDebugs } }
        set { queue.sync(flags: .barrier) { self._loggedDebugs = newValue } }
    }

    var loggedInfos: [String] {
        get { queue.sync { _loggedInfos } }
        set { queue.sync(flags: .barrier) { self._loggedInfos = newValue } }
    }

    var loggedLogs: [String] {
        get { queue.sync { _loggedLogs } }
        set { queue.sync(flags: .barrier) { self._loggedLogs = newValue } }
    }

    var loggedErrors: [String] {
        get { queue.sync { _loggedErrors } }
        set { queue.sync(flags: .barrier) { self._loggedErrors = newValue } }
    }

    var loggedFaults: [String] {
        get { queue.sync { _loggedFaults } }
        set { queue.sync(flags: .barrier) { self._loggedFaults = newValue } }
    }

    var onDebug: ((StaticString, any CVarArg) -> Void)?
    func debug(_ message: StaticString, _ args: any CVarArg...) {
        let formatted = String(format: String(describing: message), arguments: args)
        queue.async(flags: .barrier) {
            self._loggedDebugs.append(formatted)
        }
        onDebug?(message, args)
    }

    var onInfo: ((StaticString, any CVarArg) -> Void)?
    func info(_ message: StaticString, _ args: any CVarArg...) {
        let formatted = String(format: String(describing: message), arguments: args)
        queue.async(flags: .barrier) {
            self._loggedInfos.append(formatted)
        }
        onInfo?(message, args)
    }

    var onLog: ((StaticString, any CVarArg) -> Void)?
    func log(_ message: StaticString, _ args: any CVarArg...) {
        let formatted = String(format: String(describing: message), arguments: args)
        queue.async(flags: .barrier) {
            self._loggedLogs.append(formatted)
        }
        onLog?(message, args)
    }

    var onError: ((StaticString, any CVarArg) -> Void)?
    func error(_ message: StaticString, _ args: any CVarArg...) {
        let formatted = String(format: String(describing: message), arguments: args)
        queue.async(flags: .barrier) {
            self._loggedErrors.append(formatted)
        }
        onError?(message, args)
    }

    var onFault: ((StaticString, any CVarArg) -> Void)?
    func fault(_ message: StaticString, _ args: any CVarArg...) {
        let formatted = String(format: String(describing: message), arguments: args)
        queue.async(flags: .barrier) {
            self._loggedFaults.append(formatted)
        }
        onFault?(message, args)
    }

}

// MARK: - Mock ExperienceStateManager

class MockExperienceStateManager: ExperienceStateManaging {

    var currentState: ExperienceFlowState = .idle
    private var activeComponent: WeakExperienceReference?

    var markIdleCalled = false
    var markManualTriggerCalled = false
    var markAutomaticTriggerCalled = false
    var markPreviewModeCalled = false
    var markActiveCalled = false

    func getCurrentState() -> ExperienceFlowState {
        return currentState
    }

    func isActive() -> Bool {
        return currentState.isActive()
    }

    func isActivelyRendered() -> Bool {
        return currentState.isActivelyRendered()
    }

    func shouldBypassScreenValidation() -> Bool {
        return currentState.shouldBypassScreenValidation()
    }

    func isPreviewMode() -> Bool {
        return currentState.isPreviewMode()
    }

    func isManualTrigger() -> Bool {
        return currentState.isManualTrigger()
    }

    func hasCachedExperience() -> Bool {
        return currentState.hasCachedExperience()
    }

    func markIdle() {
        markIdleCalled = true
        activeComponent = nil
        currentState = .idle
    }

    func getComponentAndMarkIdle() -> UPExperience? {
        let component = activeComponent?.get()
        markIdle()
        return component
    }

    func markManualTrigger(_ experienceId: String?) {
        markManualTriggerCalled = true
        currentState = .pendingManual(experienceId: experienceId)
    }

    func markAutomaticTrigger(_ experience: ExperienceContent?) {
        markAutomaticTriggerCalled = true
        currentState = .pendingAutomatic(experience: experience)
    }

    func markPreviewMode() {
        markPreviewModeCalled = true
        currentState = .pendingPreview
    }

    func markWaitingDelay(_ triggerType: TriggerType) {
        currentState = .waitingDelay(triggerType: triggerType)
    }

    func markActive(_ triggerType: TriggerType, _ content: ExperienceContent) {
        markActiveCalled = true
        currentState = .active(triggerType: triggerType, content: content)
    }

    func markShowingThankYou() {
        currentState = .showingThankYou
    }

    func markCachedManual(_ experienceId: String) {
        currentState = .cachedPendingManual(experienceId: experienceId)
    }

    func markCachedAutomatic(_ experience: ExperienceContent) {
        currentState = .cachedPendingAutomatic(experience: experience)
    }

    func setActiveComponent(_ component: UPExperience) {
        activeComponent = WeakExperienceReference(component)
    }

    func getActiveComponent() -> UPExperience? {
        return activeComponent?.get()
    }

    func getActiveContent() -> ExperienceContent? {
        if case .active(_, let content) = currentState {
            return content
        }
        return nil
    }

    func getActiveTriggerType() -> TriggerType? {
        if case .active(let triggerType, _) = currentState {
            return triggerType
        }
        return nil
    }

    func isActiveComponentAlive() -> Bool {
        return activeComponent?.get() != nil
    }

    func getCachedExperienceId() -> String? {
        if case .cachedPendingManual(let experienceId) = currentState {
            return experienceId
        }
        return nil
    }

    func getCachedExperienceContent() -> ExperienceContent? {
        if case .cachedPendingAutomatic(let experience) = currentState {
            return experience
        }
        return nil
    }

    func markActiveFromCurrentState(content: ExperienceContent) {
        let triggerType: TriggerType
        if isManualTrigger() {
            triggerType = .manual
        } else if isPreviewMode() {
            triggerType = .preview
        } else {
            triggerType = .automatic
        }
        markActive(triggerType, content)
    }

    func processCachedExperience() -> CachedExperienceAction {
        switch currentState {
        case .cachedPendingManual(let experienceId):
            return .triggerManual(experienceId: experienceId)
        case .cachedPendingAutomatic(let experience):
            return .processAutomatic(experience: experience)
        default:
            return .none
        }
    }

}

// MARK: - Mock UserSessionStateManager

class MockUserSessionStateManager: UserSessionStateManaging {
    var currentState: UserSessionState = .awaitingInitialScreen

    var markNormalCalled = false
    var markUserBackFromBackgroundCalled = false
    var markUserSwitchCalled = false
    var markAwaitingInitialScreenCalled = false

    func getCurrentState() -> UserSessionState {
        return currentState
    }

    func isUserSwitching() -> Bool {
        return currentState.isUserSwitching()
    }

    func needsInitialScreen() -> Bool {
        return currentState.needsInitialScreen()
    }

    func isNormal() -> Bool {
        if case .normal = currentState {
            return true
        }
        return false
    }

    func isAwaitingInitialScreen() -> Bool {
        if case .awaitingInitialScreen = currentState {
            return true
        }
        return false
    }

    func isUserSwitchingAwaitingScreen() -> Bool {
        if case .userSwitchingAwaitingScreen = currentState {
            return true
        }
        return false
    }

    func markNormal() {
        markNormalCalled = true
        currentState = .normal
    }

    func markUserBackFromBackground() {
        markUserBackFromBackgroundCalled = true
        currentState = .backgroundToInitialScreen
    }

    func markUserSwitch() {
        markUserSwitchCalled = true
        currentState = .userSwitching
    }

    func markAwaitingInitialScreen() {
        markAwaitingInitialScreenCalled = true
        let newState: UserSessionState
        if case .userSwitching = currentState {
            newState = .userSwitchingAwaitingScreen
        } else {
            newState = .awaitingInitialScreen
        }
        currentState = newState
    }

    func isPostIdentificationContext(_ eventName: String) -> Bool {
        return (eventName == Constants.Event.identifyEvent || needsInitialScreen())
    }

    func shouldRequestInitialScreenEvent(_ eventsQueueEmpty: Bool, _ hasCurrentScreen: Bool) -> Bool
    {
        return eventsQueueEmpty && hasCurrentScreen
    }

    func getPostIdentificationScreenConfig(currentStartSession: Bool)
        -> UserSessionStateManager.PostIdentificationScreenConfig
    {
        let isUserSwitch = isUserSwitching() || isUserSwitchingAwaitingScreen()
        return UserSessionStateManager.PostIdentificationScreenConfig(
            startSession: isUserSwitch ? true : currentStartSession,
            isFakeReload: !isUserSwitch
        )
    }

    func getPostIdentificationStartSessionConfig(currentStartSession: Bool) -> Bool {
        let isUserSwitch = isUserSwitching() || isUserSwitchingAwaitingScreen()
        return isUserSwitch ? true : currentStartSession
    }

    func getPostIdentificationFakeReloadConfig() -> Bool {
        let isUserSwitch = isUserSwitching() || isUserSwitchingAwaitingScreen()
        return !isUserSwitch
    }
}

// MARK: - Mock Navigation Delegate

class MockNavigationDelegate: UserpilotNavigationDelegate {
    var onNavigate: ((URL) -> Void)?
    func navigate(to url: URL) {
        onNavigate?(url)
    }
}

// MARK: - Mock URL Opener

class MockLinkOpener: TopControllerGetting, URLOpening, LinkOpening {
    weak var userpilot: Userpilot?

    func handleURL(_ url: URL) {
        // Mimic the real LinkOpener behavior by checking for navigation delegate
        if let delegate = userpilot?.navigationDelegate {
            delegate.navigate(to: url)
        } else {
            // Fallback to open if no delegate
            open(url)
        }
    }

    var openCalled = false
    var lastOpenedURL: URL?
    var topViewControllerCalled: Bool?
    var mockTopViewController: UIViewController?
    var hasActiveWindowScenes: Bool = true

    func open(_ url: URL) {
        openCalled = true
        lastOpenedURL = url
    }

    func topViewController() -> UIViewController? {
        topViewControllerCalled = true
        return mockTopViewController
    }

    func reset() {
        openCalled = false
        lastOpenedURL = nil
        topViewControllerCalled = nil
        mockTopViewController = nil
    }
}

// MARK: - Mock Top Controller Getting

class MockTopControllerGetting: TopControllerGetting {
    var hasActiveWindowScenes: Bool = true
    var mockTopViewController: UIViewController?

    func topViewController() -> UIViewController? {
        return mockTopViewController
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

    func triggerCloseExperience(isInternalEvent: Bool) {
        onTriggerClose?(isInternalEvent)
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

// MARK: - Mock Event Storing

class MockEventStoring: EventStoring {
    var onSaveEvent: ((EventStorage, @escaping (Bool) -> Void) -> Void)?
    func saveEvent(_ activity: EventStorage, completion: @escaping (Bool) -> Void) {
        if let handler = onSaveEvent {
            handler(activity, completion)
        } else {
            completion(true)
        }
    }

    var onGetAllEventsAndDelete: ((@escaping ([EventStorage]) -> Void) -> Void)?
    func getAllEventsAndDelete(completion: @escaping ([EventStorage]) -> Void) {
        if let handler = onGetAllEventsAndDelete {
            handler(completion)
        } else {
            completion([])
        }
    }

    var onDeleteEvent: ((EventStorage) -> Void)?
    func deleteEvent(_ activity: EventStorage) {
        onDeleteEvent?(activity)
    }

    var onDeleteAllEvents: (() -> Void)?
    func deleteAllEvents() {
        onDeleteAllEvents?()
    }

    var storageStats = DatabaseStats(
        eventCount: 0, totalSizeBytes: 0, maxEventCount: 1000, maxSizeBytes: 5_000_000,
        isCountLimitReached: false, isSizeLimitReached: false)

    var onGetStorageStats: (() -> DatabaseStats)?
    func getStorageStats() -> DatabaseStats {
        return onGetStorageStats?() ?? storageStats
    }

    var hasEventsValue: Bool = false
    var onHasEvents: (() -> Bool)?
    func hasEvents() -> Bool {
        return onHasEvents?() ?? hasEventsValue
    }
}

// MARK: - Mock Deep Link Handler

class MockDeepLinkHandler: DeepLinkHandling {
    var didHandleURLResult: Bool = false
    var lastHandledURL: URL?

    var onDidHandleURL: ((URL) -> Bool)?
    func didHandleURL(_ url: URL) -> Bool {
        lastHandledURL = url
        return onDidHandleURL?(url) ?? didHandleURLResult
    }
}

// MARK: - Mock Network Monitor

class MockNetworkMonitor: NetworkMonitoring {
    var isNetworkAvailable: Bool = true
    var connectionType: ConnectionType = .wifi
    var isConnectedViaWiFi: Bool = true
    var isConnectedViaCellular: Bool = false
    var isReady: Bool = true

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

    var onSaveEventToLocalStorage: ((Event) -> Void)?
    func saveEventToLocalStorage(event: Event) {
        onSaveEventToLocalStorage?(event)
    }

    var onRestoreEventsFromLocalStorage: (((() -> Void)?) -> Void)?
    func restoreEventsFromLocalStorage(completion: (() -> Void)?) {
        onRestoreEventsFromLocalStorage?(completion)
        completion?()
    }

    var onClearLocalEvents: (() -> Void)?
    func clearLocalEvents() {
        onClearLocalEvents?()
    }
}
// swiftlint:enable all
