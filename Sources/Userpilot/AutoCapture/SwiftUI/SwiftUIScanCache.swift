//
//  SwiftUIScanCache.swift
//  Userpilot
//
//  Owns the cached result of the latest SwiftUI scan and the orchestration that
//  produces it:
//    - the SwiftUI reflection inventory (element titles + which are interactive)
//    - the display-list text map (exact frames + the painting CALayer)
//    - the click-time accessors the resolver reads (never re-evaluates `body`)
//
//  Scans are event-driven (screen appear + scroll settle), idle-gated, and
//  debounced — there is no periodic timer. Rescans are scheduled by the SDK's
//  existing swizzler (Phase 2 wiring); this type does not swizzle anything.
//
//  Per scan, two phases run (the sample's Phase-1 UIKit dump is NOT ported —
//  the SDK's existing UIKit extraction owns that):
//    Phase A — `SwiftUIReflection.extractInventory` evaluates the SwiftUI view
//              graph for button/text titles. This is the ONLY place `body` is
//              evaluated; the touch path just reads the cached result.
//    Phase B — `DisplayListTextMap.textMap` reads exact text geometry from the
//              render tree.
//

// swiftlint:disable closure_parameter_position file_length function_body_length identifier_name line_length type_body_length
// swiftlint:disable:previous blanket_disable_command

import UIKit

internal final class SwiftUIScanCache {

    static let shared = SwiftUIScanCache()

    enum RescanReason { case screenAppeared, touchEnded, manual, debounced }

    // MARK: - State

    private var debouncer: ScanDebouncer!
    private var latestInventory: [SwiftUIReflection.ViewRecord] = []
    private var latestTextMap: [DisplayListTextMap.Entry] = []
    private var latestInteractiveRecords: [(title: String, viewType: String)] = []
    private weak var inventoryHost: UIViewController?
    private let snapshotLock = NSLock()

    // Screen-identity generation counter (F1). `markScreenChanged()` bumps
    // `currentScreenGen` on every screen appearance; each scan stamps the
    // snapshot it produces with `cacheGen`. Readers treat a snapshot whose
    // `cacheGen` differs from `currentScreenGen` as stale (return empty) so a
    // fast first tap after navigation can never resolve against the old screen.
    // Both are touched only under `snapshotLock`.
    private var currentScreenGen = 0
    private var cacheGen = -1

    // The reason for the next debounced background scan. `scheduleRescan` records
    // it (sanitizing `.manual` → `.debounced`) so the coalesced background scan
    // is attributed correctly and selects the background budget. Touched only on
    // main, under `snapshotLock`.
    private var pendingBackgroundReason: RescanReason = .debounced
    private var becomeActiveObserver: NSObjectProtocol?
    private var memoryWarningObserver: NSObjectProtocol?
    private static let backgroundScanDebounceDelay: TimeInterval = 0.5

    private init() {
        debouncer = ScanDebouncer(delay: Self.backgroundScanDebounceDelay) { [weak self] in
            self?.performPendingBackgroundScan()
        }
    }

    // MARK: - Lifecycle

    func start() {
        registerMemoryWarningEviction()
    }

    func stop() {
        debouncer.cancel()
        clearCaches()
        if let token = becomeActiveObserver {
            NotificationCenter.default.removeObserver(token)
            becomeActiveObserver = nil
        }
        if let token = memoryWarningObserver {
            NotificationCenter.default.removeObserver(token)
            memoryWarningObserver = nil
        }
    }

    /// Requests a debounced, idle-gated background re-scan. Called on screen
    /// appear and at touch-sequence end (so lazy rows revealed by a scroll are
    /// picked up). Records the reason so the coalesced background scan is
    /// attributed correctly and selects the background budget.
    ///
    /// Contract: this queues background work only. `.manual` is reserved for the
    /// synchronous first-tap path in `prepareForTapResolutionIfNeeded()`; if a
    /// caller passes it here it is stored as `.debounced` so a queued scan can
    /// never claim the tight tap-path budget.
    ///
    /// Threading: marshals to main so `pendingBackgroundReason` is only touched
    /// on the main thread.
    func scheduleRescan(reason: RescanReason = .debounced) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.scheduleRescan(reason: reason) }
            return
        }

        #if DEBUG
        assert(reason != .manual,
               "scheduleRescan(reason:) is background-only; call performScan(reason: .manual) directly for tap-path scans.")
        #endif

        let backgroundReason: RescanReason = (reason == .manual) ? .debounced : reason

        snapshotLock.lock()
        pendingBackgroundReason = backgroundReason
        snapshotLock.unlock()
        debouncer.schedule()
        #if DEBUG
        SwiftUIScanLog.log("scheduleRescan(reason=\(reason)) → pendingBg=\(backgroundReason), "
            + "debounce armed (\(Self.backgroundScanDebounceDelay)s)")
        #endif
    }

    /// Marks that the visible screen changed (called from the `viewDidAppear`
    /// hook). Invalidates the cached snapshot for stale-aware readers until the
    /// next scan stamps the new generation. Marshals to main so the counter is
    /// only mutated on the main thread.
    func markScreenChanged() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.markScreenChanged() }
            return
        }
        snapshotLock.lock()
        currentScreenGen &+= 1
        let gen = currentScreenGen
        let stampedGen = cacheGen
        snapshotLock.unlock()
        #if DEBUG
        SwiftUIScanLog.log("markScreenChanged → currentGen=\(gen) (cacheGen=\(stampedGen) now STALE)")
        #endif
    }

    /// Ensures the tap resolver has a usable SwiftUI title snapshot. Screen
    /// appearance scans are debounced; a fast first tap after navigation can
    /// arrive before that debounce fires. Scrolling can also materialize new
    /// SwiftUI render-tree text without changing the screen generation, so the
    /// check is point-aware: if the current text map cannot cover this tap,
    /// refresh synchronously before resolving the event.
    func prepareForTapResolutionIfNeeded(at pointInWindow: CGPoint? = nil, in window: UIWindow? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.prepareForTapResolutionIfNeeded(at: pointInWindow, in: window)
            }
            return
        }

        // Rescan when EITHER the screen generation changed (real UIViewController
        // navigation — modals, separate hosting controllers), the cache holds
        // no display-list text yet, OR a same-screen scroll has made the cached
        // text map miss the tapped point.
        //
        // The empty-text-map trigger matters for SwiftUI `NavigationStack`:
        // pushing a destination swaps content inside the SAME hosting controller
        // with NO `viewDidAppear`, so the generation never bumps. We key off the
        // text map (the reliable on-screen source), NOT the reflection inventory
        // — reflection is always empty on a NavigationStack root, so keying off
        // it would force a synchronous scan on every single tap. Once the text
        // map is populated (by this scan or the debounced touch-end rescan), taps
        // read the cache directly.
        let stampedGen: Int
        let gen: Int
        let textMap: [DisplayListTextMap.Entry]
        let interactive: [(title: String, viewType: String)]
        snapshotLock.lock()
        stampedGen = cacheGen
        gen = currentScreenGen
        textMap = latestTextMap
        interactive = latestInteractiveRecords
        snapshotLock.unlock()

        let missesTapPoint: Bool
        if stampedGen == gen,
           !textMap.isEmpty,
           let pointInWindow,
           let window {
            missesTapPoint = !textMap.contains {
                Self.canResolveTitle(from: $0, interactive: interactive,
                                     at: pointInWindow, in: window)
            }
        } else {
            missesTapPoint = false
        }
        let needsScan = (stampedGen != gen) || textMap.isEmpty || missesTapPoint

        #if DEBUG
        SwiftUIScanLog.log("prepareForTap: cacheGen=\(stampedGen) currentGen=\(gen) needsScan=\(needsScan)"
            + (missesTapPoint ? " tapPointMiss=true" : "")
            + (needsScan ? " → cancel debounce + synchronous performScan(.manual)" : " → use cache as-is"))
        #endif

        guard needsScan else { return }
        debouncer.cancel()
        performScan(reason: .manual)
    }

    private static func canResolveTitle(from entry: DisplayListTextMap.Entry,
                                        interactive: [(title: String, viewType: String)],
                                        at pointInWindow: CGPoint,
                                        in window: UIWindow) -> Bool {
        guard let title = entry.title,
              entry.containsWindowPoint(pointInWindow, in: window) else { return false }
        return interactive.contains(where: { $0.title == title }) || entry.isStyledControlTitleCandidate
    }

    // MARK: - Scan

    private func performScan(reason: RescanReason) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.performScan(reason: reason) }
            return
        }
        // During launch the app is still `.inactive`; park the scan until
        // active so no scan work lands inside the launch transition. Re-stamp
        // the (sanitized) reason so the deferred re-run, re-armed via the
        // debouncer in `scheduleScanWhenActive()`, is still attributed
        // correctly — `performPendingBackgroundScan()` already consumed it.
        guard UIApplication.shared.applicationState == .active else {
            snapshotLock.lock()
            pendingBackgroundReason = (reason == .manual) ? .debounced : reason
            snapshotLock.unlock()
            #if DEBUG
            SwiftUIScanLog.log("performScan(\(reason)) DEFERRED — app not active")
            #endif
            scheduleScanWhenActive()
            return
        }
        guard let window = Self.keyVisibleWindow() else {
            #if DEBUG
            SwiftUIScanLog.log("performScan(\(reason)) ABORTED — no key visible window")
            #endif
            return
        }

        // Budget by reason: only the synchronous first-tap (`.manual`) scan uses
        // the tight tap-path budget; every background reason uses the larger one.
        //
        // CRITICAL: the two phases get INDEPENDENT, freshly-computed deadlines.
        // They must NOT share one deadline — reflection (Phase A) can be both
        // expensive and fruitless (re-evaluating a NavigationStack root's body
        // rebuilds an empty navigation state), and a shared deadline let it
        // consume the whole scan and starve the display-list phase to zero. The
        // display-list text map is the PRIMARY title source (it reads the live
        // render tree, not re-evaluated bodies), so it runs FIRST with its own
        // budget and can never be starved.
        let budget = (reason == .manual) ? SwiftUIScanBudget.tapPath : SwiftUIScanBudget.background
        #if DEBUG
        let budgetName = (reason == .manual) ? "tapPath" : "background"
        SwiftUIScanLog.log("performScan(\(reason)) START budget=\(budgetName) currentGen=\(currentScreenGen)")
        let scanStart = CFAbsoluteTimeGetCurrent()
        #endif

        // Phase B (primary) — display-list text map: exact frames + resolved
        // strings for every rendered SwiftUI text, read from the render tree.
        // Own deadline (= the scan budget) so reflection can never starve it.
        let textMapDeadline = Date().addingTimeInterval(budget.totalScanSeconds)
        var textMap: [DisplayListTextMap.Entry] = []
        for host in DisplayListTextMap.hostingViews(
            in: window,
            maxNodes: SwiftUIScanBudget.hostingDiscoveryMaxNodes,
            maxDepth: SwiftUIScanBudget.hostingDiscoveryMaxDepth,
            scanDeadline: textMapDeadline
        ) {
            if Date() > textMapDeadline { break }
            let hostDeadline = min(Date().addingTimeInterval(budget.displayListHostSeconds), textMapDeadline)
            textMap.append(contentsOf: DisplayListTextMap.textMap(
                for: host,
                deadline: hostDeadline,
                maxVisited: budget.displayListMaxVisited
            ))
        }

        // Phase A (secondary) — SwiftUI reflection inventory: marks WHICH titles
        // are interactive so Stage B can prefer confirmed controls when
        // reflection is available. Since the approximate Stage C fallback is gone,
        // reflection is skipped when there is no display-list text to pair with.
        let reflectionPolicy = Self.reflectionPolicy()
        let reflectionDeadline = Date().addingTimeInterval(budget.reflectionHostSeconds)
        let (records, invHost) = textMap.isEmpty
            ? ([], nil)
            : buildInventory(in: window, budget: budget,
                             scanDeadline: reflectionDeadline,
                             bodyEvaluationPolicy: reflectionPolicy)
        let interactive = Self.interactiveRecords(in: records)

        snapshotLock.lock()
        latestInventory = records
        latestTextMap = textMap
        latestInteractiveRecords = interactive
        inventoryHost = invHost
        cacheGen = currentScreenGen
        let stampedGen = cacheGen
        snapshotLock.unlock()

        #if DEBUG
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - scanStart) * 1000
        SwiftUIScanLog.log(String(format: "performScan(%@) DONE inv=%d textMap=%d interactive=%d "
            + "elapsed=%.1fms stampedGen=%d host=%@",
            "\(reason)", records.count, textMap.count, interactive.count, elapsedMs,
            stampedGen, invHost.map { String(describing: type(of: $0)) } ?? "nil"))
        let interactiveTitles = interactive.map { $0.title }
        let textMapTitles = textMap.compactMap { $0.title }
        logTitleChunks("interactive titles", interactiveTitles)
        logTitleChunks("textMap titles", textMapTitles)
        #endif
    }

    #if DEBUG
    private func logTitleChunks(_ label: String, _ titles: [String], chunkSize: Int = 8) {
        guard !titles.isEmpty else {
            SwiftUIScanLog.log("  → \(label)(0): []")
            return
        }
        for start in stride(from: 0, to: titles.count, by: chunkSize) {
            let end = min(start + chunkSize, titles.count)
            let chunk = Array(titles[start..<end])
            SwiftUIScanLog.log("  → \(label)(\(titles.count))[\(start)..<\(end)]: \(chunk)")
        }
    }
    #endif

    /// Runs the coalesced background scan with the recorded reason, then resets
    /// the pending reason to the neutral default.
    private func performPendingBackgroundScan() {
        snapshotLock.lock()
        let reason = pendingBackgroundReason
        pendingBackgroundReason = .debounced
        snapshotLock.unlock()
        performScan(reason: reason)
    }

    /// One-shot deferral of a scan request that arrived before the app finished
    /// launching (or while backgrounded).
    private func scheduleScanWhenActive() {
        guard becomeActiveObserver == nil else { return }
        becomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if let token = self.becomeActiveObserver {
                NotificationCenter.default.removeObserver(token)
                self.becomeActiveObserver = nil
            }
            self.debouncer.schedule()
        }
    }

    /// Build the SwiftUI inventory by reflecting every hosting controller
    /// (shallow → deep) and merging every non-empty inventory. SwiftUI
    /// NavigationStack / TabView can split visible content across multiple
    /// hosting controllers, so keeping only the deepest non-empty host drops
    /// buttons that are still visible in a sibling/parent host.
    private func buildInventory(in window: UIWindow,
                                budget: SwiftUIScanBudget.Budget,
                                scanDeadline: Date,
                                bodyEvaluationPolicy: SwiftUIReflection.BodyEvaluationPolicy)
        -> ([SwiftUIReflection.ViewRecord], UIViewController?) {
        let controllers = SwiftUIReflection.allHostingControllers(in: window)
        let snapshots = controllers.map {
            host -> (records: [SwiftUIReflection.ViewRecord], host: UIViewController) in
            // Per-host reflection deadline, clamped to the whole-scan deadline so
            // a late host can never push past the total budget. Once the scan
            // deadline passes, `hostDeadline` is in the past and reflection
            // returns near-immediately (its Budget is exhausted on first check).
            let hostDeadline = min(Date().addingTimeInterval(budget.reflectionHostSeconds), scanDeadline)
            return (records: SwiftUIReflection.extractInventory(
                        from: host,
                        deadline: hostDeadline,
                        bodyEvaluationPolicy: bodyEvaluationPolicy),
                    host: host)
        }
        let merged = Self.mergeInventories(snapshots)
        return (merged.records, merged.host ?? controllers.last)
    }

    internal static func mergeInventories(
        _ snapshots: [(records: [SwiftUIReflection.ViewRecord], host: UIViewController)]
    ) -> (records: [SwiftUIReflection.ViewRecord], host: UIViewController?) {
        var merged: [SwiftUIReflection.ViewRecord] = []
        var selectedHost: UIViewController?
        for snapshot in snapshots where !snapshot.records.isEmpty {
            merged.append(contentsOf: snapshot.records)
            selectedHost = snapshot.host
        }
        return (merged, selectedHost)
    }

    internal static func reflectionPolicy() -> SwiftUIReflection.BodyEvaluationPolicy {
        .avoidWarningProneState
    }

    internal static func reflectionPolicy(
        forTextMap textMap: [DisplayListTextMap.Entry]
    ) -> SwiftUIReflection.BodyEvaluationPolicy {
        reflectionPolicy()
    }

    /// One-shot title scan for a specific host. Used by `userpilotScanOnce()`
    /// so a screen that opted out of the accessibility read still gets titles
    /// from its current rendered/materialized SwiftUI display list.
    func scanOnceCurrentScreen(for host: UIViewController) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.scanOnceCurrentScreen(for: host) }
            return
        }

        guard Userpilot.isInitialized, let userpilot = Userpilot.shared else { return }
        let config = userpilot.config
        guard SwiftUITitleCapturePolicy.shouldRun(
            config: config,
            isSwiftUIHost: SwiftUIDetection.isHostingController(host)
        ) else { return }

        let budget = SwiftUIScanBudget.background
        let textMapDeadline = Date().addingTimeInterval(budget.totalScanSeconds)
        var textMap: [DisplayListTextMap.Entry] = []
        for hostingView in DisplayListTextMap.hostingViews(
            under: host.view,
            maxNodes: SwiftUIScanBudget.hostingDiscoveryMaxNodes,
            maxDepth: SwiftUIScanBudget.hostingDiscoveryMaxDepth,
            scanDeadline: textMapDeadline
        ) {
            if Date() > textMapDeadline { break }
            let hostDeadline = min(Date().addingTimeInterval(budget.displayListHostSeconds), textMapDeadline)
            textMap.append(contentsOf: DisplayListTextMap.textMap(
                for: hostingView,
                deadline: hostDeadline,
                maxVisited: budget.displayListMaxVisited
            ))
        }

        let reflectionPolicy = Self.reflectionPolicy()
        let inv = SwiftUIReflection.extractInventory(
            from: host,
            deadline: Date().addingTimeInterval(budget.reflectionHostSeconds),
            bodyEvaluationPolicy: reflectionPolicy
        )
        let interactive = Self.interactiveRecords(in: inv)

        snapshotLock.lock()
        latestInventory = inv
        latestInteractiveRecords = interactive
        latestTextMap = textMap
        inventoryHost = host
        cacheGen = currentScreenGen
        snapshotLock.unlock()

        #if DEBUG
        SwiftUIScanLog.log("scanOnceCurrentScreen DONE inv=\(inv.count) textMap=\(textMap.count) "
            + "interactive=\(interactive.count) host=\(type(of: host))")
        logTitleChunks("scanOnce textMap titles", textMap.compactMap { $0.title })
        #endif
    }

    // MARK: - Click-time lookup

    /// The cached SwiftUI reflection inventory + the host it came from. Read by
    /// the touch path; never triggers a fresh `body` evaluation.
    func inventory() -> ([SwiftUIReflection.ViewRecord], UIViewController?) {
        snapshotLock.lock()
        let stale = (cacheGen != currentScreenGen)
        let records = stale ? [] : latestInventory
        let host = stale ? nil : inventoryHost
        #if DEBUG
        let cg = cacheGen, cur = currentScreenGen
        #endif
        snapshotLock.unlock()
        #if DEBUG
        SwiftUIScanLog.log("inventory() → \(stale ? "STALE [] " : "\(records.count) records ")(cacheGen=\(cg) currentGen=\(cur))")
        #endif
        return (records, host)
    }

    /// The cached display-list text map plus the interactive titles derived
    /// from the reflection inventory. Read by the touch path.
    func textResolution() -> (textMap: [DisplayListTextMap.Entry],
                              interactive: [(title: String, viewType: String)]) {
        snapshotLock.lock()
        let stale = (cacheGen != currentScreenGen)
        let map = stale ? [] : latestTextMap
        let interactive = stale ? [] : latestInteractiveRecords
        #if DEBUG
        let cg = cacheGen, cur = currentScreenGen
        #endif
        snapshotLock.unlock()
        #if DEBUG
        SwiftUIScanLog.log("textResolution() → \(stale ? "STALE [] " : "textMap=\(map.count) interactive=\(interactive.count) ")(cacheGen=\(cg) currentGen=\(cur))")
        #endif
        return (textMap: map, interactive: interactive)
    }

    // MARK: - Cache hygiene

    private func registerMemoryWarningEviction() {
        guard memoryWarningObserver == nil else { return }
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCaches()
        }
    }

    func clearCaches() {
        snapshotLock.lock()
        latestInventory = []
        latestTextMap = []
        latestInteractiveRecords = []
        inventoryHost = nil
        cacheGen = -1
        snapshotLock.unlock()
    }

    // MARK: - Helpers

    /// Titles the inventory marks as belonging to tappable controls. Capture is
    /// button-first: a rendered text whose title is NOT in this list never
    /// becomes a resolver-supplied title.
    private static func interactiveRecords(
        in records: [SwiftUIReflection.ViewRecord]
    ) -> [(title: String, viewType: String)] {
        var seen = Set<String>()
        var out: [(String, String)] = []
        for record in records where record.isInteractive {
            if seen.insert(record.title).inserted {
                out.append((record.title, record.viewType))
            }
        }
        return out
    }

    #if DEBUG
    /// Test seam — seeds the click-time snapshot directly so the resolver's
    /// stage-selection can be exercised without a live SwiftUI render. NOT used
    /// in production (release builds exclude it).
    func _testSeedSnapshot(textMap: [DisplayListTextMap.Entry],
                           inventory: [SwiftUIReflection.ViewRecord],
                           inventoryHost host: UIViewController? = nil,
                           fresh: Bool = true) {
        let interactive = Self.interactiveRecords(in: inventory)
        snapshotLock.lock()
        latestTextMap = textMap
        latestInventory = inventory
        latestInteractiveRecords = interactive
        inventoryHost = host
        // `fresh` (default) stamps the current generation so stale-aware readers
        // accept the seed; `fresh: false` stamps a prior generation to simulate
        // a stale snapshot that readers must reject.
        cacheGen = fresh ? currentScreenGen : currentScreenGen &- 1
        snapshotLock.unlock()
    }
    #endif

    static func keyVisibleWindow() -> UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene,
                  ws.activationState == .foregroundActive else { continue }
            if let key = ws.windows.first(where: { $0.isKeyWindow && !$0.isHidden }) {
                return key
            }
            if let any = ws.windows.first(where: { !$0.isHidden }) {
                return any
            }
        }
        return nil
    }
}
