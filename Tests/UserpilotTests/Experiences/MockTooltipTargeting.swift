//
//  MockTooltipTargeting.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Controlled admitted host and target outcomes for renderer and publisher tests.
//

import UIKit
@testable import Userpilot

/// Finds nothing, but *recoverably* (`notFound`): the coordinator parks, exactly
/// as for a target below the fold. The real resolver has no host window under
/// test and reports `layoutUnavailable`, which abandons the presentation.
final class MockTooltipTargeting: ElementTargeting {
    /// `invalidSelector` is non-retryable, so the recovery controller reports it
    /// unrecoverable on the first attempt without waiting on the ladder.
    var isUnrecoverable = false

    /// Accessibility identifiers this double actually resolves. Empty by default,
    /// which is the parking behaviour every test that does not opt in relies on.
    var resolvableIdentifiers: Set<String> = []

    /// The screen-end answer for a target that is not found. At end by default, so a
    /// missing target alerts once the ladder is spent.
    var isAtEnd = true

    /// Accessibility identifier of every selector the coordinator asked about.
    private(set) var resolvedIdentifiers: [String] = []

    private let hostWindow: UIWindow
    private weak var owner: Userpilot?

    init(owner: Userpilot, window: UIWindow = UIWindow()) {
        self.owner = owner
        hostWindow = window
    }

    func admitHost() -> ElementTargetHost? { admitHost(in: hostWindow) }
    func admitHost(in window: UIWindow) -> ElementTargetHost? {
        owner.map { ElementTargetHost(window: window, owner: $0) }
    }
    func isValid(_ host: ElementTargetHost) -> Bool { host.owner === owner }
    func captureLayout(in host: ElementTargetHost, completion: @escaping (ElementNode?) -> Void) { completion(nil) }
    func inflateSelector(from selector: ElementSelector) -> UserpilotElementSelector? {
        isUnrecoverable ? nil : NativeElementTargetingStrategy().inflateSelector(from: selector.effectiveProperties)
    }
    func findMatches(
        for selector: UserpilotElementSelector, in tree: ElementNode, host: ElementTargetHost
    ) -> [ElementMatch] { [] }
    func isScreenAtEnd(in host: ElementTargetHost, completion: @escaping (Bool) -> Void) { completion(isAtEnd) }

    /// Overrides the protocol extension's real resolution, which cannot succeed
    /// under test: it walks a live window hierarchy, and there is none here.
    /// Recording moved with it, since the default path's `inflateSelector` no
    /// longer runs.
    func resolve(
        selector: ElementSelector, in host: ElementTargetHost,
        completion: @escaping (Result<ResolvedTarget, TargetResolutionError>) -> Void
    ) {
        let identifier = selector.effectiveProperties["accessibility_identifier"] ?? ""
        resolvedIdentifiers.append(identifier)

        guard !isUnrecoverable else { completion(.failure(.invalidSelector)); return }
        guard resolvableIdentifiers.contains(identifier) else { completion(.failure(.notFound)); return }
        completion(.success(ResolvedTarget(
            rect: CGRect(x: 40, y: 200, width: 120, height: 44),
            score: 20_000,
            nodeID: identifier,
            view: nil
        )))
    }
}
