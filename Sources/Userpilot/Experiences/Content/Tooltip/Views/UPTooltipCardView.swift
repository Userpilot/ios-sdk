//
//  UPTooltipCardView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Renders tooltip sections with UIKit widgets and reports the content size.
//  The resolved theme controls the close button; layout and targeting types
//  own placement, the pointer, and the keyhole.

import UIKit

// MARK: - UPTooltipCardView

/// Renders one tooltip step's content and reports the size it wants.
internal final class UPTooltipCardView: UIView {

    // MARK: Callbacks

    /// Called when the action button is tapped, with whatever action the payload
    /// carried — including `nil`.
    var onAction: ((ButtonAction?) -> Void)?

    /// Called when the close button is tapped.
    var onClose: (() -> Void)?

    /// Called whenever the content's measured size changes, so the card's frame
    /// can follow it.
    var onPreferredContentSizeChanged: ((CGSize) -> Void)?

    // MARK: Properties

    /// Last size reported, so an unchanged re-measure does not re-enter layout.
    ///
    /// Not `private` only because the sizing extension lives in its own file.
    var reportedContentSize: CGSize?

    /// Space reserved for the pointer on the edge facing the target.
    ///
    /// Applied as extra content inset rather than as a frame change, so the
    /// pointer occupies layout and the text never sits on top of it.
    var pointerInset: UIEdgeInsets = .zero {
        didSet {
            guard pointerInset != oldValue else { return }
            applyContentInsets()
            setNeedsLayout()
        }
    }

    // MARK: Views

    /// Caps the content: short content hugs, tall content scrolls rather than
    /// forcing a card taller than the screen.
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        // Embedded in a card, not pinned to a safe area — auto adjustment would
        // add insets that belong to the screen, not to this content.
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()

    /// Not `private` only because the sections extension lives in its own file.
    lazy var sectionsStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = TooltipStyle.sectionSpacing
        return stack
    }()

    private lazy var closeButton: UPDismissButton = {
        let button = UPDismissButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentEdgeInsets = UIEdgeInsets(
            top: TooltipStyle.closeButtonGlyphInset,
            left: TooltipStyle.closeButtonGlyphInset,
            bottom: TooltipStyle.closeButtonGlyphInset,
            right: TooltipStyle.closeButtonGlyphInset
        )
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()

    /// Step dots for a multi-step tooltip.
    ///
    /// Outside `scrollView` on purpose: pinned to the card's bottom, the dots
    /// stay put while long content scrolls above them. This differs from
    /// `SurveyContainerView` and `NPSContainerView`, which put their dot row last
    /// inside the scrolling content stack.
    private lazy var stepsProgressView: UPStepsProgressView = {
        let progress = UPStepsProgressView()
        progress.isHidden = true
        return progress
    }()

    /// The `2 of 3` text drawn instead of the dots when the theme's progress style is `counter`.
    /// Same row, same pins.
    private lazy var counterStepsProgressView: UPStepsCounterView = {
        let progress = UPStepsCounterView()
        progress.isHidden = true
        return progress
    }()

    /// The bar drawn instead of the dots when the theme's progress style is `bar`. It lies over the card's
    /// top edge like the NPS bar, taking no row of its own; the card's mask cuts it to the rounded corners.
    private lazy var barStepsProgressView: UPStepsBarProgressView = {
        let progress = UPStepsBarProgressView()
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.isHidden = true
        return progress
    }()

    /// Whether the progress is currently hidden. The card owns this decision;
    /// nothing outside sets it, and tests verify single-step visibility through it.
    var isStepsProgressHidden: Bool {
        stepsProgressView.isHidden && counterStepsProgressView.isHidden && barStepsProgressView.isHidden
    }

    /// The row under the content when the dots or the counter show; the bar has none.
    private var stepsProgressRowView: UIView? {
        if !stepsProgressView.isHidden { return stepsProgressView }
        if !counterStepsProgressView.isHidden { return counterStepsProgressView }
        return nil
    }

    /// Content insets, held so the pointer inset can be folded in later.
    private var contentInsetConstraints: [NSLayoutConstraint] = []

    // MARK: Initialization

    init() {
        super.init(frame: .zero)
        buildHierarchy()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Binding

    /// Renders the supported tooltip content with the resolved style.
    ///
    func setupView(
        step: Step,
        style: TooltipStyle,
        isRTL: Bool,
        stepIndex: Int,
        stepCount: Int
    ) {
        let theme = style.theme
        semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        backgroundColor = theme.backgroundColor

        sectionsStackView.arrangedSubviews.forEach {
            sectionsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        bindContent(TooltipContent(step: step), theme: theme)

        closeButton.isHidden = !theme.isDismissButtonEnabled
        closeButton.setupView(theme: theme)

        // Must precede `applyContentInsets()`, which reads the progress row's
        // final hidden state to decide where the scroll view ends.
        bindStepsProgress(
            theme: theme, isRTL: isRTL, stepIndex: stepIndex, stepCount: stepCount)

        // Re-applied because the scroll view's top depends on the close button's
        // visibility and its bottom on the dots' visibility — both only known now.
        // The `pointerInset` observer cannot correct them, since a pointer-less
        // tooltip never changes that inset.
        applyContentInsets()

        setNeedsLayout()
    }

    /// Shows the step's place in its Flow: a bar when the theme's progress style is `bar`, `2 of 3` for
    /// `counter`, else dots.
    ///
    /// A one-step Flow has no sequence to display, even if the theme enables progress, so enabling
    /// progress on an account cannot silently change the size — and therefore the placement — of
    /// every single-step tooltip already live.
    private func bindStepsProgress(
        theme: ExperienceTheme,
        isRTL: Bool,
        stepIndex: Int,
        stepCount: Int
    ) {
        let progress = FlowStepsProgress(stepsCount: stepCount, stepIndex: stepIndex)
        guard theme.isStepsProgressEnabled, progress.isShown else {
            stepsProgressView.isHidden = true
            counterStepsProgressView.isHidden = true
            barStepsProgressView.isHidden = true
            return
        }
        let currentStep = progress.index

        let showsBar = theme.isStepsProgressBar
        let showsCounter = theme.isStepsProgressCounter
        stepsProgressView.isHidden = showsBar || showsCounter
        counterStepsProgressView.isHidden = !showsCounter
        barStepsProgressView.isHidden = !showsBar
        // `setCurrentStep` no-ops outside the configured range, so the count
        // has to be set first.
        if showsBar {
            barStepsProgressView.setupView(stepsCount: stepCount, theme: theme, isRTL: isRTL)
            barStepsProgressView.setCurrentStep(currentStep)
        } else if showsCounter {
            counterStepsProgressView.setupView(stepsCount: stepCount, theme: theme, isRTL: isRTL)
            counterStepsProgressView.setCurrentStep(currentStep)
        } else {
            stepsProgressView.setupView(stepsCount: stepCount, theme: theme, isRTL: isRTL)
            stepsProgressView.setCurrentStep(currentStep)
        }
    }

    // MARK: Hierarchy

    private func buildHierarchy() {
        addSubview(scrollView)
        scrollView.addSubview(sectionsStackView)
        addSubview(closeButton)
        addSubview(stepsProgressView)
        addSubview(counterStepsProgressView)
        addSubview(barStepsProgressView)

        NSLayoutConstraint.activate([
            closeButton.widthAnchor.constraint(equalToConstant: TooltipStyle.closeButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: TooltipStyle.closeButtonSize),

            // Pin the stack to the content guide so the scroll view derives its
            // content size from the content itself.
            sectionsStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            sectionsStackView.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            sectionsStackView.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            sectionsStackView.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor),

            // Width matched to the frame guide (required) so the stack lays out
            // vertically only; height matched at a lower priority so short
            // content hugs and tall content scrolls instead of stretching.
            sectionsStackView.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let heightConstraint = sectionsStackView.heightAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.heightAnchor)
        // Below text compression resistance: long paragraphs must scroll, not shrink to the viewport.
        heightConstraint.priority = .defaultLow
        heightConstraint.isActive = true

        applyContentInsets()
    }

    /// Pins the scroll view and dot row, folding in the pointer's reserved space.
    ///
    /// Rebuilt from scratch each call (old set deactivated first) so repeat
    /// calls never accumulate constraints. The dot row is only pinned while
    /// visible: a hidden one then has no say in the card's geometry, which keeps
    /// every single-step tooltip exactly as it was before the dots existed.
    private func applyContentInsets() {
        NSLayoutConstraint.deactivate(contentInsetConstraints)

        contentInsetConstraints = [
            // The close button is offset by the pointer inset too. With the
            // pointer on the top or trailing edge, a button pinned to the raw
            // bounds sits inside the pointer strip — outside the mask path, so
            // clipped and dead to hit testing.
            closeButton.topAnchor.constraint(
                equalTo: topAnchor,
                constant: TooltipStyle.closeButtonInset + pointerInset.top),
            closeButton.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -(TooltipStyle.closeButtonInset + trailingPointerInset)),

            scrollView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: TooltipStyle.contentInset + leadingPointerInset),
            scrollView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -(TooltipStyle.contentInset + trailingPointerInset))
        ]
        contentInsetConstraints += closeButtonRowConstraints() + bottomConstraints() + barConstraints()

        NSLayoutConstraint.activate(contentInsetConstraints)
    }

    /// The scroll view's bottom pin, plus the progress row's pins when it shows.
    private func bottomConstraints() -> [NSLayoutConstraint] {
        let bottomInset = TooltipStyle.contentInset + pointerInset.bottom

        guard let progressView = stepsProgressRowView else {
            return [scrollView.bottomAnchor.constraint(
                equalTo: bottomAnchor, constant: -bottomInset)]
        }

        // The row's own pins, height included, sit at 999 rather than required.
        // The card is frame-positioned and gets measured at `width == 0`, where
        // a required leading + trailing pair is unsatisfiable and UIKit would
        // log a constraint break. At 999 the solver drops them quietly for that
        // pass; at the real width all four hold.
        let progressPins = [
            progressView.heightAnchor.constraint(equalToConstant: TooltipStyle.stepsProgressHeight),
            progressView.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: TooltipStyle.contentInset + leadingPointerInset),
            progressView.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -(TooltipStyle.contentInset + trailingPointerInset)),
            progressView.bottomAnchor.constraint(
                equalTo: bottomAnchor, constant: -bottomInset)
        ]
        progressPins.forEach { $0.priority = UILayoutPriority(999) }
        // The scroll view stops above the progress, so content never scrolls
        // underneath it. Its own pin stays required.
        return progressPins + [scrollView.bottomAnchor.constraint(
            equalTo: progressView.topAnchor, constant: -TooltipStyle.sectionSpacing)]
    }

    /// The bar's pins along the card's top edge, below a top pointer, when it shows. At 999 for the same
    /// `width == 0` measuring pass as the progress row's pins.
    private func barConstraints() -> [NSLayoutConstraint] {
        guard !barStepsProgressView.isHidden else { return [] }
        let barPins = [
            barStepsProgressView.heightAnchor.constraint(equalToConstant: TooltipStyle.stepsProgressBarHeight),
            barStepsProgressView.topAnchor.constraint(equalTo: topAnchor, constant: pointerInset.top),
            barStepsProgressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingPointerInset),
            barStepsProgressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailingPointerInset)
        ]
        barPins.forEach { $0.priority = UILayoutPriority(999) }
        return barPins
    }

    /// Like the modal and slideout, the close button has its own row above the
    /// content, which keeps the content's full width.
    private func closeButtonRowConstraints() -> [NSLayoutConstraint] {
        guard !closeButton.isHidden else {
            return [scrollView.topAnchor.constraint(
                equalTo: topAnchor, constant: TooltipStyle.contentInset + pointerInset.top)]
        }
        // Keeps short content from narrowing the card past its close button. At 999 for the same
        // `width == 0` measuring pass as the progress row's pins.
        let minimumWidth = closeButton.leadingAnchor.constraint(
            greaterThanOrEqualTo: leadingAnchor,
            constant: TooltipStyle.contentInset + leadingPointerInset)
        minimumWidth.priority = UILayoutPriority(999)
        return [scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor), minimumWidth]
    }

    private var leadingPointerInset: CGFloat {
        effectiveUserInterfaceLayoutDirection == .rightToLeft ? pointerInset.right : pointerInset.left
    }

    private var trailingPointerInset: CGFloat {
        effectiveUserInterfaceLayoutDirection == .rightToLeft ? pointerInset.left : pointerInset.right
    }

    // MARK: Actions

    @objc private func closeTapped() {
        onClose?()
    }
}
