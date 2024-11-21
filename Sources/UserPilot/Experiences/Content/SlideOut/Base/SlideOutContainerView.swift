//
//  SlideOutContainerView.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 20/10/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  The `SlideOutContainerView` is a custom view component designed to provide a slide-out interface
//  that contains a dismiss button at the top, scrollable content in the center, and an action button
//  at the bottom. It allows for dynamic content binding through sections, and is highly customizable
//  via the provided theme data. The view is responsible for handling user interactions such as
//  dismissing the view and triggering actions, which are passed to the associated delegate.
//

import Foundation
import UIKit

internal class SlideOutContainerView: UIView {

    // MARK: - UI Components

    /// A container for the dismiss button, with a fixed height.
    private lazy var buttonDismissContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: UPCloseButton.buttonSize).isActive = true
        return view
    }()

    /// The dismiss button, which triggers the closing of the slide-out container.
    private var buttonDismiss: UPCloseButton?

    /// The action button at the bottom of the view.
    private lazy var actionButton: UPButtonView = {
        let button = UPButtonView()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: UPButtonView.buttonHeight).isActive = true
        return button
    }()

    /// A vertical stack view to manage the arrangement of UI elements (dismiss button, content, action button).
    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [buttonDismissContainerView, scrollView, actionButton])
        stackView.axis = .vertical
        stackView.spacing = ThemeHandler.DefaultValues.distanceBetweenSections
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    /// A scroll view to allow the central content to be scrollable.
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(
            lessThanOrEqualToConstant:
            UIScreen.main.bounds.height * ThemeHandler.DefaultValues.slideOutContentMaxHeightPercentage)
        .isActive = true
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
        stackView.spacing = ThemeHandler.DefaultValues.distanceBetweenSections
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    weak var slideOutContainerViewDelegate: SlideOutContainerViewDelegate?

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
     Sets up the layout and constraints for the view components.
     */
    private func setupUI() {
        // Disable autoresizing masks for custom layout
        [scrollView, contentContainerView, stepSectionsStackView, buttonDismissContainerView,
         actionButton, contentStackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        addSubview(contentStackView)
        scrollView.addSubview(contentContainerView)
        contentContainerView.addSubview(stepSectionsStackView)

        let safeAreaLayoutGuide = safeAreaLayoutGuide
        // let contentLayoutGuide = scrollView.contentLayoutGuide
        let frameLayoutGuide = scrollView.frameLayoutGuide

        // Constraint for the content container view height
        let contentViewHeightConstraint = contentContainerView.heightAnchor.constraint(
            equalTo: frameLayoutGuide.heightAnchor, constant: 0.0)
        contentViewHeightConstraint.priority = .defaultLow

        // Constraints for the content stack view (full-screen with padding)
        NSLayoutConstraint.activate([
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
                constant: ThemeHandler.DefaultValues.contentMargin),
            stepSectionsStackView.trailingAnchor.constraint(
                equalTo: contentContainerView.trailingAnchor,
                constant: ThemeHandler.DefaultValues.contentMargin.negative),
            stepSectionsStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentContainerView.bottomAnchor),
            contentViewHeightConstraint
        ])
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
    func bindStep(_ step: Step,
                  withTheme theme: ExperienceTheme,
                  andSlideOutContainerViewDelegate slideOutContainerViewDelegate: SlideOutContainerViewDelegate,
                  andImageLoader imageLoader: ImageLoading) {
        self.slideOutContainerViewDelegate = slideOutContainerViewDelegate

        setupDismissButton(theme)
        setupActionButton(step, theme)
        bindSections(step, withTheme: theme, andImageLoader: imageLoader)
    }

    // MARK: - Component Setup

    /**
     Configures the dismiss button based on the theme data.
     
     - Parameter theme: The `ExperienceTheme` used to style the dismiss button.
     */
    private func setupDismissButton(_ theme: ExperienceTheme) {
        if theme.isDismissButtonEnabled {
            buttonDismiss = UPCloseButton()
            buttonDismiss?.setupView(theme: theme)
            buttonDismissContainerView.addSubview(buttonDismiss!)
            buttonDismiss?.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                buttonDismiss!.topAnchor.constraint(equalTo: buttonDismissContainerView.topAnchor),
                buttonDismiss!.trailingAnchor.constraint(equalTo: buttonDismissContainerView.trailingAnchor),
                buttonDismiss!.heightAnchor.constraint(equalToConstant: UPCloseButton.buttonSize),
                buttonDismiss!.widthAnchor.constraint(equalToConstant: UPCloseButton.buttonSize)
            ])

            buttonDismiss?.addTarget(self, action: #selector(buttonDismissClicked), for: .touchUpInside)
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
    private func setupActionButton(_ step: Step, _ theme: ExperienceTheme) {
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
    private func bindSections(_ step: Step,
                              withTheme theme: ExperienceTheme,
                              andImageLoader imageLoader: ImageLoading) {
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
                                   imageLoader: imageLoader)
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
