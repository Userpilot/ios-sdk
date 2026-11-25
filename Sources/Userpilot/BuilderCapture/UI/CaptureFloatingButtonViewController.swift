//
//  CaptureFloatingButtonViewController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Positions capture controls while passing unrelated touches to the host.
//

import UIKit

// MARK: - CaptureFloatingButtonViewController

/// Hosts the floating capture button.
internal final class CaptureFloatingButtonViewController: UIViewController {

    // MARK: Nested Types

    private enum Constants {
        /// Inset from the safe area so the parked widget is fully on screen.
        static let edgeMargin: CGFloat = 16
        /// Fraction of the screen height the widget starts at.
        static let initialVerticalPosition: CGFloat = 0.75
        static let snapDamping: CGFloat = 0.75
        static let snapDuration: TimeInterval = 0.45
        /// Below this projected travel a throw counts as a drop, and the button
        /// snaps straight to the nearer side instead of following a direction.
        static let flickThreshold: CGFloat = 500
        static let messageFontSize: CGFloat = 13
        static let messageCornerRadius: CGFloat = 8
        static let messageInset: CGFloat = 24
        static let messageBottomInset: CGFloat = 32
        static let messageVisibleDuration: TimeInterval = 2.5
        static let messageFadeDuration: TimeInterval = 0.25
    }

    // MARK: Properties

    /// Called when the operator taps the button.
    private let onCapture: () -> Void

    /// Called when the operator long-presses to leave capture mode.
    private let onExit: () -> Void

    /// Where the button was when the current drag began, in view coordinates.
    private var dragOrigin: CGPoint = .zero

    /// Fractional dock position within restingBounds, preserved across bounds changes.
    private var dockFraction = CGPoint(x: 1, y: Constants.initialVerticalPosition)

    /// Bounds the dock fraction was last applied against, so layout only
    /// repositions when the geometry actually changed.
    private var appliedBounds: CGRect = .zero

    /// The widget. It owns its own appearance; this controller owns its position.
    private lazy var pillView = CapturePillView(
        onCapture: { [weak self] in self?.onCapture() },
        onClose: { [weak self] in self?.onExit() }
    )

    /// Transient capture status shown to the operator.
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: Constants.messageFontSize, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        label.layer.cornerRadius = Constants.messageCornerRadius
        label.clipsToBounds = true
        label.alpha = 0
        label.isUserInteractionEnabled = false
        return label
    }()

    // MARK: Initialization

    /// Capture and exit callbacks run on main; exit is available through close or long press.
    init(onCapture: @escaping () -> Void, onExit: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onExit = onExit
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Lifecycle

    override func loadView() {
        // Flagged so the SDK's own screen tracking ignores this controller —
        // capture mode must not emit a screen event or overwrite the tracked
        // screen, which is the very value the capture is about to record.
        objc_setAssociatedObject(
            self,
            &ScreenNameTracker.untrackedScreenKey,
            true,
            .OBJC_ASSOCIATION_RETAIN
        )

        let root = CapturePassthroughView()
        root.backgroundColor = .clear
        self.view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(pillView)
        view.addSubview(messageLabel)

        // On the pill rather than on either control, so the whole widget drags as
        // one piece no matter which part of it the finger lands on.
        pillView.addGestureRecognizer(
            UIPanGestureRecognizer(target: self, action: #selector(buttonDragged))
        )
        pillView.addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: #selector(buttonLongPressed))
        )

        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -Constants.messageBottomInset),
            messageLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor,
                constant: Constants.messageInset),
            messageLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -Constants.messageInset)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Re-apply the *fractional* dock position whenever the resting rect
        // changes shape (rotation, split-view resize, safe-area change), and only
        // then. Repositioning on every pass would yank the button back after the
        // operator moved it; never repositioning would strand it off-screen after
        // a rotation, with no way to reach it.
        let bounds = restingBounds
        guard !bounds.isNull, !bounds.isEmpty, bounds != appliedBounds else { return }

        appliedBounds = bounds
        pillView.center = CGPoint(
            x: bounds.minX + bounds.width * dockFraction.x,
            y: bounds.minY + bounds.height * dockFraction.y
        )
    }

    // MARK: Visibility

    /// Hides the widget during confirmation to keep it from intercepting sheet touches.
    func setButtonHidden(_ hidden: Bool) {
        pillView.isHidden = hidden
    }

    /// Briefly shows `text` to the operator, then fades it out.
    func showMessage(_ text: String) {
        messageLabel.text = "  \(text)  "
        messageLabel.layer.removeAllAnimations()

        UIView.animate(withDuration: Constants.messageFadeDuration) { [weak self] in
            self?.messageLabel.alpha = 1
        } completion: { _ in
            UIView.animate(
                withDuration: Constants.messageFadeDuration,
                delay: Constants.messageVisibleDuration,
                animations: { [weak self] in self?.messageLabel.alpha = 0 }
            )
        }
    }

    // MARK: Actions

    /// Long press exits on began, alongside the visible close control.
    @objc private func buttonLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onExit()
    }

    /// Drags the widget, and on release throws it to a screen edge.
    @objc private func buttonDragged(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            dragOrigin = pillView.center

        case .changed:
            let translation = recognizer.translation(in: view)
            pillView.center = CGPoint(
                x: dragOrigin.x + translation.x,
                y: dragOrigin.y + translation.y
            )

        case .ended, .cancelled:
            let velocity = recognizer.velocity(in: view)
            snapToEdge(from: pillView.center, velocity: velocity)

        default:
            break
        }
    }

    // MARK: Edge Snapping

    /// Allowed widget-centre bounds inside the safe area. Callers handle a null rect on very small windows.
    private var restingBounds: CGRect {
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        return safe.insetBy(
            dx: CapturePillView.size.width / 2 + Constants.edgeMargin,
            dy: CapturePillView.size.height / 2 + Constants.edgeMargin
        )
    }

    /// Animates the widget to its resting edge and records the dock fraction.
    private func snapToEdge(from point: CGPoint, velocity: CGPoint) {
        let bounds = restingBounds
        guard !bounds.isNull, !bounds.isEmpty else { return }

        let projected = CGPoint(
            x: point.x + Self.project(initialVelocity: velocity.x),
            y: point.y + Self.project(initialVelocity: velocity.y)
        )
        let destination = Self.restingPoint(from: point, to: projected, within: bounds)

        // Recorded as a fraction so the position survives a rotation. See
        // `dockFraction`.
        dockFraction = CGPoint(
            x: (destination.x - bounds.minX) / bounds.width,
            y: (destination.y - bounds.minY) / bounds.height
        )
        appliedBounds = bounds

        UIView.animate(
            withDuration: Constants.snapDuration,
            delay: 0,
            usingSpringWithDamping: Constants.snapDamping,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { [weak self] in self?.pillView.center = destination },
            completion: nil
        )
    }

    /// Distance a flick travels while decelerating to zero at UIKit's normal
    /// scroll deceleration rate. This is the standard UIScrollView projection.
    private static func project(initialVelocity: CGFloat) -> CGFloat {
        let decelerationRate = UIScrollView.DecelerationRate.normal.rawValue
        return (initialVelocity / 1_000) * decelerationRate / (1 - decelerationRate)
    }

    /// Clamps or projects the released position along its velocity, then docks to a vertical edge.
    private static func restingPoint(
        from initial: CGPoint,
        to projected: CGPoint,
        within rect: CGRect
    ) -> CGPoint {
        var point: CGPoint

        if !rect.contains(initial) {
            point = CGPoint(
                x: min(max(initial.x, rect.minX), rect.maxX),
                y: min(max(initial.y, rect.minY), rect.maxY)
            )
        } else if hypot(projected.x - initial.x, projected.y - initial.y)
                    < Constants.flickThreshold {
            point = CGPoint(
                x: initial.x < rect.midX ? rect.minX : rect.maxX,
                y: initial.y
            )
        } else {
            point = edgeIntersection(from: initial, to: projected, within: rect)
        }

        // Never park on the top or bottom edge — slide to the nearer side.
        if point.y == rect.minY || point.y == rect.maxY {
            point.x = point.x < rect.midX ? rect.minX : rect.maxX
        }

        return point
    }

    /// Returns the nearest forward intersection between the throw direction and the resting rectangle.
    private static func edgeIntersection(
        from initial: CGPoint,
        to projected: CGPoint,
        within rect: CGRect
    ) -> CGPoint {
        let angle = atan2(projected.y - initial.y, projected.x - initial.x)
        let deltaX = cos(angle)
        let deltaY = sin(angle)

        let distances = [
            (rect.maxX - initial.x) / deltaX,
            (rect.maxY - initial.y) / deltaY,
            (rect.minX - initial.x) / deltaX,
            (rect.minY - initial.y) / deltaY
        ].map { $0.isFinite && $0 > 0 ? $0 : CGFloat.greatestFiniteMagnitude }

        guard let travel = distances.min(), travel < .greatestFiniteMagnitude else {
            return initial
        }

        return CGPoint(x: initial.x + travel * deltaX, y: initial.y + travel * deltaY)
    }
}

// MARK: - Passthrough Root View

/// Root view whose own area never claims touches; only its subviews can.
private final class CapturePassthroughView: UIView {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result === self ? nil : result
    }
}
