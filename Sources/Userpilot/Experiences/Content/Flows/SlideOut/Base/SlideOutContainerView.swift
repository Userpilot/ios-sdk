//
//  SlideOutContainerView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 20/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  The `SlideOutContainerView` is a custom view component designed to provide a slide-out interface
//  that contains a dismiss button at the top, scrollable content in the center, and an action button
//  at the bottom. It allows for dynamic content binding through sections, and is highly customizable
//  via the provided theme data. The view is responsible for handling user interactions such as
//  dismissing the view and triggering actions, which are passed to the associated delegate.
//

import Foundation
import UIKit

internal final class SlideOutContainerView: UIView {

    // MARK: - UI Components

    /// A container for the dismiss button, with a fixed height.
    private lazy var buttonDismissContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize + 10).isActive = true
        return view
    }()

    /// The action button at the bottom of the view.
    private lazy var actionButton: UPButtonView = {
        let button = UPButtonView()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: UPButtonView.buttonHeight).isActive = true
        return button
    }()

    private lazy var spaceView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.heightAnchor.constraint(equalToConstant: 0).isActive = true
        return view
    }()

    /// A Flow step's dots under the action button. Hidden, it takes no space in the stack.
    private lazy var stepsProgressView: UPStepsProgressView = {
        let progressView = UPStepsProgressView()
        progressView.isHidden = true
        progressView.heightAnchor.constraint(equalToConstant: Constants.Theme.stepsProgressDotsHeight).isActive = true
        return progressView
    }()

    /// A Flow step's `2 of 3` under the action button, shown instead of the dots for a `counter` style.
    private lazy var counterStepsProgressView: UPStepsCounterView = {
        let progressView = UPStepsCounterView()
        progressView.isHidden = true
        progressView.heightAnchor.constraint(equalToConstant: Constants.Theme.stepsProgressDotsHeight).isActive = true
        return progressView
    }()

    /// A Flow step's bar for a `bar` style, over the card's top edge like the NPS bar; the card clips its corners.
    private lazy var barStepsProgressView: UPStepsBarProgressView = {
        let progressView = UPStepsBarProgressView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true
        progressView.heightAnchor.constraint(equalToConstant: Constants.Theme.stepsProgressBarHeight).isActive = true
        return progressView
    }()

    /// How far below the card's top edge the host lays this view out (the dialog's content margin), for the bar.
    var cardTopInset: CGFloat = 0 {
        didSet { barStepsProgressTopConstraint?.constant = -cardTopInset }
    }

    /// A vertical stack view to manage the arrangement of UI elements (dismiss button, content, action button,
    /// a Flow step's dots or counter).
    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            buttonDismissContainerView, scrollView, spaceView, actionButton,
            stepsProgressView, counterStepsProgressView])
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.spacing = Constants.Theme.distanceBetweenSections
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    /// A scroll view to allow the central content to be scrollable.
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    /// A container view that holds the scrollable content inside the scroll view.
    private let contentContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// A vertical stack view for managing dynamically added sections.
    private let stepSectionsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = Constants.Theme.distanceBetweenSections
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private weak var slideOutContainerViewDelegate: SlideOutContainerViewDelegate?

    private var scrollViewHeightConstraint: NSLayoutConstraint?
    private var barStepsProgressTopConstraint: NSLayoutConstraint?
    private var storedConstraints: [NSLayoutConstraint] = []

    // MARK: - Initial Setup

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - UI Setup

    /**
     Reset height fo Scroll View on screen rotation.
     */
    func resetContentHeight(_ size: CGSize) {
        if let scrollViewHeightConstraint {
            NSLayoutConstraint.deactivate([scrollViewHeightConstraint])
        }
        scrollViewHeightConstraint = scrollView.heightAnchor.constraint(
            lessThanOrEqualToConstant:
                screenHeight * Constants.Theme.slideOutContentMaxHeightPercentage)
        scrollViewHeightConstraint?.isActive = true
        self.layoutIfNeeded()
    }

    /**
     Sets up the layout and constraints for the view components.
     */
    private func setupUI() {
        tryCatch {
            // Deactivate and clear previously stored constraints
            NSLayoutConstraint.deactivate(storedConstraints)
            storedConstraints.removeAll()

            // Set scroll view height
            if let scrollViewHeightConstraint {
                NSLayoutConstraint.deactivate([scrollViewHeightConstraint])
            }
            scrollViewHeightConstraint = scrollView.heightAnchor.constraint(
                lessThanOrEqualToConstant:
                    screenHeight * Constants.Theme.slideOutContentMaxHeightPercentage)
            scrollViewHeightConstraint?.isActive = true

            // Disable autoresizing masks for custom layout
            [scrollView, contentContainerView, stepSectionsStackView, buttonDismissContainerView,
             actionButton, contentStackView].forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
            }

            // Add subviews
            addSubview(contentStackView)
            addSubview(barStepsProgressView)
            scrollView.addSubview(contentContainerView)
            contentContainerView.addSubview(stepSectionsStackView)

            let safeAreaLayoutGuide = safeAreaLayoutGuide
            let frameLayoutGuide = scrollView.frameLayoutGuide

            // Constraint for the content container view height
            let contentViewHeightConstraint = contentContainerView.heightAnchor.constraint(
                equalTo: frameLayoutGuide.heightAnchor, constant: 0.0)
            contentViewHeightConstraint.priority = .defaultLow

            // Define constraints
            storedConstraints.append(contentsOf: stepsProgressBarConstraints() + [
                // Constraints for the content stack view (full-screen with padding)
                contentStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                contentStackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
                contentStackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
                contentStackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

                // Scroll view constraints
                contentContainerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                contentContainerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                contentContainerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                contentContainerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                contentContainerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

                // Step section stack view inside content container
                stepSectionsStackView.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
                stepSectionsStackView.leadingAnchor.constraint(
                    equalTo: contentContainerView.leadingAnchor,
                    constant: 0),
                stepSectionsStackView.trailingAnchor.constraint(
                    equalTo: contentContainerView.trailingAnchor,
                    constant: 0),
                stepSectionsStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentContainerView.bottomAnchor),

                // Content container view height constraint
                contentViewHeightConstraint
            ])

            // Activate the stored constraints
            NSLayoutConstraint.activate(storedConstraints)
        }
    }

    // MARK: - Binding Methods

    /**
     Binds the step data to the view and sets up the UI based on the provided theme and content.

     - Parameters:
       - step: The `Step` object containing the step data.
       - theme: The `ExperienceTheme` containing styling attributes.
       - slideOutContainerViewDelegate: Delegate for handling actions within the view.
       - imageLoader: Object responsible for loading images.
     */
    func bindStep(
        _ step: Step,
        withTheme theme: ExperienceTheme,
        andSlideOutContainerViewDelegate slideOutContainerViewDelegate: SlideOutContainerViewDelegate,
        andImageLoader imageLoader: ImageLoading,
        withLocal isRTL: Bool
    ) {
        self.slideOutContainerViewDelegate = slideOutContainerViewDelegate

        setupDismissButton(theme)
        setupActionButton(step, theme)
        bindSections(step,
                     withTheme: theme,
                     andImageLoader: imageLoader,
                     withLocale: isRTL)
    }

    // MARK: - Component Setup

    /**
     Configures the dismiss button based on the theme data.
     
     - Parameter theme: The `ExperienceTheme` used to style the dismiss button.
     */
    private func setupDismissButton(_ theme: ExperienceTheme) {
        if theme.isDismissButtonEnabled {
            let buttonDismiss = UPDismissButton()
            buttonDismiss.setupView(theme: theme)
            buttonDismissContainerView.addSubview(buttonDismiss)
            buttonDismiss.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                buttonDismiss.bottomAnchor.constraint(equalTo: buttonDismissContainerView.bottomAnchor),
                buttonDismiss.trailingAnchor.constraint(
                    equalTo: buttonDismissContainerView.trailingAnchor,
                    constant: Constants.Theme.dismissButtonMargin),
                buttonDismiss.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize),
                buttonDismiss.widthAnchor.constraint(equalToConstant: UPDismissButton.buttonSize)
            ])

            buttonDismiss.addTarget(self, action: #selector(buttonDismissClicked), for: .touchUpInside)
        } else {
            buttonDismissContainerView.isHidden = true
        }
    }

    /**
     Configures the action button based on the step's data.
     
     - Parameters:
       - step: The `Step` object containing step data.
       - theme: The `ExperienceTheme` used to style the action button.
     */
    private func setupActionButton(
        _ step: Step,
        _ theme: ExperienceTheme
    ) {
        guard let lastSection = step.sections.last,
              let button = lastSection.lines.last, button.type == .button else { return }

        // Set up action button with appropriate action and style
        actionButton.setupViews(line: button, action: step.buttonAction, theme: theme) { [weak self] action in
            self?.slideOutContainerViewDelegate?.onAction(action)
        }
    }

    // MARK: - Section Binding Methods

    /**
     Binds the sections of the provided step to the stack view.
     
     - Parameters:
       - step: The `Step` object containing section data.
       - theme: The `ExperienceTheme` containing styling attributes.
       - imageLoader: The `ImageLoading` instance to handle image loading.
     */
    private func bindSections(
        _ step: Step,
        withTheme theme: ExperienceTheme,
        andImageLoader imageLoader: ImageLoading,
        withLocale isRTL: Bool
    ) {
        step.sections.forEach { section in
            guard let firstLine = section.lines.first else { return }

            switch firstLine.type {
            case .heading:
                let header = UPTextView()
                header.setupView(line: firstLine, theme: theme)
                stepSectionsStackView.addArrangedSubview(header)

            case .paragraph:
                let paragraph = UPTextContainerView()
                paragraph.setupView(lines: section.lines, theme: theme)
                stepSectionsStackView.addArrangedSubview(paragraph)

            case .image:
                let size = getImageSize(for: firstLine)
                let image = UPImageView(frame: .zero)
                image.heightAnchor.constraint(equalToConstant: size.height).isActive = true
                image.setupView(line: firstLine, imageLoader: imageLoader)
                stepSectionsStackView.addArrangedSubview(image)

            case .iconText:
                let iconText = UPIconTextContainerView()
                iconText.setupView(lines: section.lines,
                                   theme: theme,
                                   imageLoader: imageLoader,
                                   isRTL: isRTL)
                stepSectionsStackView.addArrangedSubview(iconText)
            default:
                break
            }
        }
    }

    // MARK: - Action Methods

    @objc private func buttonDismissClicked() {
        slideOutContainerViewDelegate?.onClose()
    }
}

// MARK: - Flow Steps Progress

extension SlideOutContainerView {

    /**
     Shows a Flow step's progress after `bindStep`: a bar along the top edge when its theme's style is `bar`,
     `2 of 3` under the action button for `counter`, else dots there, at the step `FlowStepsProgress` lights.
     Standalone slideouts never call this, so they show none.

     - Parameters:
       - stepsCount: The whole Flow's `steps_count`.
       - stepIndex: The step's 0-based place in the Flow (`position - 1`).
       - theme: The step's merged theme, the one passed to `bindStep`.
       - isRTL: Whether the layout is right-to-left.
     */
    func bindStepsProgress(
        stepsCount: Int,
        stepIndex: Int,
        theme: ExperienceTheme,
        isRTL: Bool
    ) {
        let progress = FlowStepsProgress(stepsCount: stepsCount, stepIndex: stepIndex)
        guard theme.isStepsProgressEnabled, progress.isShown else { return }
        let shownIndex = progress.index
        if theme.isStepsProgressBar {
            barStepsProgressView.isHidden = false
            barStepsProgressView.setupView(stepsCount: stepsCount, theme: theme, isRTL: isRTL)
            barStepsProgressView.setCurrentStep(shownIndex)
        } else if theme.isStepsProgressCounter {
            counterStepsProgressView.isHidden = false
            counterStepsProgressView.setupView(stepsCount: stepsCount, theme: theme, isRTL: isRTL)
            counterStepsProgressView.setCurrentStep(shownIndex)
        } else {
            stepsProgressView.isHidden = false
            stepsProgressView.setupView(stepsCount: stepsCount, theme: theme, isRTL: isRTL)
            stepsProgressView.setCurrentStep(shownIndex)
        }
    }

    /// Pins the bar over the card's top edge, past the host's content margins.
    private func stepsProgressBarConstraints() -> [NSLayoutConstraint] {
        let margin = Constants.Theme.contentMargin
        let topConstraint = barStepsProgressView.topAnchor.constraint(equalTo: topAnchor, constant: -cardTopInset)
        barStepsProgressTopConstraint = topConstraint
        return [topConstraint,
                barStepsProgressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -margin),
                barStepsProgressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: margin)]
    }
}
