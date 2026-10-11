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

// swiftlint:disable file_length identifier_name line_length type_body_length
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
    // Keep the original destination weakly. A delayed scan must never follow a new key
    // window or keep a disappeared window/SDK instance alive.
    private weak var pendingWindow: UIWindow?
    private weak var pendingOwner: Userpilot?
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
        clearPendingScan()
        clearCaches()
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
    /// synchronous tap path in `prepareForTapResolution(at:in:tappedView:owner:)`; if a
    /// caller passes it here it is stored as `.debounced` so a queued scan can
    /// never claim the tight tap-path budget.
    ///
    /// Hooks check their source before submitting its window and resolved owner. Startup may
    /// submit a window while framework detection is pending; the scanner discovers its hosts.
    /// Threading: pending state and native reads are main-owned.
    func scheduleRescan(reason: RescanReason = .debounced, window: UIWindow, owner: Userpilot) {
        performOnMain { [weak self, weak window, weak owner] in
            guard let self, let window, let owner,
                  SwiftUITitleCapturePolicy.shouldRun(for: owner) else { return }
            self.recordPendingScan(reason: reason, window: window, owner: owner)
            self.debouncer.schedule()
            owner.config.logger.debugSwiftUICapture("scheduleRescan(reason=\(reason)) → pendingBg=\(self.pendingBackgroundReason), "
                + "debounce armed (\(Self.backgroundScanDebounceDelay)s)")
        }
    }

    /// Preserve screen-appearance priority within one destination. A new owner/window
    /// replaces the pending request in this shared debouncer.
    private func recordPendingScan(reason: RescanReason, window: UIWindow, owner: Userpilot) {
        let backgroundReason: RescanReason = (reason == .manual) ? .debounced : reason
        let preservesAppearance = pendingOwner === owner && pendingWindow === window
            && pendingBackgroundReason == .screenAppeared && backgroundReason == .touchEnded
        if !preservesAppearance { pendingBackgroundReason = backgroundReason }
        pendingWindow = window
        pendingOwner = owner
    }

    private func clearPendingScan() {
        debouncer.cancel()
        pendingWindow = nil
        pendingOwner = nil
        pendingBackgroundReason = .debounced
        if let token = becomeActiveObserver {
            NotificationCenter.default.removeObserver(token)
            becomeActiveObserver = nil
        }
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
        logger?.debugSwiftUICapture("markScreenChanged → currentGen=\(gen) (cacheGen=\(stampedGen) now STALE)")
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
        at pointInWindow: CGPoint, in window: UIWindow, tappedView: UIView, owner: Userpilot
    ) {
        guard Thread.isMainThread, SwiftUITitleCapturePolicy.shouldRun(for: owner) else { return }
        let logger: Logging? = owner.config.logger

        let (isStale, textMap, interactive) = snapshotLock.withLock {
            (cacheGen != currentScreenGen, latestTextMap, latestInteractiveRecords)
        }

        if isStale {
            logger?.debugSwiftUICapture("prepareForTap: stale snapshot → synchronous performScan(.manual)")
            clearPendingScan()
            performScan(reason: .manual, window: window, owner: owner)
            return
        }

        let coversTap = textMap.contains {
            Self.canResolveTitle(from: $0, interactive: interactive, at: pointInWindow, in: window)
        }
        guard !coversTap else { return }

        logger?.debugSwiftUICapture("prepareForTap: cache misses tap point → refresh tapped host only")
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
        logger?.debugSwiftUICapture("refreshHost \(type(of: host)) → \(scan.entries.count) entries")
    }

    // MARK: - Scan

    /// The requesting owner controls execution, even when the window's root belongs to another
    /// instance. Recheck current settings and stop state; stop then resume before execution is allowed.
    private func performScan(reason: RescanReason, window: UIWindow, owner: Userpilot) {
        assert(Thread.isMainThread)
        guard !window.isHidden, SwiftUITitleCapturePolicy.shouldRun(for: owner) else { return }
        let logger: Logging? = owner.config.logger
        // During launch/backgrounding retain this destination until active. Do not look up
        // the then-current key window, which may belong to another scene or SDK instance.
        guard UIApplication.shared.applicationState == .active else {
            recordPendingScan(reason: reason, window: window, owner: owner)
            logger?.debugSwiftUICapture("performScan(\(reason)) DEFERRED — app not active")
            scheduleScanWhenActive()
            return
        }

        // Budget by reason: only the synchronous tap-path (`.manual`) scan uses
        // the tight tap-path budget; every background reason uses the larger one.
        //
        // The two phases get INDEPENDENT, freshly-computed deadlines so
        // reflection (Phase A) can never starve the display-list phase, which is
        // the primary title source and runs first.
        let budget = (reason == .manual) ? SwiftUIScanBudget.tapPath : SwiftUIScanBudget.background
        // Measurements are diagnostic-only; Release performs only the budgeted native reads.
        #if DEBUG
        let currentGen = snapshotLock.withLock { currentScreenGen }
        logger?.debugSwiftUICapture("performScan(\(reason)) START budget=\(reason == .manual ? "tapPath" : "background") currentGen=\(currentGen)")
        let scanStart = CFAbsoluteTimeGetCurrent()
        #endif

        // Phase B (primary) — display-list text map.
        let phaseB = SwiftUIScanner.scanTextMap(under: window, budget: budget, logger: logger)
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

        snapshotLock.withLock {
            latestInventory = inventory.records
            latestTextMap = phaseB.entries
            latestInteractiveRecords = inventory.interactive
            inventoryHost = inventory.host
            cacheGen = currentScreenGen
        }

        if phaseB.truncated, reason != .manual, truncatedFollowUps < Self.maxTruncatedFollowUps {
            truncatedFollowUps += 1
            scheduleRescan(reason: .debounced, window: window, owner: owner)
        } else if !phaseB.truncated {
            truncatedFollowUps = 0
        }

        #if DEBUG
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - scanStart) * 1000
        let stampedGen = snapshotLock.withLock { cacheGen }
        logger?.debugSwiftUICapture(String(format: "performScan(%@) DONE hosts=%d lists=%d textItems=%d inv=%d textMap=%d interactive=%d "
            + "elapsed=%.1fms (textMap %.1fms) stampedGen=%d host=%@",
            "\(reason)", phaseB.hostCount, phaseB.locatedLists, phaseB.textItems, inventory.records.count,
            phaseB.entries.count, inventory.interactive.count, elapsedMs, textMapMs, stampedGen,
            inventory.host.map { String(describing: type(of: $0)) } ?? "nil"))
        #endif
        logger?.debugSwiftUITitles("interactive titles", inventory.interactive.map { $0.title })
        logger?.debugSwiftUITitles("textMap titles", phaseB.entries.compactMap { $0.title })
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
        clearPendingScan()
        clearCaches()
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        logger?.info(
            "📊 SwiftUI title capture paused for this session: render structure not recognized (%{public}@)",
            os
        )
        logger?.debugSwiftUICapture("circuit breaker TRIPPED — SwiftUI title capture off for this session (\(os))")
    }

    /// Consume the pending destination once. Native work rechecks policy after the debounce,
    /// including requests that waited for the app to become active.
    private func performPendingBackgroundScan() {
        let window = pendingWindow
        let owner = pendingOwner
        let reason = pendingBackgroundReason
        clearPendingScan()
        guard let window, let owner else { return }
        performScan(reason: reason, window: window, owner: owner)
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
        performOnMain { [weak self, weak host] in
            guard let host else { return }
            self?.scanOnceCurrentScreenOnMain(for: host)
        }
    }

    private func scanOnceCurrentScreenOnMain(for host: UIViewController) {

        guard let source = host.viewIfLoaded, let window = source.window, !window.isHidden,
              let owner = InstanceResolver.shared.target(forViewController: host),
              SwiftUITitleCapturePolicy.shouldRun(for: owner, isSwiftUIHost: source.up_isInsideHostingView) else { return }
        let logger: Logging? = owner.config.logger
        let budget = SwiftUIScanBudget.background
        // Same display-list traversal/budgets as full scans, scoped to this host rather than
        // the whole window. Reflection still targets only this controller after geometry is read.
        let textMap = SwiftUIScanner.scanTextMap(under: source, budget: budget, logger: logger).entries

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

        logger?.debugSwiftUICapture("scanOnceCurrentScreen DONE inv=\(inv.count) textMap=\(textMap.count) "
            + "interactive=\(interactive.count) host=\(type(of: host))")
        logger?.debugSwiftUITitles("scanOnce textMap titles", textMap.compactMap { $0.title })
    }

    // MARK: - Click-time lookup

    /// The cached SwiftUI reflection inventory + the host it came from. Read by
    /// the touch path; never triggers a fresh `body` evaluation.
    func inventory(logger: Logging? = nil) -> ([SwiftUIReflection.ViewRecord], UIViewController?) {
        let (stale, records, host, cg, cur) = snapshotLock.withLock {
            let stale = cacheGen != currentScreenGen
            return (stale, stale ? [] : latestInventory, stale ? nil : inventoryHost, cacheGen, currentScreenGen)
        }
        logger?.debugSwiftUICapture("inventory() → \(stale ? "STALE [] " : "\(records.count) records ")(cacheGen=\(cg) currentGen=\(cur))")
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
        logger?.debugSwiftUICapture("textResolution() → \(stale ? "STALE [] " : "textMap=\(map.count) interactive=\(interactive.count) ")(cacheGen=\(cg) currentGen=\(cur))")
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
    /// Execute the actual deferred admission path deterministically, without waiting for a timer.
    func _testPerformPendingScan() {
        performPendingBackgroundScan()
    }

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
