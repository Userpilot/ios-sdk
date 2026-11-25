//
//  TargetGeometryTracker.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Observes presentation-container bounds changes with a native layout observer.
//  This does not track continuous target movement or host-app scrolling.
//

import UIKit

// MARK: - TargetGeometryTracker

/// Reports geometry changes that require a tooltip to be re-placed.
internal final class TargetGeometryTracker {

    // MARK: Properties

    /// Called on the main thread when the geometry changed.
    ///
    /// The handler is expected to **re-run the whole selector match**, not reuse
    /// a previously resolved view. A host app may have recycled the cell that
    /// view belonged to, in which case the object is still alive and still
    /// laid out — just showing different content. Re-matching is the only way to
    /// be sure the rect still belongs to the element the tooltip was authored
    /// against.
    var onGeometryChanged: (() -> Void)?

    /// The invisible view whose layout passes provide the signal.
    private let observerView = FrameObserverView()

    // MARK: Lifecycle

    /// Starts observing `container`'s geometry.
    ///
    /// - Parameter container: the tooltip's backdrop, which spans the presentation.
    func start(in container: UIView) {
        observerView.translatesAutoresizingMaskIntoConstraints = false
        container.insertSubview(observerView, at: 0)

        NSLayoutConstraint.activate([
            observerView.topAnchor.constraint(equalTo: container.topAnchor),
            observerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            observerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            observerView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        // Settle the bounds *before* attaching the handler, or the first layout
        // pass reports a change from `.zero` that is really just the view being
        // installed — and that spurious fire would re-resolve the target before
        // the card has even been placed.
        observerView.layoutIfNeeded()

        observerView.onChange = { [weak self] in
            self?.onGeometryChanged?()
        }
    }

    /// Stops observing and detaches. Safe to call more than once.
    func stop() {
        observerView.onChange = nil
        observerView.removeFromSuperview()
    }
}

// MARK: - FrameObserverView

/// A zero-cost view that reports when its bounds change.
///
/// Exists because UIKit offers no other reliable notification: `frame` and
/// `bounds` are not KVO-compliant, and observing them is documented as
/// unsupported. A pinned view's `layoutSubviews` is, by contrast, exactly the
/// moment the system has finished deciding the new geometry.
private final class FrameObserverView: UIView {

    /// Called when `bounds` changes to a new value.
    var onChange: (() -> Void)?

    /// Last reported bounds, so an unchanged layout pass stays silent. Layout
    /// runs far more often than geometry actually changes.
    private var lastBounds: CGRect = .zero

    init() {
        super.init(frame: .zero)
        // Never take a touch: this sits at the back of the backdrop and would
        // otherwise intercept taps meant for the dim.
        isUserInteractionEnabled = false
        isHidden = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard bounds != lastBounds else { return }
        lastBounds = bounds
        onChange?()
    }
}
