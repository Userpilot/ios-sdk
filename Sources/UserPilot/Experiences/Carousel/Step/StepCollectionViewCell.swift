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
        view.spacing = 16
        return view
    }()

    // MARK: - Binding Methods

    /**
     Binds the provided step data to the cell, setting up the UI
     and populating it with content based on the step's sections.
     
     - Parameters:
       - step: The `Step` object containing the step data to bind to the cell.
       - themeData: The `ThemeData` that contains styling attributes for the step.
       - experienceContentProtocol: A listener for handling interactions related to experience content.
       - imageLoader: An object responsible for loading images.
     */
    func bindStep(_ step: Step,
                  withThemeData themeData: ThemeData,
                  andExperienceContentListener experienceContentProtocol: ExperienceContentProtocol,
                  andImageLoader imageLoader: ImageLoading) {
        // Clear existing views in the stack view
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        // Setup UI and bind sections to the stack view
        setupUI(withThemeData: themeData)
        bindSections(step,
                     withThemeData: themeData,
                     andExperienceContentProtocol: experienceContentProtocol,
                     andImageLoader: imageLoader
        )
    }

    // MARK: - Section Binding Methods

    /**
     Binds the sections of the provided step to the stack view.
     
     - Parameters:
       - step: The `Step` object containing sections to bind to the cell.
       - themeData: The `ThemeData` containing styling attributes for the step.
       - experienceContentProtocol: A listener for handling interactions related to experience content.
       - imageLoader: An object responsible for loading images.
     */
    private func bindSections(_ step: Step,
                              withThemeData themeData: ThemeData,
                              andExperienceContentProtocol experienceContentProtocol: ExperienceContentProtocol,
                              andImageLoader imageLoader: ImageLoading) {
        // Iterate over each section of the step
        step.sections.forEach { section in
            // Determine the type of the first line in the section
            guard let firstLine = section.lines.first else { return }

            switch firstLine.type {
            case .heading:
                let header = UPTextView()
                header.setupView(line: firstLine,
                                 style: themeData,
                                 experienceContentProtocol: experienceContentProtocol)
                stackView.addArrangedSubview(header)
            case .paragraph:
                let paragraph = UPTextContainerView()
                paragraph.setupView(lines: section.lines,
                                    style: themeData,
                                    experienceContentProtocol: experienceContentProtocol)
                stackView.addArrangedSubview(paragraph)
            case .image:
                let image = UPImageView(frame: .zero)
                image.heightAnchor.constraint(equalToConstant: 200).isActive = true
                image.widthAnchor.constraint(equalToConstant: 200).isActive = true
                image.setupView(line: firstLine, imageLoader: imageLoader)
                stackView.addArrangedSubview(image)
            case .iconText:
                let iconText = UPIconTextContainerView()
                iconText.setupView(lines: section.lines,
                                   style: themeData,
                                   experienceContentProtocol: experienceContentProtocol,
                                   imageLoader: imageLoader)
                iconText.translatesAutoresizingMaskIntoConstraints = false
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
       - themeData: The `ThemeData` that contains styling attributes for the cell's UI components.
     */
    private func setupUI(withThemeData themeData: ThemeData) {
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
            stackView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -16),
            contentViewHeightConstraint
        ])

        // Conditional layout based on content alignment
        if themeData.contentAlignment == .center {
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
