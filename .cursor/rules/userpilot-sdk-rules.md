# Userpilot iOS SDK - Architecture & Rules

## Project Overview
This is the Userpilot iOS SDK - a native Swift framework for in-app user engagement, analytics tracking, and experience delivery. The SDK is designed as a zero-dependency, protocol-oriented framework with thread-safe operations and comprehensive error handling.

## Technology Stack
- **Language**: Swift 5.3+
- **Minimum iOS Version**: iOS 13.0
- **Architecture**: Protocol-oriented with Dependency Injection
- **Package Managers**: Swift Package Manager (SPM) and CocoaPods
- **Dependencies**: Zero external dependencies (self-contained)
- **Testing**: XCTest framework

---

## Code Architecture & Design Patterns

### 1. Protocol-Oriented Programming
**CRITICAL RULE**: All major components MUST be protocol-based for testability and flexibility.

#### Protocol Naming Convention
- **ALWAYS** use the `-ing` suffix for protocol names:
  - ✅ `AnalyticsPublishing`, `DataStoring`, `SessionMonitoring`, `SocketEvents`, `ExperiencesPublishing`
  - ✅ `Logging`, `ThemeHandling`, `ImageLoading`, `PushNotificationMonitoring`
  - ❌ `AnalyticsProtocol`, `DataStorage`, `SessionMonitorProtocol` (incorrect)

#### Protocol Structure
```swift
// ALWAYS define protocols with descriptive names ending in -ing
internal protocol AnalyticsPublishing: AnyObject {
    /// Clear documentation for each method
    func publish(_ event: Event)
    func flush()
    var canRequestEvent: Bool { get }
}

// Implementation follows
internal class AnalyticsPublisher: AnalyticsPublishing {
    // Implementation
}
```

### 2. Dependency Injection Pattern
**MANDATORY**: Use the `DIContainer` for all component initialization.

#### DI Container Rules
- **Lazy Registration**: For components that are expensive to create or may not be needed immediately
  ```swift
  container.registerLazy(SocketEvents.self, initializer: SocketManager.init)
  ```
- **Eager Registration**: For components that must be initialized at SDK startup
  ```swift
  container.registerEager(AnalyticsPublishing.self, initializer: AnalyticsPublisher.init)
  ```

#### Component Initialization Pattern
**ALWAYS** initialize components with `DIContainer` parameter:
```swift
internal class SocketManager {
    private weak var userpilot: Userpilot?
    private let config: Userpilot.Config
    private let storage: DataStoring
    
    init(container: DIContainer) {
        self.userpilot = container.owner
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
    }
}
```

**Key Rules**:
- Use `weak` reference for `userpilot` to avoid retain cycles
- Resolve all dependencies through `container.resolve()`
- NEVER instantiate dependencies directly with `= ClassName()`

### 3. Component Naming Conventions

#### Manager vs Publisher
- **Publisher**: Components that publish/broadcast events or data
  - `AnalyticsPublisher`: Publishes analytics events
  - `ExperiencesPublisher`: Publishes user experiences
- **Manager**: Components that manage resources or connections
  - `SocketManager`: Manages WebSocket connections
- **Monitor**: Components that observe system state
  - `SessionMonitor`: Monitors app lifecycle
- **Handler**: Components that process or transform data
  - `ThemeHandler`: Handles theme data
- **Decorator**: Components that enhance/modify data
  - `AutoPropertyDecorator`: Decorates events with auto properties
- **Detector**: Components that detect system state
  - `SDKSettingsDetector`: Detects and fetches SDK settings

---

## Code Style & Formatting

### 1. File Structure
**MANDATORY** file header format:
```swift
//
//  FileName.swift
//  Userpilot SDK
//
//  Created by [Author Name] on DD/MM/YYYY.
//  Copyright © YYYY Userpilot. All rights reserved.
//
//  [Brief Description]
//  A 2-3 sentence description of what this file does and its purpose.
//
```

### 2. Code Organization with MARK
**REQUIRED**: Organize code sections using `// MARK: -` comments:

```swift
internal class AnalyticsPublisher {
    
    // MARK: - Properties
    
    private let config: Userpilot.Config
    private let storage: DataStoring
    
    // MARK: - Initialization
    
    init(container: DIContainer) {
        // initialization
    }
    
    // MARK: - Public Methods
    
    func publish(_ event: Event) {
        // implementation
    }
    
    // MARK: - Private Methods
    
    private func processEvent(_ event: Event) {
        // implementation
    }
}

// MARK: - AnalyticsPublishing

extension AnalyticsPublisher: AnalyticsPublishing {
    // Protocol implementation
}

// MARK: - SocketSubscription

extension AnalyticsPublisher: SocketSubscription {
    // Protocol implementation
}

// MARK: - Helper Methods

private extension AnalyticsPublisher {
    // Private helper methods
}
```

**Standard MARK sections** (in order):
1. `// MARK: - Properties`
2. `// MARK: - Initialization`
3. `// MARK: - Public Methods` or `// MARK: - SDK API Methods`
4. `// MARK: - Private Methods`
5. Protocol conformance extensions with their own MARKs
6. Helper methods in separate extensions

### 3. Access Control Rules

#### Visibility Guidelines
- **`internal`**: Default for all SDK components (95% of code)
  ```swift
  internal class SocketManager { }
  internal protocol DataStoring { }
  internal func tryCatch(code: () throws -> Void) { }
  ```
- **`public`**: ONLY for SDK's public API surface
  ```swift
  @objc(Userpilot)
  public class Userpilot: NSObject { }
  
  @objc
  public func identify(userId: String, properties: Payload = nil) { }
  
  @objc
  public protocol UserpilotAnalyticsDelegate: AnyObject { }
  ```
- **`private`**: For implementation details within a file
  ```swift
  private func processEvent(_ event: Event) { }
  private var cachedEvent: Event?
  ```
- **`fileprivate`**: Rarely used, only when needed for extensions in same file

**CRITICAL**: Use `@objc` annotation for all public APIs to enable Objective-C interoperability.

### 4. Documentation Standards

#### Documentation Format
**REQUIRED** for all public APIs and protocols:
```swift
/**
 Identifies a user to the SDK, enabling personalized content and behavior tracking.
 
 This method allows the SDK to associate analytics and content with a known user by passing their unique `userId`.
 Additional properties and company details can be provided for more context.
 
 - Parameters:
   - userId: A unique identifier for the user, which is used to track their behavior across sessions.
   - properties: An optional dictionary containing user-specific properties like email, role, or age.
   - company: An optional dictionary containing company-specific properties for users associated with company.
 */
@objc
public func identify(
    userId: String,
    properties: Payload = nil,
    company: Payload = nil
) {
    // implementation
}
```

**RECOMMENDED** for internal methods (especially complex ones):
```swift
/// Opens a WebSocket connection and joins the specified channel.
///
/// - Parameter completion: A closure that is called when the connection attempt completes.
private func openSocket() {
    // implementation
}
```

Use `///` for single-line documentation, `/** ... */` for multi-line.

---

## Threading & Concurrency

### 1. Queue Management

#### Named Dispatch Queues
**ALWAYS** use constants for queue labels (defined in `Constants.swift`):
```swift
internal struct DispatchQueueConstants {
    static let EVENT_QUEUE = "com.userpilot.event-queue"
    static let EXPERIENCE_QUEUE = "com.userpilot.experience-queue"
    static let DELAY_QUEUE = "com.userpilot.delay-queue"
    static let DI_CONTAINER_QUEUE = "com.userpilot.dicontainer-queue"
    static let THROTTLE_QUEUE = "com.userpilot.throttle-queue"
}
```

#### Queue Creation Pattern
```swift
private let componentQueue = DispatchQueue(
    label: DispatchQueueConstants.EVENT_QUEUE,
    qos: .utility,
    attributes: .concurrent
)
```

**QoS Guidelines**:
- `.userInteractive`: UI updates, animations (use sparingly)
- `.userInitiated`: User-requested actions
- `.utility`: Long-running tasks (default for most SDK operations)
- `.background`: Tasks not visible to user

### 2. Thread Safety Patterns

#### Read-Write Lock Pattern
**USE** `ReadWriteLock` for concurrent reads with exclusive writes:
```swift
private lazy var readWriteLock = ReadWriteLock()
private var eventsToFlush = [Event]()

func trackEvent(_ event: Event) {
    readWriteLock.write { [weak self] in
        guard let self else { return }
        self.eventsToFlush.append(event)
    }
}
```

#### Barrier Pattern for DIContainer
**USE** barriers for exclusive write access:
```swift
func register<Component>(_ type: Component.Type, value: Component) {
    componentQueue.async(flags: .barrier) {
        self.components[String(describing: Component.self)] = value
    }
}
```

### 3. Queue Helpers

#### performOn() Helper
**USE** the `performOn()` helper for cleaner queue dispatching:
```swift
performOn(.main) { [weak self] in
    self?.updateUI()
}

performOn(.background) { [weak self] in
    self?.processData()
}
```

**Available queue types**:
- `.main`: Main thread for UI updates
- `.background`: Background thread for heavy tasks
- `.lowPriority`: Low priority global queue
- `.highPriority`: High priority global queue

### 4. Memory Management

#### Weak References
**ALWAYS** use `[weak self]` in closures to prevent retain cycles:
```swift
socketManager.registerCallback(self)

phoenixSocket.onMessage(callback: { [weak self] message in
    self?.$socketSubscription.invoke { $0.onNewMessage(message) }
})

delay(1.0) { [weak self] in
    self?.processNextExperience()
}
```

**Exception**: Only use `[unowned self]` when you are 100% certain self will outlive the closure.

---

## Error Handling

### tryCatch Pattern
**ALWAYS** wrap potentially throwing operations in `tryCatch`:

```swift
// For operations that don't return values
func publish(_ event: Event) {
    tryCatch {
        guard sessionMonitorer?.isAppActive ?? false else {
            cacheEvent(event)
            return
        }
        // ... rest of implementation
    }
}

// For operations that return values
func loadData() -> Data? {
    return tryCatch {
        let data = try JSONEncoder().encode(object)
        return data
    }
}
```

**When to use**:
- Socket operations
- JSON parsing/encoding
- File I/O operations
- Any operation that might throw

**Purpose**: Prevents crashes while allowing graceful degradation.

---

## State Management & Storage

### 1. Storage Protocol Pattern

**ALWAYS** define storage needs as protocol:
```swift
internal protocol DataStoring: AnyObject {
    var socketURL: String { get set }
    var userId: String { get set }
    var user: String { get set }
    var sessionDate: Date? { get set }
}
```

**Implementation uses UserDefaults**:
```swift
internal class Storage: DataStoring {
    private enum Key: String {
        case socketURL
        case userId
    }
    
    private lazy var defaults = UserDefaults(
        suiteName: "\(Storage.userDefaultSuiteName)\(Bundle.main.identifier)"
    )
    
    var socketURL: String {
        get { read(.socketURL, defaultValue: "") }
        set { write(.socketURL, newValue: newValue) }
    }
}
```

**Rules**:
- Use enum for UserDefaults keys
- Suite name includes bundle identifier for isolation
- Generic read/write methods for consistency

### 2. Property Observers
When state changes require side effects, use computed properties or didSet:
```swift
var socketState: SocketState = .closed {
    didSet {
        if socketState == .opened {
            $socketSubscription.invoke { $0.onSocketOpened() }
        }
    }
}
```

---

## Logging

### 1. Logger Configuration
**USE** OSLog with consistent subsystem and categories:
```swift
// In Config
let logger = OSLog(userpilotCategory: GeneralConstants.USERPILOT_LOGGING_CATEOGRY)

// Extension provides convenience
extension OSLog {
    convenience init(userpilotCategory category: String) {
        self.init(subsystem: "com.userpilot.sdk", category: category)
    }
}
```

### 2. Logging Levels & Emoji Convention
**FOLLOW** this consistent emoji-based logging pattern:

```swift
logger.debug("🔄 SOCKET already connecting, skipping connect")
logger.info("✅ SOCKET opened")
logger.info("🚀 SOCKET channel joined")
logger.info("👤 USER %{public}@", storage.user)
logger.error("❗ SOCKET error - details %{public}@", error.localizedDescription)
logger.error("⚠️ SOCKET channel join failed: %{public}@", message.payload)
logger.error("🛑 SOCKET closed")
```

**Emoji Guide**:
- ✅ Success, completion
- ❌ Failure, error
- ❗ Critical error
- ⚠️ Warning
- 🔄 Retry, reconnect
- 🚀 Start, launch
- 🛑 Stop, close
- 👤 User-related
- ⚙️ Settings, configuration
- 🌏 SDK initialization
- ✈️ Network message
- ‼️ Important notice

### 3. Privacy Annotations
**USE** `%{public}@` for values that should be visible in logs:
```swift
logger.info("User ID: %{public}@", userId)
logger.debug("Socket URL: %{public}@", socketURL)
```

**USE** `%{private}@` for sensitive data (default if not specified):
```swift
logger.debug("API token: %{private}@", token) // Redacted in logs
```

---

## Delegate Patterns

### 1. Multicast Delegates
**USE** `@Multicast` property wrapper for multiple observers:

```swift
internal protocol SocketSubscription: AnyObject {
    func onSocketClosed()
    func onSocketOpened()
}

internal class SocketManager {
    @Multicast var socketSubscription: SocketSubscription
    
    func registerCallback(_ subscription: SocketSubscription) {
        self.socketSubscription = subscription
    }
    
    private func notifySubscribers() {
        $socketSubscription.invoke { $0.onSocketOpened() }
    }
}
```

**Rules**:
- Use `@Multicast` for internal observers
- Use `weak var delegate` for public delegates
- Provide default implementations in protocol extensions

### 2. Public Delegates
**STANDARD PATTERN** for SDK delegates:
```swift
// Public delegate protocol
@objc
public protocol UserpilotAnalyticsDelegate: AnyObject {
    func didTrack(
        analytic: UserpilotAnalytic,
        value: String,
        properties: [String: Any]?
    )
}

// In main SDK class
public class Userpilot: NSObject {
    @objc public weak var analyticsDelegate: UserpilotAnalyticsDelegate?
    
    // Call delegate on main thread
    private func notifyDelegate() {
        performOn(.main) { [weak self] in
            self?.analyticsDelegate?.didTrack(
                analytic: .identify,
                value: userId,
                properties: properties
            )
        }
    }
}
```

**Critical Rules**:
- Public delegates MUST be `@objc` and `weak`
- ALWAYS call delegates on main thread
- Provide clear documentation for delegate methods

---

## Testing Guidelines

### 1. Test File Structure
- Test files mirror source structure: `Sources/Userpilot/X.swift` → `Tests/UserpilotTests/XTests.swift`
- Use `XCTest` framework
- Group tests by functionality

### 2. Mock Objects
**CREATE** protocol-based mocks:
```swift
internal class MockAnalyticsPublisher: AnalyticsPublishing {
    var publishedEvents: [Event] = []
    var flushedCount = 0
    
    func publish(_ event: Event) {
        publishedEvents.append(event)
    }
    
    func flush() {
        flushedCount += 1
    }
}
```

### 3. Test Helpers
**USE** `#if DEBUG` for test helpers:
```swift
#if DEBUG
internal extension AnalyticsPublisher {
    func mockGetCachedEvent() -> Event? {
        return cachedEvent
    }
    
    func mockGetEventsToFlush() -> [Event] {
        return eventsToFlush
    }
}
#endif
```

---

## Extension Guidelines

### 1. File Organization
**SEPARATE** extensions by purpose, not by type:

**Good** ✅:
- `String+Extensions.swift`: All String extensions
- `UIView+Extensions.swift`: All UIView extensions
- `Date+Extensions.swift`: All Date extensions

**Bad** ❌:
- `Validations.swift`: Mix of String, Int validations
- `Helpers.swift`: Generic catch-all

### 2. Extension Structure
```swift
//
//  String+Extensions.swift
//  Userpilot SDK
//

import Foundation

extension String {
    /// Removes leading and trailing whitespace
    var trim: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Checks if string is not empty after trimming
    var isNotEmpty: Bool {
        return !trim.isEmpty
    }
    
    /// Converts string to JSON dictionary
    func toJSONDictionary() -> [String: Any]? {
        // implementation
    }
}
```

### 3. Computed Properties vs Methods
**USE** computed properties for:
- Simple transformations without parameters
- State queries
```swift
var isEmpty: Bool { count == 0 }
var isNotEmpty: Bool { !isEmpty }
```

**USE** methods for:
- Operations with parameters
- Actions that modify state
```swift
func trim() -> String { }
func toJSONString() -> String? { }
```

---

## Model & Data Structure Guidelines

### 1. Model Structure
**USE** structs for models (value types):
```swift
internal struct Event {
    let type: EventType
    let properties: Payload
    let company: Payload
    
    // Computed properties for convenience
    var eventName: String {
        return type.eventName
    }
    
    var isIdentifyEvent: Bool {
        if case .identify = type { return true }
        return false
    }
}
```

### 2. Enums with Associated Values
**PREFER** enums with associated values for type safety:
```swift
internal enum EventType {
    case identify(String)  // userId
    case screen(String)    // screenTitle
    case event(String)     // eventName
    
    var eventName: String {
        switch self {
        case .identify: return "identify"
        case .screen: return "screen"
        case .event: return "event"
        }
    }
}
```

### 3. JSON Codable
**IMPLEMENT** custom Codable when needed:
```swift
internal struct FlowContent: Codable {
    let id: Int
    let type: FlowType
    let screens: [String]
    
    enum CodingKeys: String, CodingKey {
        case id = "mobile_content_id"
        case type = "mobile_content_type"
        case screens = "screen_names"
    }
}
```

---

## Constants & Configuration

### 1. Constants Organization
**DEFINE** constants in dedicated structs:
```swift
// Constants.swift
internal struct DispatchQueueConstants {
    static let EVENT_QUEUE = "com.userpilot.event-queue"
    static let EXPERIENCE_QUEUE = "com.userpilot.experience-queue"
}

internal struct GeneralConstants {
    static let PATH_NAME = "/mobile/v1/events/websocket"
    static let SESSION_DURATION = TimeInterval(30 * 60)
    static let CONFIGURATION_DURATION = TimeInterval(30 * 60)
}
```

### 2. Type Aliases
**USE** meaningful type aliases:
```swift
public typealias Payload = [String: Any]?
```

### 3. Magic Numbers
**AVOID** magic numbers, use named constants:
```swift
// Bad ❌
if difference > 1800 { }

// Good ✅
static let SESSION_DURATION = TimeInterval(30 * 60) // 30 minutes
if difference > GeneralConstants.SESSION_DURATION { }
```

---

## Linting & Code Quality

### 1. SwiftLint Integration
**ENABLE** SwiftLint for all files. Common rules used in this project:

**Disable specific rules when necessary**:
```swift
// swiftlint:disable file_length
// Large file with good reason

// swiftlint:disable:next force_cast
let component = initializer(self) as! Component

// swiftlint:disable identifier_name
internal struct DispatchQueueConstants {
    static let EVENT_QUEUE = "com.userpilot.event-queue"
}
// swiftlint:enable identifier_name
```

### 2. Line Length
**TARGET**: 120 characters max per line
**USE** line breaks for long method signatures:
```swift
func publishInternalSDKEvent(
    _ sdkEvent: SDKEvent,
    socketSubscription: SocketSubscription?
) {
    // implementation
}
```

### 3. Cyclomatic Complexity
**TARGET**: Max complexity of 10 per method
**REFACTOR** complex methods:
```swift
// Instead of one complex method
func processEvent(_ event: Event) {
    // 50 lines of complex logic
}

// Break into smaller methods
func processEvent(_ event: Event) {
    guard validateEvent(event) else { return }
    let processedData = transformEvent(event)
    sendToBackend(processedData)
}
```

---

## Adding New Features

### Step-by-Step Process for Adding Features

#### 1. Define Protocol First
```swift
// 1. Create protocol in Protocols/ directory
internal protocol NewFeatureHandling: AnyObject {
    func handleFeature()
    var isEnabled: Bool { get }
}
```

#### 2. Create Implementation
```swift
// 2. Create implementation file in appropriate directory
internal class NewFeatureHandler: NewFeatureHandling {
    
    // MARK: - Properties
    
    private let config: Userpilot.Config
    private let storage: DataStoring
    
    // MARK: - Initialization
    
    init(container: DIContainer) {
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
    }
    
    // MARK: - NewFeatureHandling
    
    func handleFeature() {
        tryCatch {
            // Implementation
        }
    }
    
    var isEnabled: Bool {
        return config.featureEnabled
    }
}
```

#### 3. Register in DIContainer
```swift
// In Userpilot.swift initializeContainer()
container.registerLazy(NewFeatureHandling.self, initializer: NewFeatureHandler.init)
// Or
container.registerEager(NewFeatureHandling.self, initializer: NewFeatureHandler.init)
```

#### 4. Add Public API (if needed)
```swift
// In Userpilot.swift
extension Userpilot {
    /**
     Enables the new feature.
     
     - Parameter config: Configuration for the feature
     */
    @objc
    public func enableNewFeature(config: FeatureConfig) {
        newFeatureHandler.handleFeature()
    }
}
```

#### 5. Create Tests
```swift
// In Tests/UserpilotTests/NewFeatureHandlerTests.swift
import XCTest
@testable import Userpilot

final class NewFeatureHandlerTests: XCTestCase {
    
    var sut: NewFeatureHandler!
    var mockContainer: DIContainer!
    
    override func setUp() {
        super.setUp()
        mockContainer = DIContainer()
        // Setup mocks
        sut = NewFeatureHandler(container: mockContainer)
    }
    
    override func tearDown() {
        sut = nil
        mockContainer = nil
        super.tearDown()
    }
    
    func testFeatureHandling() {
        // Given
        let expectedResult = true
        
        // When
        sut.handleFeature()
        
        // Then
        XCTAssertEqual(sut.isEnabled, expectedResult)
    }
}
```

---

## Refactoring Guidelines

### When to Refactor
1. **Cyclomatic Complexity > 10**: Break into smaller methods
2. **File Length > 500 lines**: Consider splitting into multiple files/extensions
3. **Duplicate Code**: Extract into shared helper or extension
4. **Hard-to-Test Code**: Refactor to use protocols and DI

### Refactoring Process
1. **Write Tests First**: Ensure existing behavior is tested
2. **Make Changes Incrementally**: Small, focused changes
3. **Run Tests After Each Change**: Ensure no regression
4. **Update Documentation**: Keep docs in sync with code

### Common Refactoring Patterns

#### Extract Method
```swift
// Before
func processEvent(_ event: Event) {
    if socketManager.isSocketOpened {
        // 20 lines of event processing
    } else {
        // 15 lines of caching logic
    }
}

// After
func processEvent(_ event: Event) {
    if socketManager.isSocketOpened {
        sendEventImmediately(event)
    } else {
        cacheEventForLater(event)
    }
}

private func sendEventImmediately(_ event: Event) {
    // 20 lines of event processing
}

private func cacheEventForLater(_ event: Event) {
    // 15 lines of caching logic
}
```

#### Extract Protocol
```swift
// Before
class SocketManager {
    func connect() { }
    func close() { }
    func publish() { }
}

// After
internal protocol SocketEvents: AnyObject {
    func connect()
    func close()
    func publish()
}

internal class SocketManager: SocketEvents {
    // Implementation
}
```

---

## Performance Optimization

### 1. Lazy Loading
**USE** lazy properties for expensive initializations:
```swift
private lazy var analyticsPublisher = container.resolve(AnalyticsPublishing.self)
private lazy var socketManager = container.resolve(SocketEvents.self)
```

### 2. Queue Selection
**CHOOSE** appropriate QoS for operations:
- Critical UI updates: `.userInteractive`
- User-initiated actions: `.userInitiated`
- Background processing: `.utility` or `.background`

### 3. Memory Management
- **Avoid** creating unnecessary copies of large data structures
- **Use** weak references to prevent retain cycles
- **Clear** caches when appropriate (e.g., on logout)

### 4. Batch Operations
**BATCH** multiple operations when possible:
```swift
// Instead of multiple individual writes
for item in items {
    storage.write(item)
}

// Batch write
storage.writeAll(items)
```

---

## Security & Privacy

### 1. Data Sanitization
**VALIDATE** and sanitize all user input:
```swift
func identify(userId: String, properties: Payload = nil) {
    guard userId.trim().isNotEmpty else {
        logger.error("Invalid user id - empty string")
        return
    }
    
    let sanitizedProperties = sanitizePayload(
        properties,
        payloadName: "properties",
        logger: logger
    )
    
    // Process sanitized data
}
```

### 2. Supported Property Types
**ONLY** allow these types in payloads:
- `String`
- `Bool`
- `Int`, `Int64`
- `Double`, `Float`
- `NSNumber`

**REJECT** all other types with clear error messages.

### 3. Keychain Usage
**USE** Keychain for sensitive data (e.g., tokens, API keys):
```swift
// Store in Keychain, not UserDefaults
KeychainHelper.save(token, forKey: "api_token")
```

---

## CI/CD & Build Configuration

### 1. Swift Package Manager
**MAINTAIN** `Package.swift` with:
- Correct platform version (iOS 13+)
- All resources listed explicitly
- Test target configured

### 2. CocoaPods
**MAINTAIN** `Userpilot.podspec` with:
- Matching version numbers
- Correct dependency specifications
- Platform and deployment target

### 3. Version Management
**UPDATE** version in:
1. `Version.swift`: `let userpilotVersion = "X.Y.Z"`
2. `Userpilot.podspec`: `spec.version = "X.Y.Z"`
3. Git tag: `vX.Y.Z`

---

## Common Patterns Reference

### 1. Async Delay
```swift
delay(1.0) { [weak self] in
    self?.doSomething()
}
```

### 2. Thread-Safe State Updates
```swift
readWriteLock.write { [weak self] in
    guard let self else { return }
    self.state = newState
}
```

### 3. Safe Optional Unwrapping
```swift
guard let value = optionalValue,
      value.isNotEmpty,
      !value.isEmpty else {
    return
}
```

### 4. Multicast Notification
```swift
$socketSubscription.invoke { $0.onSocketOpened() }
```

### 5. Main Thread Dispatch
```swift
performOn(.main) { [weak self] in
    self?.updateUI()
}
```

---

## Objective-C Interoperability

### 1. @objc Annotations
**REQUIRED** for all public APIs:
```swift
@objc(Userpilot)
public class Userpilot: NSObject {
    
    @objc
    public func identify(userId: String) { }
    
    @objc(sdkVersion)
    public static func version() -> String { }
}
```

### 2. NS Prefixes
**AVOID** NS prefixes in Swift. Use native Swift types:
- ✅ `String`, `Array`, `Dictionary`
- ❌ `NSString`, `NSArray`, `NSDictionary`

### 3. Enums for Objective-C
**USE** `@objc` enums with raw values:
```swift
@objc
public enum UserpilotAnalytic: Int {
    case identify = 0
    case screen = 1
    case event = 2
}
```

---

## Documentation

### 1. Inline Documentation
- **Public APIs**: MUST have full documentation
- **Internal protocols**: SHOULD have documentation
- **Private methods**: OPTIONAL but recommended for complex logic

### 2. README Updates
**UPDATE** README.md when:
- Adding new public APIs
- Changing initialization requirements
- Adding new dependencies
- Changing minimum iOS version

### 3. DocC Documentation
**MAINTAIN** `.docc` documentation for:
- Complex features (Push Notifications, Navigation)
- Integration guides
- Best practices

---

## Quick Reference Checklist

### Before Committing Code
- [ ] All files have proper headers
- [ ] MARK comments are in place
- [ ] SwiftLint passes with no warnings
- [ ] All new code has appropriate access control
- [ ] Thread safety is considered
- [ ] Memory leaks are prevented ([weak self])
- [ ] Error handling with tryCatch is used
- [ ] Tests are written/updated
- [ ] Documentation is updated
- [ ] Public APIs have @objc annotation
- [ ] Logging uses appropriate emoji conventions

### Adding New Component
- [ ] Protocol defined with -ing suffix
- [ ] Implementation created
- [ ] Registered in DIContainer
- [ ] Tests created
- [ ] Documentation added
- [ ] Public API exposed (if needed)

### Refactoring Existing Code
- [ ] Tests exist and pass before changes
- [ ] Changes are incremental
- [ ] Tests pass after each change
- [ ] Documentation updated
- [ ] No breaking changes to public API

---

## AI Assistant Instructions

When working with this codebase:

1. **ALWAYS** follow the protocol-oriented approach with -ing suffix naming
2. **ALWAYS** use DIContainer for dependency injection
3. **ALWAYS** consider thread safety and use appropriate patterns
4. **ALWAYS** wrap operations in tryCatch for safety
5. **ALWAYS** use weak references in closures
6. **ALWAYS** add proper MARK comments
7. **ALWAYS** follow the emoji logging conventions
8. **ALWAYS** use internal visibility by default
9. **ALWAYS** add @objc to public APIs
10. **NEVER** create external dependencies
11. **NEVER** use force unwrapping (except in fatal error cases)
12. **NEVER** ignore memory management
13. **PREFER** protocols over concrete types
14. **PREFER** structs over classes for models
15. **PREFER** computed properties for simple getters

When asked to add features:
1. Start with protocol definition
2. Create implementation with DI
3. Register in container
4. Add tests
5. Expose public API if needed
6. Update documentation

When asked to refactor:
1. Understand existing tests
2. Make incremental changes
3. Run tests frequently
4. Update documentation
5. Preserve public API compatibility

---

## Examples from Codebase

### Perfect Protocol Example
```swift
internal protocol AnalyticsPublishing: AnyObject {
    func publish(_ event: Event)
    func flush()
    func resume()
    func reset()
    var canRequestEvent: Bool { get }
}
```

### Perfect DI Implementation Example
```swift
internal class AnalyticsPublisher: AnalyticsPublishing {
    private weak var userpilot: Userpilot?
    private let config: Userpilot.Config
    private let storage: DataStoring
    private let socketManager: SocketEvents
    
    init(container: DIContainer) {
        self.userpilot = container.owner
        self.config = container.resolve(Userpilot.Config.self)
        self.storage = container.resolve(DataStoring.self)
        self.socketManager = container.resolve(SocketEvents.self)
    }
}
```

### Perfect Threading Example
```swift
private let eventQueue = DispatchQueue(
    label: DispatchQueueConstants.EVENT_QUEUE,
    qos: .utility,
    attributes: .concurrent
)

private lazy var readWriteLock = ReadWriteLock()

func trackEvent(_ event: Event) {
    readWriteLock.write { [weak self] in
        guard let self else { return }
        self.eventsToFlush.append(event)
    }
}
```

### Perfect Public API Example
```swift
/**
 Identifies a user to the SDK, enabling personalized content.
 
 - Parameters:
   - userId: A unique identifier for the user
   - properties: Optional user properties
   - company: Optional company information
 */
@objc
public func identify(
    userId: String,
    properties: Payload = nil,
    company: Payload = nil
) {
    guard userId.trim().isNotEmpty else {
        logger.error("Invalid user id - empty string")
        return
    }
    analyticsPublisher.publish(
        Event(
            type: .identify(userId.trim()),
            properties: properties,
            company: company
        )
    )
}
```

---

This document represents the complete coding standards, patterns, and best practices for the Userpilot iOS SDK. Follow these rules to maintain consistency, quality, and reliability across the codebase.

