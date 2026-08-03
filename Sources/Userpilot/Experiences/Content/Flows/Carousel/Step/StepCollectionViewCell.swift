//
//  CarouselExperienceViewController.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 02/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A custom UICollectionViewCell that represents a single step in a multi-step tutorial or guide.
//  This cell is designed to display various types of content sections such as headings, paragraphs,
//  images, and icon-text combinations in a scrollable view.
//

import UIKit

internal class StepCollectionViewCell: UICollectionViewCell {

    /// A UIScrollView that allows the content to be scrollable.
    ///
    /// `contentInsetAdjustmentBehavior` is pinned to `.always` rather than left at `.automatic`,
    /// whose adjustment depends on whether the axis is currently scrollable. When the action button
    /// floats, this scroll view reaches the display's bottom edge, and the home indicator's inset
    /// has to be added to the button's clearance for the content to clear both.
    let theScrollView: UIScrollView = {
        let view = UIScrollView()
        view.contentInsetAdjustmentBehavior = .always
        return view
    }()

    /// A UIView that serves as a container for all the content within the scroll view.
    let contentContainerView: UIView = {
        let view = UIView()
        return view
    }()

    /// A UIStackView that arranges its arranged subviews vertically with specified spacing.
    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        view.distribution = .fill
        view.spacing = ThemeHandler.DefaultValues.distanceBetweenSections
        return view
    }()

    let actionButton: UPButtonView = {
        let view = UPButtonView()
        return view
    }()

    var actionButtonClicked: (ButtonAction?) -> Void = { _ in }

    /// Decides whether this step's chrome renders as Liquid Glass, and therefore whether the
    /// action button floats over the scrolling content. Assigned at dequeue, before `bindStep`.
    var glassResolver: GlassCapabilityResolving?

    /// Glass background behind the step's content, when the card renders as glass. Held so it can
    /// be torn down on reuse — cells are recycled between steps.
    private var cardGlassBackground: UPGlassEffectView?

    private var storedConstraints: [NSLayoutConstraint] = []
    // MARK: - Override

    // Clear existing views in the stack view
    override func prepareForReuse() {
        super.prepareForReuse()
        stackView.clearViews()
        resetGlassState()
    }

    /// Returns every piece of glass-only state to its default, so a recycled cell cannot inherit
    /// the previous step's chrome.
    ///
    /// `bindStep` re-applies all of this for the incoming step, but only the *positive* branch of
    /// each decision — a step that resolves solid after a glass one would otherwise keep the fade,
    /// the interaction and the clearance inset that belonged to its predecessor. Insets in
    /// particular are assignments rather than increments, so this is about correctness on the
    /// solid path rather than about accumulation.
    private func resetGlassState() {
        actionButton.removeUPScrollEdgeContainer()
        theScrollView.applyUPBottomScrollEdgeEffect(allowsGlass: false)
        theScrollView.contentInset.bottom = 0
        theScrollView.verticalScrollIndicatorInsets.bottom = 0
        cardGlassBackground?.removeFromSuperview()
        cardGlassBackground = nil
    }

    // MARK: - Binding Methods

    /**
     Binds the provided step data to the cell, setting up the UI
     and populating it with content based on the step's sections.
     
     - Parameters:
       - step: The `Step` object containing the step data to bind to the cell.
       - theme: The `ExperienceTheme` that contains styling attributes for the step.
       - experienceContentProtocol: A listener for handling interactions related to experience content.
       - imageLoader: An object responsible for loading images.
     */
    func bindStep(
        _ step: Step,
        withTheme theme: ExperienceTheme,
        andImageLoader imageLoader: ImageLoading,
        withLocale isRTL: Bool
    ) {
        // Setup UI and bind sections to the stack view
        setupUI(withTheme: theme)
        bindSections(step,
                     withTheme: theme,
                     andImageLoader: imageLoader,
                     withLocale: isRTL
        )
    }

    // MARK: - Section Binding Methods

    /**
     Binds the sections of the provided step to the stack view.
     
     - Parameters:
       - step: The `Step` object containing sections to bind to the cell.
       - theme: The `ExperienceTheme` containing styling attributes for the step.
       - experienceContentProtocol: A listener for handling interactions related to experience content.
       - imageLoader: An object responsible for loading images.
     */
    private func bindSections(
        _ step: Step,
        withTheme theme: ExperienceTheme,
        andImageLoader imageLoader: ImageLoading,
        withLocale isRTL: Bool
    ) {
        // Iterate over each section of the step
        guard
            let lastSection = step.sections.last,
            let button = lastSection.lines.last,
            button.type == .button
        else {
            return
        }

        // Set up the action button with the step's button configuration and theme.
        actionButton.setupViews(
            line: button,
            action: step.buttonAction,
            theme: theme
        ) { [weak self] action in
            self?.actionButtonClicked(action)
        }

        step.sections.forEach { section in
            guard let firstLine = section.lines.first else { return }
            switch firstLine.type {
            case .heading:
                let header = UPTextView()
                header.setupView(line: firstLine, theme: theme)
                stackView.addArrangedSubview(header)

            case .paragraph:
                let paragraph = UPTextContainerView()
                paragraph.setupView(lines: section.lines, theme: theme)
                stackView.addArrangedSubview(paragraph)

            case .image:
                let size = getImageSize(for: firstLine)
                let image = UPImageView(frame: .zero)
                image.heightAnchor.constraint(equalToConstant: size.height).isActive = true
                image.setupView(line: firstLine, imageLoader: imageLoader)
                stackView.addArrangedSubview(image)

            case .iconText:
                let iconText = UPIconTextContainerView()
                iconText.setupView(lines: section.lines,
                                   theme: theme,
                                   imageLoader: imageLoader,
                                   isRTL: isRTL)
                stackView.addArrangedSubview(iconText)
            default:
                break
            }
        }
    }

    // MARK: - UI Setup

    /*
     Sets up the UI components of the cell with the provided theme data.
     
     - Parameters:
       - theme: The `TheExperienceThemeData` that contains styling attributes for the cell's UI components.
     */
    /// Paints the step card's background, as Liquid Glass or an opaque themed fill.
    ///
    /// Gated on `.fullScreen`, its own opt-in (`Config.liquidGlassFullScreen`) shared with the
    /// full-screen survey rather than following the sheet/dialog flag: a carousel step covers the
    /// whole screen and can hold dense content, so it is among the riskiest places in the SDK for
    /// glass to hurt legibility.
    ///
    /// This also determines whether the step's action button can *look* like glass. A glass
    /// button over an opaque full-screen card has nothing to refract and renders as a flat fill —
    /// measured during the iOS 26 spike, where the same button configuration reads as a plain
    /// capsule over a flat background and as glass over content.
    /// Paints the step card, through the same resolution the sheet and the dialog use.
    ///
    /// It used to build a tinted material here by hand, which meant a carousel card never saw
    /// `liquidGlassDefaultBackground` — no Apple material, and no appearance pinned from the theme's
    /// colour, so its chrome drew light glass on a dark card.
    private func applyCardBackground(theme: ExperienceTheme) {
        cardGlassBackground?.removeFromSuperview()
        cardGlassBackground = nil

        let style = glassResolver?.surfaceStyle(
            for: .fullScreen,
            themeBackground: theme.backgroundColor,
            themeBackdrop: .clear,
            themeBackdropEnabled: false,
            appearance: traitCollection.userInterfaceStyle
        ) ?? UPSurfaceStyle(
            fill: .solid(theme.backgroundColor),
            backdrop: nil,
            masksBackdrop: false,
            usesConcentricCorners: false
        )

        cardGlassBackground = UPGlassEffectView.install(style.fill, in: contentView)
    }

    /// Where the scrolling content stops.
    ///
    /// On iOS 26 with Liquid Glass the content runs all the way to the display's bottom edge and
    /// the action button **floats over it**, which is what Apple's scroll edge effect needs in
    /// order to render at all — with the content stopping above the button there is nothing
    /// passing underneath to fade, and the effect draws nothing (verified during the iOS 26 spike).
    ///
    /// The edge rather than the safe area, per Apple's guidance that content fills the display and
    /// passes behind the chrome while *controls* stay inside the safe area. The home indicator's
    /// inset is added back as content inset by `.always`, so the content still clears the button.
    ///
    /// Otherwise the content stops above the button exactly as before.
    private func scrollViewBottomConstraint() -> NSLayoutConstraint {
        guard floatsActionButton else {
            return theScrollView.bottomAnchor.constraint(
                equalTo: actionButton.topAnchor,
                constant: ThemeHandler.DefaultValues.distanceBetweenSections.negative
            )
        }
        return theScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    }

    /// Whether the action button floats over the scrolling content.
    private var floatsActionButton: Bool {
        glassResolver?.allowsGlass(for: .chrome) ?? false
    }

    /// The band at the bottom of the scroll view that the floating button occupies, and that the
    /// content therefore has to keep clear of. Zero when the button is not floating, because then
    /// the scroll view stops above it and there is nothing to clear.
    private func floatingButtonClearance(theme: ExperienceTheme) -> CGFloat {
        guard floatsActionButton else { return 0 }

        let buttonMargin = theme.isStepsProgressEnabled
            ? ThemeHandler.DefaultValues.buttonBottomMarginWithStepProgress
            : ThemeHandler.DefaultValues.buttonBottomMarginWithoutStepProgress
        return UPButtonView.buttonHeight
            + buttonMargin
            + ThemeHandler.DefaultValues.distanceBetweenSections
    }

    /// Applies the scroll edge effect and gives the content room to clear the floating button.
    ///
    /// Without the inset the last section would sit permanently underneath the button.
    private func applyFloatingActionButtonChrome(theme: ExperienceTheme) {
        actionButton.glassResolver = glassResolver
        theScrollView.applyUPBottomScrollEdgeEffect(allowsGlass: floatsActionButton)

        guard floatsActionButton else {
            theScrollView.contentInset.bottom = 0
            theScrollView.verticalScrollIndicatorInsets.bottom = 0
            actionButton.removeUPScrollEdgeContainer()
            return
        }

        // `setupUI` adds `actionButton` before `theScrollView`, so the scroll view sits on top in
        // z-order. That was harmless while the two were adjacent, but now the scroll view extends
        // underneath the button — and would swallow its taps. Raising the button both fixes
        // hit-testing and is required for it to be visible over the content at all.
        contentView.bringSubviewToFront(actionButton)

        let clearance = floatingButtonClearance(theme: theme)
        theScrollView.contentInset.bottom = clearance
        theScrollView.verticalScrollIndicatorInsets.bottom = clearance

        actionButton.registerUPScrollEdgeContainer(
            for: theScrollView,
            edge: .bottom,
            allowsGlass: true
        )
    }

    // swiftlint:disable:next function_body_length
    private func setupUI(withTheme theme: ExperienceTheme) {
        tryCatch {
            // Deactivate previously stored constraints
            NSLayoutConstraint.deactivate(storedConstraints)
            storedConstraints.removeAll()

            applyCardBackground(theme: theme)

            // Disable autoresizing mask constraints for custom layout
            [theScrollView, contentContainerView, stackView, actionButton].forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
            }

            // Add the scroll view and its content view to the cell's content view
            contentView.addSubview(actionButton)
            contentView.addSubview(theScrollView)
            theScrollView.addSubview(contentContainerView)
            contentContainerView.addSubview(stackView)

            // Define layout guides
            let safeAreaLayoutGuide = contentView.safeAreaLayoutGuide
            let contentLayoutGuide = theScrollView.contentLayoutGuide
            let frameLayoutGuide = theScrollView.frameLayoutGuide

            // Constraint for the content container view height.
            //
            // This is what makes a step that fits not scroll: at low priority it sizes the content
            // to the visible area, so `contentSize` matches the scrollable height exactly and there
            // is no range to drag through. With the floating button the visible area is the frame
            // *minus* the button's band — the frame now runs under the button, and the matching
            // `contentInset.bottom` would otherwise add that band as scrollable distance to every
            // step, however short its content.
            //
            // Measured against the scroll view's **safe area** guide, not its frame guide: the frame
            // now reaches the display's bottom edge, so the visible area is also short by the home
            // indicator's inset. Against the frame guide every step would scroll by that inset. The
            // guide is used because insets are not known when the cell is built and change on
            // rotation, so a constant computed here would be wrong twice over; only its *height* is
            // referenced, which is independent of `contentOffset`.
            let contentViewHeightConstraint = contentContainerView.heightAnchor.constraint(
                equalTo: theScrollView.safeAreaLayoutGuide.heightAnchor,
                constant: floatingButtonClearance(theme: theme).negative)
            contentViewHeightConstraint.priority = .defaultLow

            // Define layout constraints for the scroll view and its content
            storedConstraints.append(contentsOf: [
                actionButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor,
                  constant: ThemeHandler.DefaultValues.contentMargin + ThemeHandler.DefaultValues.leftRightMargin),
                actionButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor,
                constant: ThemeHandler.DefaultValues.contentMargin.negative
                                                       + ThemeHandler.DefaultValues.leftRightMargin.negative),
                actionButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor,
                                                     constant:
                  theme.isStepsProgressEnabled ? ThemeHandler.DefaultValues.buttonBottomMarginWithStepProgress.negative
                    : ThemeHandler.DefaultValues.buttonBottomMarginWithoutStepProgress.negative),
                theScrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor,
                  constant: ThemeHandler.DefaultValues.carouselContentTopMargin),
                theScrollView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor,
                  constant: ThemeHandler.DefaultValues.leftRightMargin),
                theScrollView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor,
                  constant: ThemeHandler.DefaultValues.leftRightMargin.negative),
                scrollViewBottomConstraint(),
                contentContainerView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor,
                  constant: 0.0),
                contentContainerView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor,
                  constant: 0.0),
                contentContainerView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor,
                  constant: 0.0),
                contentContainerView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor,
                  constant: 0.0),
                contentContainerView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor,
                  constant: 0.0),
                stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentContainerView.bottomAnchor,
                  constant: -8.0),
                stackView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor,
                  constant: ThemeHandler.DefaultValues.contentMargin),
                stackView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor,
                  constant: ThemeHandler.DefaultValues.contentMargin.negative),
                contentViewHeightConstraint
            ])

            // Conditional layout based on content alignment
            if theme.contentAlignment == .middle {
                storedConstraints.append(contentsOf: [
                    stackView.topAnchor.constraint(greaterThanOrEqualTo: contentContainerView.topAnchor, constant: 0.0),
                    stackView.centerYAnchor.constraint(equalTo: contentContainerView.centerYAnchor, constant: 0.0)
                ])
            } else {
                storedConstraints.append(
                    stackView.topAnchor.constraint(equalTo: contentContainerView.topAnchor, constant: 0.0)
                )
            }

            // Activate the stored constraints
            NSLayoutConstraint.activate(storedConstraints)

            applyFloatingActionButtonChrome(theme: theme)
        }
    }

}
