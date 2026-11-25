//
//  TooltipViewController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Presents a Flow segment's anchored tooltips: resolves the target element, hands
//  its rect to the wrapper view, and turns the card's controls into step outcomes.
//
//  The segment's steps are **one presentation**. The action button advances by
//  index and closes the overlay after the segment's last step or the Flow's last
//  step, which may also record a deep link (see `TooltipViewController+Paging`).
//  The view model owns which step is showing.
//

import UIKit

// MARK: - TooltipViewController

/// Owns a Flow tooltip segment's native overlay, target recovery and terminal intent on main.
/// Target resolution gates reveal; only UIKit's completed dismissal releases the publisher's presentation.
internal final class TooltipViewController: UIViewController {

    // MARK: Properties

    /// Drives content, theme, and lifecycle events.
    internal let viewModel: TooltipViewModel

    /// The tooltip's view. Typed so the controller does not re-cast constantly.
    /// Non-private so `TooltipViewController+Paging` can rebind the card.
    lazy var wrapperView = TooltipWrapperView()

    /// Guards the terminal path: the overlay ends once, by **either** a close or
    /// the last step's action, never both. A close-then-action race would otherwise
    /// report two outcomes for one step.
    var hasReachedTerminalState = false

    /// Whether the card has been revealed at least once. Distinct from
    /// `isTrackingGeometry`: a tooltip can be revealed, disappear, and reappear,
    /// and tracking has to be restarted for the second appearance even though it
    /// is no longer the first reveal.
    /// Non-private: the paging extension branches on it.
    var hasRevealed = false

    /// A Flow overlay faded out because its next step's target was not there at once.
    var isParked = false

    /// A held Flow overlay still shows the previous step's card until the next target resolves.
    var hasPendingStep = false

    /// The app host admitted before presentation, retained across target retries.
    private var targetingHost: ElementTargetHost?

    /// Owns target work. The paging extension reuses it when the current step changes.
    lazy var targetCoordinator = TooltipTargetCoordinator(
        resolveTarget: { [weak self] completion in
            guard let self, let host = self.targetingHost else { completion(.failure(.layoutUnavailable)); return }
            self.viewModel.resolveTarget(in: host, completion: completion)
        },
        isScreenAtEnd: { [weak self] completion in
            guard let self, let host = self.targetingHost else { completion(false); return }
            self.viewModel.isScreenAtEnd(in: host, completion: completion)
        },
        scrollViews: { [weak self] in
            self?.targetingHost?.window?.userpilotScrollViews() ?? []
        },
        layoutRoot: { [weak self] in
            self?.targetingHost?.window
        }
    )

    /// Admission selects the app host once; delayed retries retain only its weak native references.
    func admitTargetHost() -> UIWindow? {
        if targetingHost == nil { targetingHost = viewModel.admitTargetHost() }
        return targetingHost?.window
    }

    /// When the last advance happened, for `advance(to:)`'s re-entry guard.
    /// Stored here because an extension cannot hold state.
    var lastAdvanceAt: Date?

    /// A further advance inside this window is treated as a double tap.
    var advanceReentryWindow: TimeInterval = 0.3

    /// Every step's target retry ladder, in milliseconds.
    var retryIntervals = Constants.Theme.tooltipRetryIntervals

    // MARK: Initialization

    /// - Parameter viewModel: view model built by the publisher's
    ///   generic presentation factory.
    init(viewModel: TooltipViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        // Covers the whole screen without a system dimming view of its own — the
        // keyhole backdrop is ours and must not be doubled.
        modalPresentationStyle = .overFullScreen
        // Plain cross-dissolve for tooltips and no custom
        // animator; nothing on the card animates its alpha, scale, or transform
        // on appear.
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Lifecycle

    /// `viewWillAppear` can run before UIKit attaches this controller to the SDK window.
    /// It must never become an app screen or cancel its own experience as navigation.
    override var userpilotIgnoreScreen: Bool { true }

    override func loadView() {
        view = wrapperView

        // Keep the card hidden until placement exists. ExperienceOverlayWindow also
        // yields hit testing while hidden, so the modal container does not block
        // host scrolling needed to bring a parked target into view.
        wrapperView.isHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Once visible the tooltip blocks the host app, so VoiceOver must not
        // wander into the content behind it. Harmless while hidden — a hidden
        // view is not in the accessibility tree at all.
        view.accessibilityViewIsModal = true

        targetCoordinator.onResolved = { [weak self] rect in
            self?.handleResolvedTarget(rect)
        }
        targetCoordinator.onTargetLost = { [weak self] in
            self?.viewModel.logTargetLost()
            self?.dismissForTargetLost()
        }
        targetCoordinator.onUnresolvable = { [weak self] in
            self?.handleUnresolvable()
        }
        targetCoordinator.onAttemptFailed = { [weak self] in
            // A step whose target is not there at once fades the overlay out instead of cutting.
            self?.park()
        }
        targetCoordinator.onTargetNotFound = { [weak self] error, attempts, elapsed in
            // The step's error is its outcome, and runs the step's fallback.
            guard let self, self.viewModel.onTargetNotFound(
                error: error, attemptCount: attempts, elapsedMs: elapsed) else { return }
            self.runFallback()
        }

        bindViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasReachedTerminalState else { return }
        // Start after content binding and initial layout so the coordinator uses the
        // measured card size. Reveal reports seen only after a target has resolved
        // and the card becomes visible.
        targetCoordinator.start(retryIntervals: retryIntervals)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Every terminal path ends here. Without it a dismissed tooltip keeps
        // walking the view hierarchy on a timer, or sits parked on the scroll
        // observer, for the life of the process.
        targetCoordinator.stop()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            // Once visible, the geometry tracker already fires on rotation (the
            // backdrop's bounds change), so re-attempting here would resolve
            // twice per rotation — and worse, a transient mid-rotation miss
            // would consume ladder rungs and eventually park a tooltip that is
            // on screen, waiting on a scroll that a blocking backdrop guarantees
            // will never arrive.
            self.targetCoordinator.handleRotation()
        }, completion: nil)
    }

    // MARK: Binding

    private func bindViewModel() {
        viewModel.bindData = { [weak self] canBindData in
            guard let self else { return }

            // The segment's first step. Paging from here on is the controller's,
            // added in the paging extension.
            guard canBindData, let step = self.viewModel.tooltipSteps.first else {
                self.viewModel.logNotRenderable()
                self.abandonPresentation()
                return
            }

            // Per-step, and re-run on every advance — see
            // `applyStepConfiguration` in `TooltipViewController+Paging`.
            self.applyStepConfiguration()
            self.bindCard(step: step)
        }

        viewModel.onStart()
    }

    /// Renders the step and wires the card's controls.
    func bindCard(step: Step) {
        wrapperView.cardView.setupView(
            step: step,
            style: TooltipStyle(theme: viewModel.tooltipTheme),
            isRTL: viewModel.isRTL,
            stepIndex: viewModel.progressStepIndex,
            stepCount: viewModel.progressStepsCount
        )

        wrapperView.cardView.onAction = { [weak self] action in
            self?.handleAction(action)
        }
        wrapperView.cardView.onClose = { [weak self] in
            self?.onClose()
        }
    }

    // MARK: Targeting

    /// Reveals every resolved step. The first reveal reports the segment's first step;
    /// each later step reports as it is revealed. Placement can change after rotation.
    private func handleResolvedTarget(_ rect: CGRect) {
        guard !hasReachedTerminalState else { return }
        let returnsFromPark = prepareFlowReveal()
        wrapperView.targetRect = view.convert(rect, from: nil)
        targetCoordinator.beginTracking(in: wrapperView.backdropView)
        // A host drag still in progress would keep moving the content under the revealing overlay.
        if wrapperView.isHidden {
            targetingHost?.window?.userpilotScrollViews().forEach { $0.userpilotCancelDragInProgress() }
        }
        wrapperView.isHidden = false
        if returnsFromPark { fadeInFromPark() }

        guard !hasRevealed else { viewModel.onStepRevealed(); return }
        hasRevealed = true
        viewModel.logRevealed(at: wrapperView.resolvedPlacement, attemptCount: targetCoordinator.attemptCount)
        viewModel.onExperienceSeen()
    }

    /// Dismisses a visible tooltip whose target has gone. An SDK-driven close, so it sends nothing.
    func dismissForTargetLost() {
        endAsDismissal(reason: .targetLost)
    }

    /// No terminal engagement is invented for a tooltip that never appeared. A parked Flow
    /// overlay whose step error was its outcome closes the same way.
    ///
    /// Deferred one main-queue turn because this can be reached from
    /// `viewDidLoad`, which runs *inside* the publisher's `present(_:animated:)`,
    /// and UIKit ignores a `dismiss` issued mid-transition — which would strand
    /// the overlay window.
    func abandonPresentation() {
        guard beginTermination() else { return }

        performOn(.main) { [weak self] in
            self?.dismissTooltip {
                // Idling normally rides on the close event, and this path
                // deliberately emits none — so it has to be done explicitly, or
                // the publisher keeps ownership and no
                // later experience of any type is ever presented.
                self?.viewModel.onExperienceDismissalCompleted()
            }
        }
    }

    /// Claims terminal intent before any event or native animation can re-enter.
    private func beginTermination() -> Bool {
        guard !hasReachedTerminalState else { return false }
        hasReachedTerminalState = true
        targetCoordinator.stop()
        return true
    }

    // MARK: Actions

    /// Reports the last step's action before removal. Only the Flow's last step records its link,
    /// which the publisher opens after final release.
    func completeTooltip(deepLink: String?, isLink: Bool = false) {
        guard beginTermination() else { return }

        endPresentation { [weak self] in
            self?.viewModel.onExperienceCompleted(deepLink: deepLink, isLink: isLink)
        }
    }

    /// Close button: always a dismissal, never a completion. A step's close counts once it was seen.
    private func onClose() {
        guard canTakeUserAction else { return }
        endAsDismissal(reason: .closeButton)
    }

    /// Ends the presentation as a dismissal, with its reason.
    private func endAsDismissal(reason: TooltipDismissReason) {
        guard beginTermination() else { return }

        endPresentation { [weak self] in
            self?.viewModel.onTooltipDismissed(reason: reason)
        }
    }

    /// A step reports at the committed action, before the fade; the publisher hears about
    /// the removal last.
    private func endPresentation(reporting report: () -> Void) {
        report()
        dismissTooltip { [weak self] in
            self?.viewModel.onExperienceDismissalCompleted()
        }
    }

    // MARK: Dismissal

    /// SDK closes that joined a dismissal already in flight; each runs once UIKit removes this controller.
    private var dismissalWaiters: [() -> Void] = []
    /// Set once UIKit removed this controller, so a later SDK close completes at once.
    private(set) var hasCompletedDismissal = false

    /// Runs terminal callbacks and waiting SDK closes only after UIKit finishes removing this controller.
    /// The publisher then decides whether to request a reload or open the selected completion link.
    private func dismissTooltip(completion: (() -> Void)?) {
        dismiss(animated: true) { [weak self] in
            self?.hasCompletedDismissal = true
            completion?()
            let waiters = self?.dismissalWaiters ?? []
            self?.dismissalWaiters.removeAll()
            waiters.forEach { $0() }
        }
    }
}

// MARK: - UPExperience

extension TooltipViewController: UPExperienceDelegate {

    /// Closes the tooltip from outside. The host app's close (`manualClose`) of a seen step dismisses it
    /// like a modal step. A step never revealed, and every SDK-driven close (navigation, logout, QR
    /// preview, Builder capture), closes silently so the run pauses.
    ///
    /// Latches the terminal state so an external close cannot race the user's
    /// own tap into emitting two terminal events.
    func triggerCloseExperience(manualClose: Bool, completion: (() -> Void)?) {
        performOnMain { [weak self] in
            self?.closeOnMain(manualClose: manualClose, completion: completion)
        }
    }

    /// Joins a dismissal already in flight, else reports a host close of a seen step and dismisses.
    private func closeOnMain(manualClose: Bool, completion: (() -> Void)?) {
        // Already terminal: a dismissal is in flight from the user's own tap.
        // Issuing a second `dismiss` on the same controller would run both
        // completions, double-reporting the dismissal and letting this interleave
        // with a deep link the action button started.
        guard !hasReachedTerminalState else {
            // The publisher may join an existing dismissal, but must wait for UIKit removal.
            if let completion {
                if hasCompletedDismissal {
                    completion()
                } else {
                    dismissalWaiters.append(completion)
                }
            }
            return
        }
        let reportsClose = manualClose && canTakeUserAction
        guard beginTermination() else { return }

        viewModel.onTooltipDismissed(reason: reportsClose ? .hostClose : .sdkReset)
        dismissTooltip { [weak self] in
            if let completion {
                completion()
            } else {
                self?.viewModel.onExperienceDismissalCompleted()
            }
        }
    }
}
