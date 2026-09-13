//
//  SocketRaceReproViewController.swift
//  UserpilotSample
//
//  Drives the Phoenix socket lifecycle races from Userpilot/ios-sdk#50 and CI-3925.
//  Ported from the 1.0.12 working copy so the same screen can be run against every
//  version before a release.
//
//  ⚠️ The verdict is inverted from the 1.0.12 copy of this screen.
//     On 1.0.12 a crash was a PASS (the race reproduced).
//     Here a crash is a FAIL — it means the serialization this version added regressed.
//
//  Run from Xcode with the debugger attached (either scheme; the SDK hooks are not
//  #if DEBUG so the Release "UserpilotSample" scheme works too). Identify a user first
//  if you want the socket to actually open — Crash B needs a live socket to tear down.
//
//  What each button verifies:
//
//  Crash A  `SocketManager.openSocket()` hops to main, so `URLSessionTransport.connect`
//           can no longer run on the URLSession callback queue while teardown invalidates
//           the session from another queue.
//  Crash B  `Socket.connection` reads under `connectionLock` and returns a strong
//           reference, so a state reader cannot be left holding a freed transport.
//  Crash C  `URLSessionTransport.notifyDelegate` captures the delegate strongly before
//           hopping to main, so there is no `[weak self]` load on main to fault on.
//  Control  The app-side APM hazard itself (objc_disposeClassPair before
//           clearDeallocating). SDK-independent: this one is expected to crash on every
//           version, and exists to prove the instrumentation is really installed.
//

import UIKit
import Userpilot

// swiftlint:disable all

final class SocketRaceReproViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let statusLabel = UILabel()
    private let logView = UITextView()
    private var isRunning = false

    private let userA = "socket_race_user_a"
    private let userB = "socket_race_user_b"

    /// Set once the process-wide URLSession delegate instrumentation is in place. Installing it
    /// swizzles a class method, so it cannot be undone without relaunching the app.
    private static var isAPMInstrumentationInstalled = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Socket Race Repro"
        view.backgroundColor = .systemBackground
        setupBackButton()
        setupUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stop()
    }

    // MARK: - UI

    private func setupBackButton() {
        let backButton = UIButton(type: .system)
        backButton.setTitle("< Back", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 17)
        backButton.contentHorizontalAlignment = .leading
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        let intro = UILabel()
        intro.numberOfLines = 0
        intro.font = .systemFont(ofSize: 14)
        intro.textColor = .secondaryLabel
        intro.text = """
        Socket lifecycle races — ios-sdk#50 and CI-3925.

        On this version a CRASH is a FAIL (the fix regressed) and finishing every \
        cycle is a PASS. That is the opposite of the 1.0.12 copy of this screen.

        Identify a user first so the socket actually opens.

        Crash A → connect() vs. session invalidation
        Crash B → socket state read vs. transport dealloc
        Crash C → main-queue delegate hop vs. transport dealloc
        Control → app-side APM hazard; crashes on every version by design
        """

        let crashAButton = makeButton("Run Crash A (invalidated URLSession)", color: .systemRed)
        crashAButton.addTarget(self, action: #selector(runCrashA), for: .touchUpInside)

        let crashBButton = makeButton("Run Crash B (freed transport readyState)", color: .systemOrange)
        crashBButton.addTarget(self, action: #selector(runCrashB), for: .touchUpInside)

        let crashCButton = makeButton("Run Crash C (delegate hop + APM swizzle)", color: .systemPurple)
        crashCButton.addTarget(self, action: #selector(runCrashC), for: .touchUpInside)

        let controlButton = makeButton("Control: APM weak load (expected crash)", color: .systemIndigo)
        controlButton.addTarget(self, action: #selector(runAPMControl), for: .touchUpInside)

        let stopButton = makeButton("Stop", color: .systemGray)
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)

        statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        statusLabel.numberOfLines = 0
        statusLabel.text = "Idle"

        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.isEditable = false
        logView.backgroundColor = .secondarySystemBackground
        logView.layer.cornerRadius = 8
        logView.translatesAutoresizingMaskIntoConstraints = false
        logView.heightAnchor.constraint(equalToConstant: 220).isActive = true

        [intro, crashAButton, crashBButton, crashCButton, controlButton, stopButton, statusLabel, logView].forEach {
            stackView.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    private func makeButton(_ title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        button.layer.cornerRadius = 10
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return button
    }

    // MARK: - Actions

    @objc private func backTapped() {
        stop()
        navigationController?.popViewController(animated: true)
    }

    @objc private func stopTapped() {
        stop()
        log("Stopped")
        setStatus("Idle")
    }

    @objc private func runCrashA() {
        guard beginRun(.crashA, label: "Crash A") else { return }
        log("Armed Crash A — settings cache bypassed so connect() is driven from the URLSession queue")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.crashALoop()
        }
    }

    @objc private func runCrashB() {
        guard beginRun(.crashB, label: "Crash B") else { return }
        log("Armed Crash B — off-main state reader will park inside Socket.connectionState")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.crashBLoop()
        }
    }

    @objc private func runCrashC() {
        guard beginRun(.crashC, label: "Crash C") else { return }
        installAPMInstrumentation()
        log("Armed Crash C — transport is ISA-swizzled and the main-queue delegate hop is held open")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.crashCLoop()
        }
    }

    @objc private func runAPMControl() {
        guard !isRunning else { return }
        isRunning = true
        installAPMInstrumentation()
        log("Control — racing an app-side weak load against objc_disposeClassPair")
        log("A crash here is EXPECTED on every SDK version; it proves the swizzle is live.")
        setStatus("Control running… crash is expected")

        // Must run on main: the production weak load happened on main.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            APMWeakLoadControl.run { [weak self] message in
                self?.log(message)
            }
            self.stop()
            self.log("Control did NOT crash — the APM window did not open, so Crash C is inconclusive.")
            self.setStatus("Control inconclusive — no crash")
        }
    }

    /// Claims the run and arms the SDK window. Returns `false` if a run is already in flight.
    private func beginRun(_ kind: SocketRaceKind, label: String) -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        UserpilotManager.shared.qaArmSocketRace(kind)
        setStatus("\(label) running… crash = FAIL")
        return true
    }

    private func installAPMInstrumentation() {
        guard !Self.isAPMInstrumentationInstalled else {
            log("APM instrumentation already installed for this process")
            return
        }
        Self.isAPMInstrumentationInstalled = true
        FakeAPMSwizzler.installURLSessionDelegateInstrumentation()
        log("Installed URLSession delegate instrumentation (FirebasePerformance stand-in).")
        log("This is process-wide and permanent — relaunch the app to get a clean state.")
    }

    // MARK: - Crash A
    //
    // Unfixed: the settings-fetch completion arrived on the URLSession delegate queue and went
    // straight into openSocket() -> connect(), which created a URLSession and then a WebSocket
    // task on it. A teardown on another queue invalidated that session in between, so
    // `webSocketTaskForRequest:` threw NSGenericException.
    //
    // Fixed: openSocket() hops to main before touching Phoenix, so parking inside connect()
    // parks the only queue that runs socket lifecycle work — there is nothing left to race.

    private func crashALoop() {
        let cycles = 40
        for index in 1...cycles {
            guard isRunning else { return }
            setStatus("Crash A cycle \(index)/\(cycles) — crash = FAIL")
            log("Cycle \(index): expire settings cache → identify → staggered logout")

            UserpilotManager.shared.qaExpireSettingsCache()
            UserpilotManager.shared.identify(userId: index.isMultiple(of: 2) ? userA : userB)

            // Fire teardown from both main and a background queue across the whole 300ms
            // connect hold, so any unserialized path would land inside the window.
            for delayMs in [40, 90, 150, 220, 280, 340] {
                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + .milliseconds(delayMs)
                ) { [weak self] in
                    guard self?.isRunning == true else { return }
                    UserpilotManager.shared.logout()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs + 20)) { [weak self] in
                    guard self?.isRunning == true else { return }
                    UserpilotManager.shared.logout()
                }
            }

            Thread.sleep(forTimeInterval: 0.55)
        }

        finish("Crash A", cycles: cycles, detail: "connect() was never torn down mid-flight")
    }

    // MARK: - Crash B
    //
    // Unfixed: a state reader on another queue loaded the transport pointer out of a plain
    // stored property, teardown on main released the last reference, and the reader then read
    // `readyState` off freed memory (EXC_BAD_ACCESS).
    //
    // Fixed: `Socket.connection` reads under `connectionLock` and hands the reader its own
    // strong reference, so the transport cannot be deallocated while it is parked.
    //
    // The reader is explicit here: this version's `isSocketOpened` answers from a lock-guarded
    // flag and no longer dereferences the transport at all, so waiting on analytics-flush timing
    // would never enter the window.

    private func crashBLoop() {
        let cycles = 25
        for index in 1...cycles {
            guard isRunning else { return }
            setStatus("Crash B cycle \(index)/\(cycles) — crash = FAIL")
            log("Cycle \(index): identify → wait for socket → off-main state reads + teardown")

            UserpilotManager.shared.identify(userId: userA)
            Thread.sleep(forTimeInterval: 1.6)

            // Off-main readers park inside Socket.connectionState for ~300ms each.
            for _ in 0..<4 {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard self?.isRunning == true else { return }
                    UserpilotManager.shared.qaReadSocketStateOffMain()
                }
            }

            // Event burst keeps the real analytics paths touching the socket too.
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard self?.isRunning == true else { return }
                for eventIndex in 0..<25 {
                    UserpilotManager.shared.track(
                        eventName: "socket_race_\(index)_\(eventIndex)",
                        properties: ["cycle": index]
                    )
                }
            }

            // Tear down while the readers are parked: this is the release that used to free
            // the transport underneath them.
            Thread.sleep(forTimeInterval: 0.08)
            DispatchQueue.main.async {
                UserpilotManager.shared.logout()
                NotificationCenter.default.post(
                    name: UIApplication.didEnterBackgroundNotification,
                    object: nil
                )
            }

            Thread.sleep(forTimeInterval: 0.45)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: UIApplication.willEnterForegroundNotification,
                    object: nil
                )
            }
            Thread.sleep(forTimeInterval: 0.25)
        }

        finish("Crash B", cycles: cycles, detail: "parked readers always saw a live transport")
    }

    // MARK: - Crash C (CI-3925)
    //
    // Unfixed: the transport hopped to main as `DispatchQueue.main.async { [weak self] in
    // self?.delegate?... }`. With the host app's APM instrumentation ISA-swizzling the transport
    // (it is a URLSession delegate), `dealloc` disposed the generated class pair before the
    // runtime zeroed weak references — so the pending weak load on main dereferenced a freed
    // `isa` and faulted in objc_loadWeakRetained.
    //
    // Fixed: `notifyDelegate` captures the delegate strongly on the calling thread and the
    // main-queue closure does not capture `self`, so no weak load happens on main.
    //
    // Pair this with the Control button: if the control does not crash, the swizzle is not
    // actually biting and a clean Crash C run proves nothing.

    private func crashCLoop() {
        let cycles = 40
        for index in 1...cycles {
            guard isRunning else { return }
            setStatus("Crash C cycle \(index)/\(cycles) — crash = FAIL")
            log("Cycle \(index): identify → let the receive loop run → logout from two queues")

            UserpilotManager.shared.identify(userId: index.isMultiple(of: 2) ? userA : userB)
            Thread.sleep(forTimeInterval: 1.5)

            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard self?.isRunning == true else { return }
                for eventIndex in 0..<8 {
                    UserpilotManager.shared.track(
                        eventName: "ci3925_\(index)_\(eventIndex)",
                        properties: ["cycle": index]
                    )
                }
            }

            Thread.sleep(forTimeInterval: 0.12)
            DispatchQueue.main.async {
                UserpilotManager.shared.logout()
            }
            Thread.sleep(forTimeInterval: 0.20)
            DispatchQueue.global(qos: .utility).async {
                UserpilotManager.shared.logout()
            }
            Thread.sleep(forTimeInterval: 0.45)
        }

        finish("Crash C", cycles: cycles, detail: "the delegate hop never touched a dead transport")
    }

    // MARK: - Helpers

    private func finish(_ label: String, cycles: Int, detail: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stop()
            self.log("PASS: \(label) survived \(cycles) cycles — \(detail).")
            self.setStatus("\(label) PASS — no crash in \(cycles) cycles")
        }
    }

    private func stop() {
        isRunning = false
        UserpilotManager.shared.qaDisarmSocketRace()
    }

    private func setStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = text
        }
    }

    private func log(_ text: String) {
        let line = "\(timeStamp())  \(text)\n"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.logView.text += line
            let bottom = NSRange(location: max(0, self.logView.text.count - 1), length: 1)
            self.logView.scrollRangeToVisible(bottom)
        }
        print("[SocketRaceRepro] \(text)")
    }

    private func timeStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    static func newInstance() -> SocketRaceReproViewController {
        SocketRaceReproViewController()
    }
}

// MARK: - App-side APM instrumentation (CI-3925 root cause)
//
// The three CI-3925 Crashlytics stacks all fault in `objc_loadWeakRetained`, which is only
// reachable from a weak load. Weak loads are thread-safe on their own, so racing a `[weak self]`
// resolve against `dealloc` normally just yields nil — verified at ~540M loads.
//
// The missing ingredient is in the host app. Mercury's app runs Firebase Performance Monitoring.
// `FPRNSURLSessionInstrument` ISA-swizzles every URLSession delegate into a runtime-generated
// subclass, and `FPRObjectSwizzler` — retained as an associated object of that delegate — calls
// `objc_disposeClassPair` from its own `dealloc`.
//
// `URLSessionTransport` *is* a URLSession delegate, so it gets instrumented. When it is released
// (session invalidation / reconnect), the runtime runs:
//
//     _objc_rootDealloc
//       -> objc_destructInstance
//            -> _object_remove_associations       // FPRObjectSwizzler dies here
//                 -> objc_disposeClassPair        // generated class freed
//            -> clearDeallocating                 // weak refs zeroed only NOW
//
// Between those last two steps the transport's weak references are still non-nil while its `isa`
// points at freed memory. A concurrent `objc_loadWeakRetained` dereferences that class for its
// `isInitialized()` check and takes EXC_BAD_ACCESS.
//
// Upstream: google/GoogleUtilities#228, firebase-ios-sdk#16074.

/// App-side stand-in for `FPRObjectSwizzler`, reduced to the two behaviours that matter:
/// ISA-swizzle the object into a generated subclass, and dispose that class pair from `deinit`.
final class FakeAPMSwizzler: NSObject {

    /// Seconds to stall in `deinit` after `objc_disposeClassPair`, before the runtime reaches
    /// `clearDeallocating`. Widens the production window; it does not create it.
    static var postDisposeHold: TimeInterval = 0.6

    private static var associationKey: UInt8 = 0

    private weak var swizzledObject: AnyObject?
    private var generatedClass: AnyClass?

    /// Mirrors `FPRNSURLSessionInstrument`: instrument the delegate of every URLSession the
    /// process creates, so the SDK is instrumented without cooperating.
    static func installURLSessionDelegateInstrumentation() {
        let selector = NSSelectorFromString("sessionWithConfiguration:delegate:delegateQueue:")
        guard let method = class_getClassMethod(URLSession.self, selector) else { return }

        typealias Factory = @convention(c) (
            AnyObject, Selector, URLSessionConfiguration, AnyObject?, OperationQueue?
        ) -> URLSession
        let original = unsafeBitCast(method_getImplementation(method), to: Factory.self)

        let replacement: @convention(block) (
            AnyObject, URLSessionConfiguration, AnyObject?, OperationQueue?
        ) -> URLSession = { receiver, configuration, delegate, queue in
            let session = original(receiver, selector, configuration, delegate, queue)
            if let delegate {
                instrument(delegate)
            }
            return session
        }
        method_setImplementation(method, imp_implementationWithBlock(replacement))
    }

    static func instrument(_ object: AnyObject) {
        guard objc_getAssociatedObject(object, &associationKey) == nil else { return }
        guard let originalClass = object_getClass(object) else { return }

        let name = "fake_apm_\(UUID().uuidString)_\(NSStringFromClass(originalClass))"
        guard let generated = name.withCString({ objc_allocateClassPair(originalClass, $0, 0) }) else { return }

        let swizzler = FakeAPMSwizzler()
        swizzler.swizzledObject = object
        swizzler.generatedClass = generated

        // Retained association: the swizzler dies inside the swizzled object's own dealloc.
        objc_setAssociatedObject(object, &associationKey, swizzler, .OBJC_ASSOCIATION_RETAIN)
        objc_registerClassPair(generated)
        object_setClass(object, generated)
    }

    deinit {
        guard let generatedClass else { return }
        self.generatedClass = nil
        objc_disposeClassPair(generatedClass)

        // The swizzled object's `isa` still points at `generatedClass`, and the runtime has not
        // reached `clearDeallocating`, so every weak reference to it is still loadable.
        if Self.postDisposeHold > 0 {
            Thread.sleep(forTimeInterval: Self.postDisposeHold)
        }
    }
}

/// Keeps the transport's only strong reference off the stack, so the background queue that
/// clears it is the thread that runs `dealloc` — as URLSession does when it releases its
/// delegate during `invalidateAndCancel`.
final class TransportHolder {
    var transport: URLSessionTransport?
}

/// Control experiment for the CI-3925 root cause.
///
/// The weak load here is in this harness, not in the SDK, so this reproduces the upstream
/// GoogleUtilities/Firebase hazard on **any** SDK version — including versions where the SDK
/// itself no longer performs a weak load on main. Its job is to prove the instrumentation is
/// actually installed and biting, which is what makes a clean Crash C run meaningful.
///
/// No app token, network, or Firebase account required: `connect()` creates the URLSession
/// synchronously with the transport as its delegate, which is all the instrumentation needs.
enum APMWeakLoadControl {

    /// Must be called on the main thread: the production weak load happened on main.
    static func run(cycles: Int = 20, log: @escaping (String) -> Void) {
        FakeAPMSwizzler.installURLSessionDelegateInstrumentation()

        for cycle in 1...cycles {
            // `connect()` builds URLSession(configuration:delegate:self:), so the swizzle
            // ISA-swizzles the real SDK transport exactly as Firebase Performance would.
            let holder = TransportHolder()
            guard let url = URL(string: "wss://127.0.0.1:1/socket") else { return }
            let transport = URLSessionTransport(url: url)
            holder.transport = transport
            transport.connect(with: [:])

            weak var weakTransport = holder.transport
            let isaName = object_getClass(transport).map(NSStringFromClass) ?? "?"
            log("Cycle \(cycle): isa = \(isaName.prefix(24))… (instrumented: \(isaName.hasPrefix("fake_apm_")))")

            let gate = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .userInitiated).async {
                gate.wait()
                // Last release -> dealloc -> _object_remove_associations
                //   -> FakeAPMSwizzler.deinit -> objc_disposeClassPair
                holder.transport = nil
            }
            gate.signal()

            // Models the pending main-queue `[weak self]` hop that produced all three stacks.
            var loads = 0
            let deadline = Date().addingTimeInterval(FakeAPMSwizzler.postDisposeHold + 0.3)
            while Date() < deadline {
                _ = weakTransport != nil  // objc_loadWeakRetained
                loads += 1
            }
            log("Cycle \(cycle) survived (\(loads) weak loads on main)")
        }

        log("No crash after \(cycles) cycles.")
    }
}

// swiftlint:enable all
