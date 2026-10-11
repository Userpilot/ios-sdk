//
//  UPExperienceHostingController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Mounts the SwiftUI root with UIKit containment, sizing, keyboard and actual dismissal ownership.
//

import SwiftUI

/// Native presentation remains separate from model-to-component rendering.
internal final class UPExperienceHostingController: UIViewController, UPExperience {
    enum Style { case fullScreen, dialog, bottomSheet }

    let state: ExperienceRenderState
    let style: Style
    private(set) var contentController: UIHostingController<UPExperienceRootView>?
    private(set) var carouselController: UPExperienceCarouselController?
    private var transitionAnimator: UIViewPropertyAnimator?
    private var resizeAnimator: UIViewPropertyAnimator?
    private var renderedSurveyStep: Int?
    private var headerController: UIHostingController<UPExperienceRootView>?
    private var footerController: UIHostingController<UPExperienceRootView>?
    private var headerHeight: NSLayoutConstraint?
    private var footerHeight: NSLayoutConstraint?
    private let scrollView = UIScrollView()
    private let cardView = UIView()
    private let backdropView = UIView()
    private var cardTop: NSLayoutConstraint?
    private var hasAnimatedEntrance = false
    private var contentTop: NSLayoutConstraint?
    private var contentHeight: NSLayoutConstraint?
    private var cardHeight: NSLayoutConstraint?
    private var cardWidth: NSLayoutConstraint?
    private var keyboardHeight: CGFloat = 0
    private var hasFinishedDismissing = false
    private var dismissalCompletions: [() -> Void] = []

    init(state: ExperienceRenderState, style: Style) {
        self.state = state
        self.style = style
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        isModalInPresentation = true
        view.accessibilityViewIsModal = true
        objc_setAssociatedObject(self, &ScreenNameTracker.untrackedScreenKey, true, .OBJC_ASSOCIATION_RETAIN)
        state.dismiss = { [weak self] completion in self?.dismissExperience(completion: completion) }
        state.didChange = { [weak self] in self?.updateAppearance() }
        state.start()
        if style == .fullScreen, case .flow(let model) = state.content,
            model.flowContent?.type == .carousel {
            mountCarousel(model)
        } else {
            mountContent()
        }
        if style != .fullScreen {
            cardView.alpha = 0
            backdropView.alpha = 0
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardChanged),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardChanged),
            name: UIResponder.keyboardWillHideNotification, object: nil)
        ExternalKeyboardManagerCompat.disableIQKeyboardManager(for: [UPExperienceHostingController.self])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !state.isReady {
            state.close()
            return
        }
        animateEntrance()
        state.appeared()
        UIAccessibility.post(notification: .screenChanged, argument: view)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSize()
    }

    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        if !state.isClosing { view.setNeedsLayout() }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        state.backgroundColor.isLightColor() ? .darkContent : .lightContent
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func mountCarousel(_ model: ExperienceViewModel) {
        let pager = UPExperienceCarouselController(state: state, model: model)
        carouselController = pager
        addChild(pager)
        view.addSubview(pager.view)
        pager.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pager.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pager.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            pager.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pager.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        pager.didMove(toParent: self)
        updateAppearance()
    }

    private func mountContent() {
        let header = makeContentController(.header)
        let content = makeContentController(.content)
        let footer = makeContentController(.footer)
        headerController = header
        contentController = content
        footerController = footer
        mountBackdrop()
        view.addSubview(cardView)
        [header.view, scrollView, footer.view].forEach { cardView.addSubview($0) }
        scrollView.addSubview(content.view)
        [cardView, scrollView, header.view, content.view, footer.view].forEach {
            $0?.translatesAutoresizingMaskIntoConstraints = false
        }
        cardView.clipsToBounds = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.contentInsetAdjustmentBehavior = .never
        cardTop = cardView.topAnchor.constraint(equalTo: view.topAnchor)
        contentTop = content.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor)
        contentHeight = content.view.heightAnchor.constraint(equalToConstant: 1)
        headerHeight = header.view.heightAnchor.constraint(equalToConstant: 1)
        footerHeight = footer.view.heightAnchor.constraint(equalToConstant: 1)
        cardHeight = cardView.heightAnchor.constraint(equalToConstant: 1)
        cardWidth = cardView.widthAnchor.constraint(equalToConstant: 1)
        let dimensions = [cardTop, contentTop, contentHeight, headerHeight, footerHeight, cardHeight, cardWidth]
        NSLayoutConstraint.activate(dimensions.compactMap { $0 })
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            header.view.topAnchor.constraint(equalTo: cardView.topAnchor),
            header.view.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            header.view.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: header.view.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footer.view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            footer.view.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            footer.view.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            footer.view.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            content.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        [header, content, footer].forEach { $0.didMove(toParent: self) }
        updateAppearance()
    }

    private func mountBackdrop() {
        view.addSubview(backdropView)
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func makeContentController(_ region: ExperienceRenderRegion) -> UIHostingController<UPExperienceRootView> {
        let controller = UIHostingController(
            rootView: UPExperienceRootView(state: state, width: max(1, view.bounds.width), region: region))
        objc_setAssociatedObject(controller, &ScreenNameTracker.untrackedScreenKey, true, .OBJC_ASSOCIATION_RETAIN)
        controller.view.backgroundColor = .clear
        if #available(iOS 16.0, *) { controller.sizingOptions = .preferredContentSize }
        addChild(controller)
        return controller
    }

    /// View bounds and safe area belong to this window/scene; never size against UIScreen.main.
    private func updateSize(animated: Bool = true) {
        guard !state.isClosing, let controller = contentController, view.bounds.width > 0 else { return }
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let width = cardContentWidth(safe)
        let availableHeight = max(1, safe.height - keyboardHeight)
        let widthChanged = abs((cardWidth?.constant ?? 0) - width) > 0.5
        if widthChanged {
            cardWidth?.constant = width
            controller.rootView = UPExperienceRootView(state: state, width: width, region: .content)
            headerController?.rootView = UPExperienceRootView(state: state, width: width, region: .header)
            footerController?.rootView = UPExperienceRootView(state: state, width: width, region: .footer)
        }
        let proposal = CGSize(width: width, height: .greatestFiniteMagnitude)
        let contentSize = max(1, ceil(controller.sizeThatFits(in: proposal).height))
        let headerSize = ceil(headerController?.sizeThatFits(in: proposal).height ?? 0)
        let footerSize = ceil(footerController?.sizeThatFits(in: proposal).height ?? 0)
        let total = contentSize + headerSize + footerSize
        let height = style == .fullScreen ? availableHeight : min(total, availableHeight * 0.9)
        setHeight(contentHeight, contentSize)
        setHeight(headerHeight, headerSize)
        setHeight(footerHeight, footerSize)
        let remaining = max(0, height - headerSize - footerSize - contentSize)
        switch state.verticalAlignment {
        case .middle, .center: setHeight(contentTop, remaining / 2)
        case .bottom: setHeight(contentTop, remaining)
        case .top: setHeight(contentTop, 0)
        }
        let top: CGFloat
        switch style {
        case .fullScreen: top = safe.minY
        case .dialog: top = safe.minY + (availableHeight - height) / 2
        case .bottomSheet: top = safe.minY + availableHeight - height
        }
        // The card's vertical position follows the keyboard without rebuilding its SwiftUI identity.
        updateCardSize(height: height, top: top, animated: animated && !widthChanged)
    }

    private func cardContentWidth(_ safe: CGRect) -> CGFloat {
        switch style {
        case .dialog: return safe.width * (safe.width > safe.height ? 0.7 : 0.9)
        case .bottomSheet: return max(1, safe.width - UPExperienceLayout.sheetMargin * 2)
        case .fullScreen: return safe.width
        }
    }

    private func setHeight(_ constraint: NSLayoutConstraint?, _ value: CGFloat) {
        if abs((constraint?.constant ?? 0) - value) > 0.5 { constraint?.constant = value }
    }

    private func updateAppearance() {
        guard isViewLoaded else { return }
        view.backgroundColor = style == .fullScreen ? state.backgroundColor : .clear
        backdropView.backgroundColor = style == .fullScreen ? .clear : state.backdropColor
        cardView.backgroundColor = state.backgroundColor
        cardView.layer.cornerRadius = style == .fullScreen ? 0 : state.cornerRadius
        view.semanticContentAttribute = state.isRTL ? .forceRightToLeft : .forceLeftToRight
        carouselController?.updateSelection()
        refreshSurveyStepContent()
        setNeedsStatusBarAppearanceUpdate()
        performOn(.main) { [weak self] in
            self?.view.setNeedsLayout()
            self?.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardChanged(_ notification: Notification) {
        stopResizeAtCurrentPosition()
        if notification.name == UIResponder.keyboardWillHideNotification {
            keyboardHeight = 0
        } else if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let local = view.convert(frame, from: nil)
            keyboardHeight = max(0, view.bounds.intersection(local).height - view.safeAreaInsets.bottom)
        }
        updateSize(animated: false)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        if let responder = view.firstResponder as? UIView {
            scrollView.scrollRectToVisible(responder.convert(responder.bounds, to: scrollView), animated: false)
        }
    }

    /// Multiple close requests share one UIKit completion; callers are never told dismissal finished early.
    func triggerCloseExperience(manualClose: Bool, completion: (() -> Void)?) {
        if let completion { dismissalCompletions.append(completion) }
        if hasFinishedDismissing {
            drainDismissalCompletions()
            return
        }
        state.cancel(manualClose: manualClose)
    }

}

private extension UPExperienceHostingController {
    func animateEntrance() {
        guard style != .fullScreen, !hasAnimatedEntrance, !state.isClosing else { return }
        hasAnimatedEntrance = true
        view.layoutIfNeeded()
        guard !UIAccessibility.isReduceMotionEnabled else {
            cardView.alpha = 1
            backdropView.alpha = 1
            return
        }
        // Establish the offscreen pose before revealing the card. Layout stays at its final position.
        cardView.transform = hiddenTransform
        cardView.alpha = style == .dialog ? 0 : 1
        let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeOut) { [weak self] in
            self?.backdropView.alpha = 1
            self?.cardView.alpha = 1
            self?.cardView.transform = .identity
        }
        transitionAnimator = animator
        animator.startAnimation()
    }

    private var hiddenTransform: CGAffineTransform {
        if style == .bottomSheet {
            return CGAffineTransform(translationX: 0, y: view.bounds.height - (cardTop?.constant ?? 0))
        }
        return CGAffineTransform(scaleX: 0.96, y: 0.96)
    }

    private func dismissExperience(completion: @escaping () -> Void) {
        stopResizeAtCurrentPosition()
        // Stop entrance at its current visual position; no second animation can reverse this exit.
        if transitionAnimator?.state == .active {
            transitionAnimator?.stopAnimation(false)
            transitionAnimator?.finishAnimation(at: .current)
        }
        view.endEditing(true)
        if style == .fullScreen || UIAccessibility.isReduceMotionEnabled {
            removePresentation(animated: style == .fullScreen && !UIAccessibility.isReduceMotionEnabled,
                               completion: completion)
            return
        }
        let animator = UIViewPropertyAnimator(duration: 0.2, curve: .easeIn) { [weak self] in
            guard let self else { return }
            self.backdropView.alpha = 0
            self.cardView.alpha = self.style == .dialog ? 0 : 1
            self.cardView.transform = self.hiddenTransform
        }
        animator.addCompletion { [weak self] _ in
            self?.removePresentation(animated: false, completion: completion)
        }
        transitionAnimator = animator
        animator.startAnimation()
    }

    /// UIKit's completion, after our card animation and native detachment, is the sole completion boundary.
    private func removePresentation(animated: Bool, completion: @escaping () -> Void) {
        dismiss(animated: animated) { [weak self] in
            guard let self else { return }
            self.hasFinishedDismissing = true
            completion()
            self.drainDismissalCompletions()
        }
    }

    private func drainDismissalCompletions() {
        let completions = dismissalCompletions
        dismissalCompletions.removeAll()
        completions.forEach { $0() }
    }
}

private extension UPExperienceHostingController {
    /// Replacing the root value flushes the new step before measuring; the hosted view identity stays intact.
    func refreshSurveyStepContent() {
        guard let controller = contentController, case .survey(let model) = state.content,
            model.surveyContent?.type == .step, renderedSurveyStep != model.currentStep else { return }
        renderedSurveyStep = model.currentStep
        let width = cardWidth?.constant ?? view.bounds.width
        controller.rootView = UPExperienceRootView(state: state, width: width, region: .content)
        headerController?.rootView = UPExperienceRootView(state: state, width: width, region: .header)
        footerController?.rootView = UPExperienceRootView(state: state, width: width, region: .footer)
    }

    /// Survey steps retain their native 0.2-second height transition, anchored at bottom or center.
    func updateCardSize(height: CGFloat, top: CGFloat, animated: Bool) {
        let heightChanged = abs((cardHeight?.constant ?? 0) - height) > 0.5
        guard heightChanged || abs((cardTop?.constant ?? 0) - top) > 0.5 else { return }
        let shouldAnimate = animated && heightChanged && canAnimateSurveyResize
        stopResizeAtCurrentPosition()
        setHeight(cardHeight, height)
        setHeight(cardTop, top)
        guard shouldAnimate else { return }
        let animator = UIViewPropertyAnimator(duration: 0.2, curve: .easeInOut) { [weak self] in
            self?.view.layoutIfNeeded()
        }
        resizeAnimator = animator
        animator.startAnimation()
    }

    var canAnimateSurveyResize: Bool {
        guard style != .fullScreen, hasAnimatedEntrance, state.hasAppeared,
            transitionAnimator?.state != .active, !UIAccessibility.isReduceMotionEnabled,
            case .survey(let model) = state.content else { return false }
        return model.surveyContent?.type == .step
    }

    /// Retarget from rendered geometry, not the previous destination, including cancellation mid-resize.
    func stopResizeAtCurrentPosition() {
        guard resizeAnimator?.state == .active else { return }
        let frame = cardView.layer.presentation()?.frame ?? cardView.frame
        resizeAnimator?.stopAnimation(false)
        resizeAnimator?.finishAnimation(at: .current)
        resizeAnimator = nil
        setHeight(cardHeight, frame.height)
        setHeight(cardTop, frame.minY)
        UIView.performWithoutAnimation { [weak self] in self?.cardView.frame = frame }
    }
}
