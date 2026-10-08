//
//  SwiftUIScanCache.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Owns the cached result of the latest SwiftUI scan and the orchestration that
//  produces it:
//    - the SwiftUI reflection inventory (element titles + which are interactive)
//    - the display-list text map (exact frames + the painting CALayer)
//    - the click-time accessors the resolver reads (never re-evaluates `body`)
//
//  Background scans are event-driven (screen appear + touch settle), idle-gated,
//  and debounced — there is no periodic timer. Rescans are scheduled by the SDK's
//  existing swizzler; this type does not swizzle anything.
//
//  Per scan, two phases run:
//    Phase B (primary) — `DisplayListTextMap.scanHost` reads exact text
//              geometry from the render tree of every hosting view.
//    Phase A (secondary) — `SwiftUIReflection.extractInventory` marks which
//              titles are interactive. Normal title lookup uses the snapshot;
//              a first tap that beats the scheduled scan may run both phases.
//
//  Every full scan feeds `SwiftUICaptureHealth`; when the render structure is
//  not recognized (new iOS release) the breaker turns capture off for the
//  session after a few scans.
//

// swiftlint:disable file_length function_body_length identifier_name line_length type_body_length
// swiftlint:disable:previous blanket_disable_command

import UIKit

internal final class SwiftUIScanCache {

    // Native hooks share one process-wide view snapshot. It contains no tenant settings:
    // admission and publishing stay with the owning instance, while the health breaker is
    // shared because every instance reads the same OS render structures.
    static let shared = SwiftUIScanCache()

    enum RescanReason { case screenAppeared, touchEnded, manual, debounced }

    // MARK: - State

    // Lifecycle entry points marshal to main before first access to this lazy dependency.
    private lazy var debouncer = ScanDebouncer(delay: Self.backgroundScanDebounceDelay) { [weak self] in
        self?.performPendingBackgroundScan()
    }
    private var latestInventory: [SwiftUIReflection.ViewRecord] = []
    private var latestTextMap: [DisplayListTextMap.Entry] = []
    private var latestInteractiveRecords: [(title: String, viewType: String)] = []
    private weak var inventoryHost: UIViewController?
    private let snapshotLock = NSLock()

    // Screen-identity generation counter. `markScreenChanged()` bumps
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
    // main; the snapshot lock protects only the cached read state.
    private var pendingBackgroundReason: RescanReason = .debounced
    private var becomeActiveObserver: NSObjectProtocol?
    private var memoryWarningObserver: NSObjectProtocol?
    private static let backgroundScanDebounceDelay: TimeInterval = 0.5

    // A background scan cut short by its budget re-arms itself so a cold first
    // scan (one-time Swift runtime warm-up) finishes in a few short passes
    // before the user taps, instead of one long main-thread stall. Capped per
    // screen so a screen too large for the budget cannot loop. Main thread only.
    private var truncatedFollowUps = 0
    private static let maxTruncatedFollowUps = 3

    private init() {}

    // MARK: - Lifecycle

    func start() {
        performOnMain { [weak self] in self?.registerMemoryWarningEviction() }
    }

    func stop() {
        performOnMain { [weak self] in self?.stopOnMain() }
    }

    private func stopOnMain() {
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
    /// synchronous tap path in `prepareForTapResolution(at:in:tappedView:)`; if a
    /// caller passes it here it is stored as `.debounced` so a queued scan can
    /// never claim the tight tap-path budget.
    ///
    /// Threading: marshals to main so `pendingBackgroundReason` is only touched
    /// on the main thread.
    func scheduleRescan(reason: RescanReason = .debounced, logger: Logging? = nil) {
        performOnMain { [weak self] in
            self?.scheduleRescanOnMain(reason: reason, logger: logger)
        }
    }

    private func scheduleRescanOnMain(reason: RescanReason, logger: Logging?) {
        guard !SwiftUICaptureHealth.isTripped else { return }

        #if DEBUG
        assert(reason != .manual,
               "scheduleRescan(reason:) is background-only; the tap path scans synchronously.")
        #endif

        let backgroundReason: RescanReason = (reason == .manual) ? .debounced : reason

        // A pending screen-appeared scan must keep its reason (it refreshes the
        // reflection inventory); a later touch-end only re-arms the debounce.
        if !(pendingBackgroundReason == .screenAppeared && backgroundReason == .touchEnded) {
            pendingBackgroundReason = backgroundReason
        }
        debouncer.schedule()
        #if DEBUG
        logger?.debugSwiftUICapture("scheduleRescan(reason=\(reason)) → pendingBg=\(backgroundReason), "
            + "debounce armed (\(Self.backgroundScanDebounceDelay)s)")
        #endif
    }

    /// Marks that the visible screen changed (called from the `viewDidAppear`
    /// hook). Invalidates the cached snapshot for stale-aware readers until the
    /// next scan stamps the new generation. Marshals to main so the counter is
    /// only mutated on the main thread.
    func markScreenChanged(logger: Logging? = nil) {
        performOnMain { [weak self] in
            self?.markScreenChangedOnMain(logger: logger)
        }
    }

    private func markScreenChangedOnMain(logger: Logging?) {
        let (gen, stampedGen) = snapshotLock.withLock {
            currentScreenGen &+= 1
            return (currentScreenGen, cacheGen)
        }
        truncatedFollowUps = 0
        #if DEBUG
        logger?.debugSwiftUICapture("markScreenChanged → currentGen=\(gen) (cacheGen=\(stampedGen) now STALE)")
        #endif
    }

    /// Makes sure the cached text map can answer a tap at `pointInWindow`.
    /// Called from the click-enrichment path only — after the SDK has decided
    /// the tap needs a SwiftUI title — so other taps never pay for a scan.
    ///
    ///   - Screen generation changed (the debounced screen-appear scan has not
    ///     run yet): synchronous full scan of the TAPPED window, tap budget.
    ///   - Otherwise, if no cached entry resolves at the point (a scroll revealed
    ///     rows, or a NavigationStack push swapped content inside the same
    ///     hosting controller): refresh only the hosting view under the tap,
    ///     text map only.
    ///   - Otherwise: use the cache as-is.
    ///
    /// A tap that legitimately has no title (icon, empty space) costs one
    /// single-host refresh, never a full scan.
    func prepareForTapResolution(
        at pointInWindow: CGPoint, in window: UIWindow, tappedView: UIView, logger: Logging? = nil
    ) {
        guard Thread.isMainThread else { return }

        let (isStale, textMap, interactive) = snapshotLock.withLock {
            (cacheGen != currentScreenGen, latestTextMap, latestInteractiveRecords)
        }

        if isStale {
            #if DEBUG
            logger?.debugSwiftUICapture("prepareForTap: stale snapshot → synchronous performScan(.manual)")
            #endif
            debouncer.cancel()
            performScan(reason: .manual, in: window, logger: logger)
            return
        }

        let coversTap = textMap.contains {
            Self.canResolveTitle(from: $0, interactive: interactive, at: pointInWindow, in: window)
        }
        guard !coversTap else { return }

        #if DEBUG
        logger?.debugSwiftUICapture("prepareForTap: cache misses tap point → refresh tapped host only")
        #endif
        refreshHost(containing: tappedView, logger: logger)
    }

    private static func canResolveTitle(from entry: DisplayListTextMap.Entry,
                                        interactive: [(title: String, viewType: String)],
                                        at pointInWindow: CGPoint,
                                        in window: UIWindow) -> Bool {
        guard let title = entry.title,
              entry.containsWindowPoint(pointInWindow, in: window) else { return false }
        return interactive.contains(where: { $0.title == title }) || entry.isStyledControlTitleCandidate
    }

    /// Re-reads the display list of the innermost hosting view containing
    /// `view` and replaces that host's cached entries.
    private func refreshHost(containing view: UIView, logger: Logging?) {
        var current: UIView? = view
        while let candidate = current, !SwiftUIDetection.isHostingView(candidate) {
            current = candidate.superview
        }
        guard let host = current else { return }

        let budget = SwiftUIScanBudget.tapPath
        let scan = DisplayListTextMap.scanHost(
            host,
            deadline: Date().addingTimeInterval(budget.displayListHostSeconds),
            maxVisited: budget.displayListMaxVisited, logger: logger
        )

        snapshotLock.withLock {
            latestTextMap.removeAll { $0.host == nil || $0.host === host }
            latestTextMap.append(contentsOf: scan.entries)
        }
        #if DEBUG
        logger?.debugSwiftUICapture("refreshHost \(type(of: host)) → \(scan.entries.count) entries")
        #endif
    }

    // MARK: - Scan

    /// Full scan of `window` (the key visible window when nil).
    private func performScan(reason: RescanReason, in window: UIWindow? = nil, logger: Logging? = nil) {
        // All callers are main-owned: the debouncer, native tap path and lifecycle wrappers.
        assert(Thread.isMainThread)
        guard !SwiftUICaptureHealth.isTripped else { return }
        // During launch the app is still `.inactive`; park the scan until
        // active so no scan work lands inside the launch transition. Re-stamp
        // the (sanitized) reason so the deferred re-run, re-armed via the
        // debouncer in `scheduleScanWhenActive()`, is still attributed
        // correctly — `performPendingBackgroundScan()` already consumed it.
        guard UIApplication.shared.applicationState == .active else {
            pendingBackgroundReason = (reason == .manual) ? .debounced : reason
            #if DEBUG
            logger?.debugSwiftUICapture("performScan(\(reason)) DEFERRED — app not active")
            #endif
            scheduleScanWhenActive()
            return
        }
        guard let window = window ?? Self.keyVisibleWindow() else {
            #if DEBUG
            logger?.debugSwiftUICapture("performScan(\(reason)) ABORTED — no key visible window")
            #endif
            return
        }

        // Budget by reason: only the synchronous tap-path (`.manual`) scan uses
        // the tight tap-path budget; every background reason uses the larger one.
        //
        // The two phases get INDEPENDENT, freshly-computed deadlines so
        // reflection (Phase A) can never starve the display-list phase, which is
        // the primary title source and runs first.
        let logger = logger ?? InstanceResolver.shared.target(forSource: window)?.config.logger
        let budget = (reason == .manual) ? SwiftUIScanBudget.tapPath : SwiftUIScanBudget.background
        #if DEBUG
        let budgetName = (reason == .manual) ? "tapPath" : "background"
        let currentGen = snapshotLock.withLock { currentScreenGen }
        logger?.debugSwiftUICapture("performScan(\(reason)) START budget=\(budgetName) currentGen=\(currentGen)")
        let scanStart = CFAbsoluteTimeGetCurrent()
        #endif

        // Phase B (primary) — display-list text map.
        let phaseB = SwiftUIScanner.scanTextMap(in: window, budget: budget, logger: logger)
        #if DEBUG
        let textMapMs = (CFAbsoluteTimeGetCurrent() - scanStart) * 1000
        #endif

        if SwiftUICaptureHealth.recordScan(hosts: phaseB.hostCount, locatedLists: phaseB.locatedLists,
                                           textItems: phaseB.textItems, pairedEntries: phaseB.entries.count) {
            handleBreakerTripped(logger: logger)
            return
        }

        // Phase A (secondary) — reflection inventory.
        let inventory = inventoryForScan(reason: reason, hasText: !phaseB.entries.isEmpty,
                                         window: window, budget: budget, logger: logger)

        let stampedGen = snapshotLock.withLock {
            latestInventory = inventory.records
            latestTextMap = phaseB.entries
            latestInteractiveRecords = inventory.interactive
            inventoryHost = inventory.host
            cacheGen = currentScreenGen
            return cacheGen
        }

        if phaseB.truncated, reason != .manual, truncatedFollowUps < Self.maxTruncatedFollowUps {
            truncatedFollowUps += 1
            scheduleRescan(reason: .debounced)
        } else if !phaseB.truncated {
            truncatedFollowUps = 0
        }

        #if DEBUG
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - scanStart) * 1000
        logger?.debugSwiftUICapture(String(format: "performScan(%@) DONE hosts=%d lists=%d textItems=%d inv=%d textMap=%d interactive=%d "
            + "elapsed=%.1fms (textMap %.1fms) stampedGen=%d host=%@",
            "\(reason)", phaseB.hostCount, phaseB.locatedLists, phaseB.textItems, inventory.records.count,
            phaseB.entries.count, inventory.interactive.count, elapsedMs, textMapMs, stampedGen,
            inventory.host.map { String(describing: type(of: $0)) } ?? "nil"))
        logTitleChunks("interactive titles", inventory.interactive.map { $0.title }, logger: logger)
        logTitleChunks("textMap titles", phaseB.entries.compactMap { $0.title }, logger: logger)
        #endif
    }

    /// Phase A: the reflection inventory marking WHICH titles are interactive.
    /// Skipped when there is no display-list text to pair with, and on
    /// touch-end rescans of a screen that already has an inventory (scrolling
    /// changes rendered text, not the view tree).
    private func inventoryForScan(reason: RescanReason,
                                  hasText: Bool,
                                  window: UIWindow,
                                  budget: SwiftUIScanBudget.Budget, logger: Logging?) -> ScanInventory {
        guard hasText else { return ScanInventory() }

        let (screenAlreadyScanned, previous) = snapshotLock.withLock {
            (cacheGen == currentScreenGen,
             ScanInventory(records: latestInventory, interactive: latestInteractiveRecords, host: inventoryHost))
        }

        if reason == .touchEnded, screenAlreadyScanned {
            return previous
        }
        let reflectionDeadline = Date().addingTimeInterval(budget.reflectionHostSeconds)
        let built = SwiftUIScanner.buildInventory(in: window, budget: budget, scanDeadline: reflectionDeadline, logger: logger)
        return ScanInventory(records: built.0, interactive: SwiftUIScanner.interactiveRecords(in: built.0), host: built.1)
    }

    private struct ScanInventory {
        var records: [SwiftUIReflection.ViewRecord] = []
        var interactive: [(title: String, viewType: String)] = []
        weak var host: UIViewController?
    }

    /// The render structure was not recognized on this OS for several scans in
    /// a row: drop all cached state and stop scheduling work for the session.
    private func handleBreakerTripped(logger: Logging?) {
        debouncer.cancel()
        clearCaches()
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        logger?.info(
            "📊 SwiftUI title capture paused for this session: render structure not recognized (%{public}@)",
            os
        )
        #if DEBUG
        logger?.debugSwiftUICapture("circuit breaker TRIPPED — SwiftUI title capture off for this session (\(os))")
        #endif
    }

    #if DEBUG
    private func logTitleChunks(_ label: String, _ titles: [String], logger: Logging?, chunkSize: Int = 8) {
        guard !titles.isEmpty else {
            logger?.debugSwiftUICapture("  → \(label)(0): []")
            return
        }
        for start in stride(from: 0, to: titles.count, by: chunkSize) {
            let end = min(start + chunkSize, titles.count)
            let chunk = Array(titles[start..<end])
            logger?.debugSwiftUICapture("  → \(label)(\(titles.count))[\(start)..<\(end)]: \(chunk)")
        }
    }
    #endif

    /// Runs the coalesced background scan with the recorded reason, then resets
    /// the pending reason to the neutral default.
    private func performPendingBackgroundScan() {
        let reason = pendingBackgroundReason
        pendingBackgroundReason = .debounced
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

    /// One-shot title scan for a specific host. Used by `userpilotScanOnce()`
    /// so a screen that opted out of the accessibility read still gets titles
    /// from its current rendered/materialized SwiftUI display list.
    func scanOnceCurrentScreen(for host: UIViewController) {
        performOnMain { [weak self] in
            self?.scanOnceCurrentScreenOnMain(for: host)
        }
    }

    private func scanOnceCurrentScreenOnMain(for host: UIViewController) {

        guard let userpilot = InstanceResolver.shared.target(forViewController: host) else { return }
        let config = userpilot.config
        let logger: Logging? = config.logger
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
            textMap.append(contentsOf: DisplayListTextMap.scanHost(
                hostingView,
                deadline: hostDeadline,
                maxVisited: budget.displayListMaxVisited, logger: logger
            ).entries)
        }

        let inv = SwiftUIReflection.extractInventory(
            from: host,
            deadline: Date().addingTimeInterval(budget.reflectionHostSeconds), logger: logger
        )
        let interactive = SwiftUIScanner.interactiveRecords(in: inv)

        snapshotLock.withLock {
            latestInventory = inv
            latestInteractiveRecords = interactive
            latestTextMap = textMap
            inventoryHost = host
            cacheGen = currentScreenGen
        }

        #if DEBUG
        logger?.debugSwiftUICapture("scanOnceCurrentScreen DONE inv=\(inv.count) textMap=\(textMap.count) "
            + "interactive=\(interactive.count) host=\(type(of: host))")
        logTitleChunks("scanOnce textMap titles", textMap.compactMap { $0.title }, logger: logger)
        #endif
    }

    // MARK: - Click-time lookup

    /// The cached SwiftUI reflection inventory + the host it came from. Read by
    /// the touch path; never triggers a fresh `body` evaluation.
    func inventory(logger: Logging? = nil) -> ([SwiftUIReflection.ViewRecord], UIViewController?) {
        let (stale, records, host, cg, cur) = snapshotLock.withLock {
            let stale = cacheGen != currentScreenGen
            return (stale, stale ? [] : latestInventory, stale ? nil : inventoryHost, cacheGen, currentScreenGen)
        }
        #if DEBUG
        logger?.debugSwiftUICapture("inventory() → \(stale ? "STALE [] " : "\(records.count) records ")(cacheGen=\(cg) currentGen=\(cur))")
        #endif
        return (records, host)
    }

    /// The cached display-list text map plus the interactive titles derived
    /// from the reflection inventory. Read by the touch path.
    func textResolution(logger: Logging? = nil) -> (textMap: [DisplayListTextMap.Entry],
                              interactive: [(title: String, viewType: String)]) {
        let (stale, map, interactive, cg, cur) = snapshotLock.withLock {
            let stale = cacheGen != currentScreenGen
            return (stale, stale ? [] : latestTextMap, stale ? [] : latestInteractiveRecords, cacheGen, currentScreenGen)
        }
        #if DEBUG
        logger?.debugSwiftUICapture("textResolution() → \(stale ? "STALE [] " : "textMap=\(map.count) interactive=\(interactive.count) ")(cacheGen=\(cg) currentGen=\(cur))")
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
        snapshotLock.withLock {
            latestInventory = []
            latestTextMap = []
            latestInteractiveRecords = []
            inventoryHost = nil
            cacheGen = -1
        }
    }

    // MARK: - Helpers

    #if DEBUG
    /// Test seam — seeds the click-time snapshot directly so the resolver's
    /// stage-selection can be exercised without a live SwiftUI render. NOT used
    /// in production (release builds exclude it).
    func _testSeedSnapshot(textMap: [DisplayListTextMap.Entry],
                           inventory: [SwiftUIReflection.ViewRecord],
                           inventoryHost host: UIViewController? = nil,
                           fresh: Bool = true) {
        let interactive = SwiftUIScanner.interactiveRecords(in: inventory)
        snapshotLock.withLock {
            latestTextMap = textMap
            latestInventory = inventory
            latestInteractiveRecords = interactive
            inventoryHost = host
            // `fresh` (default) stamps the current generation so stale-aware readers
            // accept the seed; `fresh: false` stamps a prior generation to simulate
            // a stale snapshot that readers must reject.
            cacheGen = fresh ? currentScreenGen : currentScreenGen &- 1
        }
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
