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

// swiftlint:disable file_length

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
    private var renderedNPSStep: Int?
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
    /// The width the SwiftUI roots lay out in; a sheet's card is wider, as it runs edge to edge.
    private var contentWidth: CGFloat = 0
    /// How far the card sits above its place while the keyboard is up (see `keyboardChanged`).
    private var keyboardMove: CGFloat = 0
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
        // Only the experience closes itself: no swipe-to-dismiss, and VoiceOver stays inside it.
        isModalInPresentation = true
        view.accessibilityViewIsModal = true
        // Keep screen autocapture from reporting the experience as a host-app screen.
        objc_setAssociatedObject(self, &ScreenNameTracker.untrackedScreenKey, true, .OBJC_ASSOCIATION_RETAIN)
        // The state never touches UIKit; it asks this controller to dismiss or refresh.
        state.dismiss = { [weak self] completion in self?.dismissExperience(completion: completion) }
        state.didChange = { [weak self] in self?.updateAppearance() }
        state.start()
        if style == .fullScreen, case .flow(let model) = state.content,
            model.flowContent?.type == .carousel {
            mountCarousel(model)
        } else {
            mountContent()
        }
        // Dialogs and sheets stay hidden until the entrance animation.
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
        // iOS 13–15 have no preferred-content-size signal; re-measure when the user changes text size.
        NotificationCenter.default.addObserver(
            self, selector: #selector(contentSizeCategoryChanged),
            name: UIContentSizeCategory.didChangeNotification, object: nil)
        addKeyboardDismissTap()
        // A host app's IQKeyboardManager would fight the keyboard handling below.
        ExternalKeyboardManagerCompat.disableIQKeyboardManager(for: [UPExperienceHostingController.self])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Content or theme failed to bind: close instead of showing an empty card.
        if !state.isReady {
            state.close()
            return
        }
        animateEntrance()
        state.appeared()
        // VoiceOver announces the experience and moves into it.
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
        // The card is a fixed header, a scrolling body and a fixed footer.
        view.addSubview(cardView)
        [header.view, scrollView, footer.view].forEach { cardView.addSubview($0) }
        scrollView.addSubview(content.view)
        [cardView, scrollView, header.view, content.view, footer.view].forEach {
            $0?.translatesAutoresizingMaskIntoConstraints = false
        }
        cardView.clipsToBounds = true
        // Layout margins keep a sheet's content inside the safe area; updateSize sets them.
        cardView.insetsLayoutMarginsFromSafeArea = false
        cardView.preservesSuperviewLayoutMargins = false
        cardView.layoutMargins = .zero
        scrollView.keyboardDismissMode = .interactive
        // Keyboard and safe-area space are handled in updateSize, not by automatic insets.
        scrollView.contentInsetAdjustmentBehavior = .never
        // Placeholder constants; updateSize sets the real values on every layout pass.
        cardTop = cardView.topAnchor.constraint(equalTo: view.topAnchor)
        contentTop = content.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor)
        contentHeight = content.view.heightAnchor.constraint(equalToConstant: 1)
        headerHeight = header.view.heightAnchor.constraint(equalToConstant: 1)
        footerHeight = footer.view.heightAnchor.constraint(equalToConstant: 1)
        cardHeight = cardView.heightAnchor.constraint(equalToConstant: 1)
        cardWidth = cardView.widthAnchor.constraint(equalToConstant: 1)
        let dimensions = [cardTop, contentTop, contentHeight, headerHeight, footerHeight, cardHeight, cardWidth]
        NSLayoutConstraint.activate(dimensions.compactMap { $0 })
        let margins = cardView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            // A sheet spans the whole screen width; other cards center in the safe area.
            cardView.centerXAnchor.constraint(
                equalTo: style == .bottomSheet ? view.centerXAnchor : view.safeAreaLayoutGuide.centerXAnchor),
            header.view.topAnchor.constraint(equalTo: cardView.topAnchor),
            header.view.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            header.view.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: header.view.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footer.view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            footer.view.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            footer.view.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            footer.view.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            content.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            // Body wraps at the card width, so it only ever scrolls vertically.
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
        let controller = UIHostingController(rootView: rootView(region, width: max(1, view.bounds.width)))
        objc_setAssociatedObject(controller, &ScreenNameTracker.untrackedScreenKey, true, .OBJC_ASSOCIATION_RETAIN)
        controller.view.backgroundColor = .clear
        // iOS 16+ reports its own size changes; older versions rely on the layout pass re-measuring.
        if #available(iOS 16.0, *) { controller.sizingOptions = .preferredContentSize }
        // The keyboard is handled here (`keyboardChanged`). SwiftUI's own keyboard safe area would also grow a
        // region that overlaps the keyboard, mid-rotation for example, and the card would be measured that tall.
        if #available(iOS 16.4, *) { controller.safeAreaRegions = .container }
        addChild(controller)
        return controller
    }

    private func updateAppearance() {
        guard isViewLoaded else { return }
        view.backgroundColor = style == .fullScreen ? state.backgroundColor : .clear
        backdropView.backgroundColor = style == .fullScreen ? .clear : state.backdropColor
        cardView.backgroundColor = state.backgroundColor
        cardView.layer.cornerRadius = style == .fullScreen ? 0 : state.cornerRadius
        // A sheet sits on the screen's bottom edge, so only its top corners are rounded.
        cardView.layer.maskedCorners = style == .bottomSheet
            ? [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        view.semanticContentAttribute = state.isRTL ? .forceRightToLeft : .forceLeftToRight
        // System pickers, menus and the keyboard follow the experience's background, not the device setting.
        overrideUserInterfaceStyle = state.backgroundColor.isLightColor() ? .light : .dark
        carouselController?.updateSelection()
        refreshSurveyStepContent()
        focusNewNPSStage()
        setNeedsStatusBarAppearanceUpdate()
        // Re-measure on the next pass, after SwiftUI has applied the change.
        performOn(.main) { [weak self] in
            self?.view.setNeedsLayout()
            self?.view.layoutIfNeeded()
        }
    }

    /// The body scrolls the focused field above the keyboard, and where that leaves too little room the card moves
    /// up (`keyboardAvoidance`), animated with the keyboard; both go back when it hides.
    @objc private func keyboardChanged(_ notification: Notification) {
        stopResizeAtCurrentPosition()
        let responder = view.firstResponder as? UIView
        var avoidance = KeyboardAvoidance.scroll(bottomInset: 0)
        if notification.name != UIResponder.keyboardWillHideNotification, let responder,
           let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboard = view.convert(frame, from: nil)
            // Measured where the card sits without the keyboard.
            let body = scrollView.convert(scrollView.bounds, to: view).offsetBy(dx: 0, dy: keyboardMove)
            let field = fieldBox(responder).offsetBy(dx: 0, dy: keyboardMove)
            avoidance = Self.keyboardAvoidance(
                bodyHeight: body.height, covered: body.intersection(keyboard).height,
                fieldHeight: field.height,
                cardBottom: cardView.frame.maxY - cardView.layoutMargins.bottom + keyboardMove,
                keyboardTop: keyboard.minY,
                fieldRoom: Self.fieldRoom(
                    field: field, body: body, safeTop: view.safeAreaInsets.top, fullScreen: style == .fullScreen),
                fullScreen: style == .fullScreen)
        }
        switch avoidance {
        case .scroll(let bottomInset):
            keyboardMove = 0
            scrollView.contentInset.bottom = bottomInset
        case .move(let distance, let bottomInset):
            keyboardMove = distance
            scrollView.contentInset.bottom = bottomInset
        }
        scrollView.verticalScrollIndicatorInsets.bottom = scrollView.contentInset.bottom
        updateSize(animated: false)
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int ?? 0
        let options = UIView.AnimationOptions(rawValue: UInt(curve << 16))
        UIView.animate(withDuration: duration, delay: 0, options: options) { [weak self] in
            self?.view.layoutIfNeeded()
        }
        guard let responder else { return }
        if case .move(_, let bottomInset) = avoidance, bottomInset > 0 {
            scrollToTop(fieldBox(responder))
        } else {
            scrollToVisible(fieldBox(responder))
        }
    }

    /// The focused input's box in this view.
    private func fieldBox(_ responder: UIView) -> CGRect {
        Self.fieldBox(around: responder.convert(responder.bounds, to: view), singleLine: responder is UITextField)
    }

    private func scrollToVisible(_ box: CGRect) {
        scrollView.scrollRectToVisible(view.convert(box, to: scrollView), animated: false)
    }

    /// Full-screen content that rose for the keyboard keeps the field at the body's top, where
    /// `keyboardAvoidance` counted it.
    private func scrollToTop(_ box: CGRect) {
        let top = view.convert(box, to: scrollView).minY
        let lowest = scrollView.contentSize.height + scrollView.contentInset.bottom - scrollView.bounds.height
        scrollView.setContentOffset(CGPoint(x: 0, y: min(max(0, top), max(0, lowest))), animated: false)
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

extension UPExperienceHostingController {
    @objc func contentSizeCategoryChanged() {
        if !state.isClosing { view.setNeedsLayout() }
    }

    /// VoiceOver's two-finger Z: the same close path as the visible close control, so the same
    /// dismissal is reported. Nothing happens when the experience shows no close control, or while a
    /// picker sheet is open (the sheet handles its own escape).
    override func accessibilityPerformEscape() -> Bool {
        guard state.showsCloseControl, !state.isClosing, presentedViewController == nil else { return false }
        state.userClose()
        return true
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
        // A dialog takes the previous release's 0.4 seconds to rise.
        let animator = UIViewPropertyAnimator(duration: style == .dialog ? 0.4 : 0.3, curve: .easeOut) { [weak self] in
            self?.backdropView.alpha = 1
            self?.cardView.alpha = 1
            self?.cardView.transform = .identity
        }
        transitionAnimator = animator
        animator.startAnimation()
    }

    private var hiddenTransform: CGAffineTransform {
        // Sheets slide from just below the screen edge; dialogs rise 50 points as they fade in and drop as
        // they fade out, as in the previous release.
        if style == .bottomSheet {
            return CGAffineTransform(translationX: 0, y: view.bounds.height - (cardTop?.constant ?? 0))
        }
        return CGAffineTransform(translationX: 0, y: 50)
    }

    private func dismissExperience(completion: @escaping () -> Void) {
        stopResizeAtCurrentPosition()
        // Stop entrance at its current visual position; no second animation can reverse this exit.
        if transitionAnimator?.state == .active {
            transitionAnimator?.stopAnimation(false)
            transitionAnimator?.finishAnimation(at: .current)
        }
        view.endEditing(true)
        // Full screen uses UIKit's own transition; Reduce Motion removes the card without one.
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
    /// Dismissing from the presenter removes the card and any picker sheet it presented; dismissing from
    /// the card would remove only the sheet and leave a closing card on screen.
    private func removePresentation(animated: Bool, completion: @escaping () -> Void) {
        (presentingViewController ?? self).dismiss(animated: animated) { [weak self] in
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
        // The first render isn't a step change, so focus stays where viewDidAppear put it.
        let isStepChange = renderedSurveyStep != nil
        renderedSurveyStep = model.currentStep
        let width = contentWidth > 0 ? contentWidth : view.bounds.width
        controller.rootView = rootView(.content, width: width)
        headerController?.rootView = rootView(.header, width: width)
        footerController?.rootView = rootView(.footer, width: width)
        if isStepChange { focusContent() }
    }

    /// Dialogs and sheets keep more room at their top and bottom edges than full-screen content.
    func rootView(_ region: ExperienceRenderRegion, width: CGFloat) -> UPExperienceRootView {
        UPExperienceRootView(
            state: state, width: width, region: region,
            edgeSpacing: style == .fullScreen ? UPExperienceLayout.spacing : UPExperienceLayout.cardEdgeSpacing,
            // A sheet keeps its content inside the safe area (`updateSize`); its width changes with these, so a new
            // root picks them up.
            sideInsets: style == .bottomSheet
                ? UIEdgeInsets(top: 0, left: view.safeAreaInsets.left, bottom: 0, right: view.safeAreaInsets.right)
                : .zero)
    }

    func focusNewNPSStage() {
        guard case .nps = state.content, renderedNPSStep != state.npsStep else { return }
        let isStageChange = renderedNPSStep != nil
        renderedNPSStep = state.npsStep
        if isStageChange { focusContent() }
    }

    /// After SwiftUI draws the new step, VoiceOver moves to it instead of staying on an element that has gone.
    func focusContent() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.state.isClosing else { return }
            UIAccessibility.post(notification: .layoutChanged, argument: self.contentController?.view)
        }
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

    /// View bounds and safe area belong to this window/scene; never size against UIScreen.main.
    func updateSize(animated: Bool = true) {
        guard !state.isClosing, let controller = contentController, view.bounds.width > 0 else { return }
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let width = cardContentWidth(safe)
        let availableHeight = max(1, safe.height)
        // A sheet runs edge to edge and under the home indicator, as it did before the SwiftUI renderer;
        // its content stays in the safe area. Moved up for the keyboard, it grows by that distance, so its
        // background still reaches the screen's bottom edge behind the keyboard, as in the previous release.
        let bottomInset = style == .bottomSheet ? view.safeAreaInsets.bottom + keyboardMove : 0
        if style == .bottomSheet {
            cardView.layoutMargins = UIEdgeInsets(
                top: 0, left: view.safeAreaInsets.left, bottom: bottomInset, right: view.safeAreaInsets.right)
        }
        setHeight(cardWidth, style == .bottomSheet ? view.bounds.width : width)
        let widthChanged = abs(contentWidth - width) > 0.5
        // A new width (rotation, split view) re-wraps text, so the SwiftUI roots get the new width.
        if widthChanged {
            contentWidth = width
            controller.rootView = rootView(.content, width: width)
            headerController?.rootView = rootView(.header, width: width)
            footerController?.rootView = rootView(.footer, width: width)
        }
        let proposal = CGSize(width: width, height: .greatestFiniteMagnitude)
        let contentSize = max(1, ceil(controller.sizeThatFits(in: proposal).height))
        let headerSize = ceil(headerController?.sizeThatFits(in: proposal).height ?? 0)
        let footerSize = ceil(footerController?.sizeThatFits(in: proposal).height ?? 0)
        let total = contentSize + headerSize + footerSize
        // Dialogs and sheets hug their content, up to 80% of the space; beyond that the body scrolls.
        let height = style == .fullScreen
            ? availableHeight : min(total, availableHeight * UPExperienceLayout.cardMaxHeightFraction)
        setHeight(contentHeight, contentSize)
        setHeight(headerHeight, headerSize)
        setHeight(footerHeight, footerSize)
        // Leftover space positions the body per the theme's vertical alignment.
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
        updateCardSize(height: height + bottomInset, top: top - keyboardMove, animated: animated && !widthChanged)
    }

    func cardContentWidth(_ safe: CGRect) -> CGFloat {
        switch style {
        // Dialogs are narrower in landscape.
        case .dialog: return safe.width * (safe.width > safe.height ? 0.7 : 0.9)
        case .bottomSheet, .fullScreen: return safe.width
        }
    }

    func setHeight(_ constraint: NSLayoutConstraint?, _ value: CGFloat) {
        // Ignore sub-point changes so measuring can't trigger an endless layout loop.
        if abs((constraint?.constant ?? 0) - value) > 0.5 { constraint?.constant = value }
    }
}

// MARK: - Keyboard avoidance

extension UPExperienceHostingController {
    enum KeyboardAvoidance: Equatable {
        /// The body scrolls the field into view, with the part the keyboard covers added under its content.
        case scroll(bottomInset: CGFloat)
        /// The whole card moves up this far, the field staying below the top bars. A card's content ends on the
        /// keyboard; full-screen content keeps scrolling with `bottomInset` added and rises only by what is missing.
        case move(distance: CGFloat, bottomInset: CGFloat)
    }

    // swiftlint:disable function_parameter_count
    /// Scroll while the body's uncovered part holds the focused field with the usual spacing to spare. Otherwise
    /// full-screen content keeps its footer under the keyboard, as when it scrolls: the body scrolls the field to its
    /// top and the content rises by the space still missing. A card moves up until its content's bottom
    /// (`cardBottom`) meets the keyboard. Neither rises further than `fieldRoom`, which leaves the field the usual
    /// spacing below the top bars.
    static func keyboardAvoidance(
        bodyHeight: CGFloat, covered: CGFloat, fieldHeight: CGFloat, cardBottom: CGFloat, keyboardTop: CGFloat,
        fieldRoom: CGFloat, fullScreen: Bool
    ) -> KeyboardAvoidance {
        let missing = covered + fieldHeight + UPExperienceLayout.spacing - bodyHeight
        if missing <= 0 { return .scroll(bottomInset: covered) }
        if fullScreen { return .move(distance: max(0, min(missing, fieldRoom)), bottomInset: covered) }
        return .move(distance: max(0, min(cardBottom - keyboardTop, fieldRoom)), bottomInset: 0)
    }
    // swiftlint:enable function_parameter_count

    /// How far the card can rise before the field, once the body has scrolled it into view, comes within the usual
    /// spacing of the top bars. A full-screen body scrolls the field to its top; a card's body scrolls a field partly
    /// out of view back in.
    static func fieldRoom(field: CGRect, body: CGRect, safeTop: CGFloat, fullScreen: Bool) -> CGFloat {
        let settledTop = fullScreen
            ? body.minY : min(max(field.minY, body.minY), max(body.minY, body.maxY - field.height))
        return settledTop - safeTop - UPExperienceLayout.spacing
    }

    /// A single-line field's text sits inside a padded box at least `inputMinHeight` tall; that box is what has
    /// to clear the keyboard. A multiline field is its own box.
    static func fieldBox(around frame: CGRect, singleLine: Bool) -> CGRect {
        guard singleLine else { return frame }
        let height = max(UPExperienceLayout.inputMinHeight, frame.height + 2 * UPExperienceLayout.inputPadding)
        return frame.insetBy(dx: 0, dy: -(height - frame.height) / 2)
    }
}

// MARK: - Closing the keyboard

extension UPExperienceHostingController: UIGestureRecognizerDelegate {
    /// A tap outside a text input closes the keyboard: on the backdrop, the card, its content or empty space, in
    /// every experience. The tap still reaches what it landed on.
    func addKeyboardDismissTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapOutsideTextInput))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesEnded = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    @objc func tapOutsideTextInput() { view.endEditing(true) }

    /// Only while something in the experience is being edited.
    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool { view.firstResponder != nil }

    /// A tap on a text input focuses it as usual, without closing the keyboard first. The focused field's padded box
    /// (`fieldBox`) counts as the field.
    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if Self.isTextInput(touch.view) { return false }
        guard let responder = view.firstResponder as? UIView else { return true }
        return !fieldBox(responder).contains(touch.location(in: view))
    }

    /// Buttons, choices, links, menus and scrolling keep their own gestures.
    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }

    /// A text field, or an editable text view such as the open-text box, or a view inside one. Read-only link text
    /// is not an input.
    static func isTextInput(_ view: UIView?) -> Bool {
        guard let view else { return false }
        return sequence(first: view, next: { $0.superview }).contains {
            $0 is UITextField || ($0 as? UITextView)?.isEditable == true
        }
    }
}
