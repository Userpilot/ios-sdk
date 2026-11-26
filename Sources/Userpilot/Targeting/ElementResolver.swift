//
//  ElementResolver.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Resolves selectors in one admitted native host using runtime instance ownership.
//

import UIKit

/// Main-thread-only targeting and full-host capture. Admission never starts autocapture.
internal protocol ElementTargeting: AnyObject {
    func admitHost() -> ElementTargetHost?
    func admitHost(in window: UIWindow) -> ElementTargetHost?
    func isValid(_ host: ElementTargetHost) -> Bool
    func captureLayout(in host: ElementTargetHost, completion: @escaping (ElementNode?) -> Void)
    func inflateSelector(from selector: ElementSelector) -> UserpilotElementSelector?
    func findMatches(
        for selector: UserpilotElementSelector, in tree: ElementNode, host: ElementTargetHost
    ) -> [ElementMatch]
    /// Whether the admitted screen is at its end, so a missing tooltip target can be
    /// reported: its main scroll area cannot scroll further down, or nothing visible scrolls
    /// vertically. False when the host can no longer be read. Completes on main.
    func isScreenAtEnd(in host: ElementTargetHost, completion: @escaping (Bool) -> Void)
    func resolve(selector: ElementSelector, in host: ElementTargetHost,
                 completion: @escaping (Result<ResolvedTarget, TargetResolutionError>) -> Void)
}

/// Selects a native host once, then reads only that host until its operation ends.
internal final class ElementResolver: ElementTargeting {
    private weak var owner: Userpilot?
    private let instanceRegistry: InstanceRegistering
    private let instanceResolver: InstanceResolving
    private let logger: Logging
    private let strategy: UserpilotElementTargetingStrategy

    init(container: DIContainer) {
        strategy = container.resolve(UserpilotElementTargetingStrategy.self)
        owner = container.owner
        instanceRegistry = container.resolve(InstanceRegistering.self)
        instanceResolver = container.resolve(InstanceResolving.self)
        logger = container.resolve(Userpilot.Config.self).logger
    }

    /// Window preference is evaluated only at admission, never by capture or retries.
    func admitHost() -> ElementTargetHost? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
        let candidates = windows.isEmpty ? UIApplication.shared.windows : windows
        let ordered = candidates.sorted {
            if $0.isKeyWindow != $1.isKeyWindow { return $0.isKeyWindow }
            return $0.windowLevel < $1.windowLevel
        }
        for window in ordered {
            if let host = admitHost(in: window) { return host }
        }
        logger.debug("Userpilot targeting: no eligible host window to capture")
        return nil
    }

    /// A nested explicit owner is valid even when another instance owns the window root.
    func admitHost(in window: UIWindow) -> ElementTargetHost? {
        guard let owner, instanceRegistry.isRegistered(owner),
              !window.isHidden, !window.isUserpilotWindow,
              let ownedView = ownedView(in: window, owner: owner) else { return nil }
        let host = ElementTargetHost(window: window, owner: owner)
        host.ownedView = ownedView
        return host
    }

    /// A detached/replaced host or removed owner cannot redirect work to another tenant.
    func isValid(_ host: ElementTargetHost) -> Bool {
        guard let owner, host.owner === owner, instanceRegistry.isRegistered(owner),
              let window = host.window, !window.isHidden, !window.isUserpilotWindow,
              window.rootViewController.map(ObjectIdentifier.init) == host.rootViewControllerID,
              window.windowScene === host.scene else { return false }
        if host.hadScene {
            guard let scene = host.scene,
                  !host.wasSceneConnected || UIApplication.shared.connectedScenes.contains(scene) else { return false }
        }
        return containsOwnedView(window, host: host, owner: owner)
    }

    /// Keeps full-window capture content and coordinates independent of autocapture settings.
    func captureLayout(in host: ElementTargetHost, completion: @escaping (ElementNode?) -> Void) {
        guard isValid(host), let window = host.window else { completion(nil); return }
        strategy.captureLayout(in: window) { [weak self] tree in
            guard let self, self.isValid(host) else { completion(nil); return }
            completion(tree)
        }
    }

    func inflateSelector(from selector: ElementSelector) -> UserpilotElementSelector? {
        strategy.inflateSelector(from: selector.effectiveProperties)
    }

    /// Filter candidates, not capture contents: a foreign parent may contain an owned child.
    func findMatches(
        for selector: UserpilotElementSelector, in tree: ElementNode, host: ElementTargetHost
    ) -> [ElementMatch] {
        guard isValid(host), let owner, let window = host.window else { return [] }
        return tree.matches(for: selector).filter {
            guard let view = $0.node.ownershipView, view === window || view.window === window else { return false }
            return instanceResolver.resolveOwner(from: view) === owner
        }
    }

    /// Asks the strategy first; a strategy without an answer uses the native scroll state.
    func isScreenAtEnd(in host: ElementTargetHost, completion: @escaping (Bool) -> Void) {
        guard isValid(host), let window = host.window else { completion(false); return }
        guard let isScrolledToEnd = strategy.isScrolledToEnd else {
            ScreenScrollState.isAtEnd(in: window, completion: completion)
            return
        }
        isScrolledToEnd(window) { [weak self, weak window] answer in
            guard let self, let window, self.isValid(host) else { completion(false); return }
            if let answer {
                completion(answer.boolValue)
            } else {
                ScreenScrollState.isAtEnd(in: window, completion: completion)
            }
        }
    }

    /// A resolve validates its host several times; while the last owned view is still in the
    /// window and still owned, each check costs one ownership lookup instead of a window walk.
    private func containsOwnedView(_ window: UIWindow, host: ElementTargetHost, owner: Userpilot) -> Bool {
        if let known = host.ownedView, known.isDescendant(of: window),
           instanceResolver.resolveOwner(from: known) === owner {
            return true
        }
        host.ownedView = ownedView(in: window, owner: owner)
        return host.ownedView != nil
    }

    private func ownedView(in view: UIView, owner: Userpilot) -> UIView? {
        // Hidden app views retain their bindings; visibility is enforced by traversal instead.
        if instanceResolver.resolveOwner(from: view) === owner { return view }
        for subview in view.subviews {
            if let owned = ownedView(in: subview, owner: owner) { return owned }
        }
        return nil
    }
}

extension ElementTargeting {
    func inflateSelector(from selector: ElementSelector) -> UserpilotElementSelector? {
        NativeElementTargetingStrategy().inflateSelector(from: selector.effectiveProperties)
    }

    /// WebView capture yields to its web process. Check admission again before using the result.
    ///
    /// Only the visible screen is searched. A match counts when it has a size and its middle
    /// is on the visible screen; otherwise the target is not found yet. A tie is `ambiguous`;
    /// a unique winner that cannot be used is `notVisible` or `overlapped`
    /// (see `ElementNode+TargetAvailability`).
    func resolve(
        selector: ElementSelector,
        in host: ElementTargetHost,
        completion: @escaping (Result<ResolvedTarget, TargetResolutionError>) -> Void
    ) {
        guard selector.isSupportedVersion else {
            completion(.failure(.unsupportedSelectorVersion(selector.selectorVersion)))
            return
        }
        guard let identity = inflateSelector(from: selector) else {
            completion(.failure(.invalidSelector))
            return
        }
        captureLayout(in: host) { [weak self] tree in
            guard let self, self.isValid(host), let tree else {
                completion(.failure(.layoutUnavailable))
                return
            }
            let matches = self.findMatches(for: identity, in: tree, host: host)
            completion(self.resolve(matches: matches, minimumScore: selector.minimumScore ?? 0))
        }
    }

    /// Preserve score-floor and unique-highest-match ordering for native and logical elements.
    private func resolve(
        matches: [ElementMatch], minimumScore: Int
    ) -> Result<ResolvedTarget, TargetResolutionError> {
        // A match whose middle is off the visible screen is not there yet, as the native
        // capture already decides.
        let eligible = matches.filter { $0.score >= minimumScore && $0.node.isOnVisibleScreen }
        guard let topScore = eligible.map(\.score).max() else { return .failure(.notFound) }
        let winners = eligible.filter { $0.score == topScore }
        guard winners.count == 1, let winner = winners.first else {
            return .failure(.ambiguous(matchCount: eligible.count))
        }
        // The winner must be seen and uncovered for a tooltip to point at it.
        if let reason = winner.node.unavailableReason(matchCount: eligible.count) {
            return .failure(reason)
        }
        return .success(ResolvedTarget(rect: winner.node.targetRect, score: winner.score,
                                       nodeID: winner.node.nodeID, view: winner.node.view))
    }
}
