//
//  CarouselExperienceViewController.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 02/10/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  A custom UICollectionViewCell that represents a single step in a multi-step tutorial or guide.
//  This cell is designed to display various types of content sections such as headings, paragraphs,
//  images, and icon-text combinations in a scrollable view.
//

import UIKit

internal class StepCollectionViewCell: UICollectionViewCell {

    /// A UIScrollView that allows the content to be scrollable.
    let theScrollView: UIScrollView = {
        let view = UIScrollView()
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

    // MARK: - Override

    // Clear existing views in the stack view
    override func prepareForReuse() {
        super.prepareForReuse()
        stackView.clearViews()
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
    func bindStep(_ step: Step,
                  withTheme theme: ExperienceTheme,
                  andImageLoader imageLoader: ImageLoading) {
        // Setup UI and bind sections to the stack view
        setupUI(withTheme: theme)
        bindSections(step,
                     withTheme: theme,
                     andImageLoader: imageLoader
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
    private func bindSections(_ step: Step,
                              withTheme theme: ExperienceTheme,
                              andImageLoader imageLoader: ImageLoading) {
        // Iterate over each section of the step
        step.sections.forEach { section in
            guard let firstLine = section.lines.first else { return }
            switch firstLine.type {
            case .heading:
                let header = UPTextView()
                header.setupView(line: firstLine,
                                 theme: theme)
                stackView.addArrangedSubview(header)
            case .paragraph:
                let paragraph = UPTextContainerView()
                paragraph.setupView(lines: section.lines,
                                    theme: theme)
                stackView.addArrangedSubview(paragraph)
            case .image:
                let image = UPImageView(frame: .zero)
                image.heightAnchor.constraint(equalToConstant: 200).isActive = true
                image.setupView(line: firstLine, imageLoader: imageLoader)
                stackView.addArrangedSubview(image)
            case .iconText:
                let iconText = UPIconTextContainerView()
                iconText.setupView(lines: section.lines,
                                   theme: theme,
                                   imageLoader: imageLoader)
                stackView.addArrangedSubview(iconText)
            default:
                break
            }
        }
    }

    // MARK: - UI Setup

    /**
     Sets up the UI components of the cell with the provided theme data.
     
     - Parameters:
       - theme: The `TheExperienceThemeData` that contains styling attributes for the cell's UI components.
     */
    private func setupUI(withTheme theme: ExperienceTheme) {
        // Disable autoresizing mask constraints for custom layout
        [theScrollView, contentContainerView, stackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        // Add the scroll view and its content view to the cell's content view
        contentView.addSubview(theScrollView)
        theScrollView.addSubview(contentContainerView)
        contentContainerView.addSubview(stackView)

        // Define layout guides
        let safeAreaLayoutGuide = contentView.safeAreaLayoutGuide
        let contentLayoutGuide = theScrollView.contentLayoutGuide
        let frameLayoutGuide = theScrollView.frameLayoutGuide

        // Constraint for the content container view height
        let contentViewHeightConstraint = contentContainerView.heightAnchor.constraint(
            equalTo: frameLayoutGuide.heightAnchor, constant: 0.0)
        contentViewHeightConstraint.priority = .defaultLow

        // Activate layout constraints for the scroll view and its content
        NSLayoutConstraint.activate([
            theScrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 0.0),
            theScrollView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 0.0),
            theScrollView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: 0.0),
            theScrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: 0.0),
            contentContainerView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor, constant: 0.0),
            contentContainerView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor, constant: 0.0),
            contentContainerView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor, constant: 0.0),
            contentContainerView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor, constant: 0.0),
            contentContainerView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor, constant: 0.0),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentContainerView.bottomAnchor, constant: -8.0),
            stackView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor,
                                               constant: ThemeHandler.DefaultValues.contentMargin),
            stackView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor,
                                                constant: ThemeHandler.DefaultValues.contentMargin.negative),
            contentViewHeightConstraint
        ])

        // Conditional layout based on content alignment
        if theme.contentAlignment == .center {
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(greaterThanOrEqualTo: contentContainerView.topAnchor, constant: 0.0),
                stackView.centerYAnchor.constraint(equalTo: contentContainerView.centerYAnchor, constant: 0.0)
            ])
        } else {
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: contentContainerView.topAnchor, constant: 0.0)
            ])
        }
    }
}
