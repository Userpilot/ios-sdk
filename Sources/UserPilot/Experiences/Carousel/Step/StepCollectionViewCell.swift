//
//  StepCollectionViewCell.swift
//
//
//  Created by Motasem Hamed on 02/10/2024.
//

import UIKit

internal class StepCollectionViewCell: UICollectionViewCell {

    let theScrollView: UIScrollView = {
        let view = UIScrollView()
        return view
    }()

    let contentContainerView: UIView = {
        let view = UIView()
        return view
    }()

    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        view.distribution = .fill
        view.spacing = 16
        return view
    }()

    func bindStep(_ step: Step,
                  withThemeData themeData: ThemeData,
                  andExperienceContentListener experienceContentProtocol: ExperienceContentProtocol) {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        setupUI(withThemeData: themeData)
        bindSections(step,
                     withThemeData: themeData,
                     andExperienceContentProtocol: experienceContentProtocol
        )
    }

    // unused_enumerated
    private func bindSections(_ step: Step,
                              withThemeData themeData: ThemeData,
                              andExperienceContentProtocol experienceContentProtocol: ExperienceContentProtocol) {
        // Iterate over each section of the step
        // for (_, section) in step.sections.enumerated() {
        step.sections.forEach { section in
            // Determine the type of the first line in the section
            guard let firstLine = section.lines.first else { return }

            switch firstLine.type {
            case .heading:
                let header = UPTextView()
                header.setupView(line: firstLine,
                                 style: themeData,
                                 experienceContentProtocol: experienceContentProtocol)
                header.translatesAutoresizingMaskIntoConstraints = false
                stackView.addArrangedSubview(header)
            case .paragraph:
                let paragraph = UPTextContainerView()
                paragraph.setupView(lines: section.lines,
                                    style: themeData,
                                    experienceContentProtocol: experienceContentProtocol)
                paragraph.translatesAutoresizingMaskIntoConstraints = false
                stackView.addArrangedSubview(paragraph)
            case .image:
                let image = UPImageView(frame: .zero)
                image.translatesAutoresizingMaskIntoConstraints = false
                image.heightAnchor.constraint(equalToConstant: 200).isActive = true
                image.widthAnchor.constraint(equalToConstant: 200).isActive = true
                image.backgroundColor = .brown
                image.setupView(line: firstLine)
                stackView.addArrangedSubview(image)
            case .iconText:
                let iconText = UPIconTextContainerView()
                iconText.setupView(lines: section.lines,
                                   style: themeData,
                                   experienceContentProtocol: experienceContentProtocol)
                iconText.translatesAutoresizingMaskIntoConstraints = false
                stackView.addArrangedSubview(iconText)
            default:
                break
            }

//            if (index != step.sections.count - 1) {
//                let view = UIView(frame: .zero)
//                view.backgroundColor = .green
//                view.translatesAutoresizingMaskIntoConstraints = false
//                view.heightAnchor.constraint(equalToConstant:
//            (index == step.sections.count - 1) ? 34 : 24).isActive = true
//                stackView.addArrangedSubview(view)
//            }
        }
    }

    func setupUI(withThemeData themeData: ThemeData) {
        [theScrollView, contentContainerView, stackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        contentView.addSubview(theScrollView)
        theScrollView.addSubview(contentContainerView)
        contentContainerView.addSubview(stackView)
        let safeAreaLayoutGuide = contentView.safeAreaLayoutGuide
        let contentLayoutGuide = theScrollView.contentLayoutGuide
        let frameLayoutGuide = theScrollView.frameLayoutGuide

        // constrain height of content view to height of scroll view's Frame Layout Guide
        //  with less-than-required Priority so it can get taller when the content gets taller
        let contentViewHeightConstraint = contentContainerView.heightAnchor.constraint(
            equalTo: frameLayoutGuide.heightAnchor, constant: 0.0)
        contentViewHeightConstraint.priority = .defaultLow

        NSLayoutConstraint.activate([
            // constrain scroll view Top to buttons Bottom plus 8-points "spacing"
            //  leading/trailing/bottom to the safe area
            theScrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 0.0),
            theScrollView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 0.0),
            theScrollView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: 0.0),
            theScrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: 0.0),

            // constrain all 4 sides of the content view to the scroll view's Content Layout Guide
            contentContainerView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor, constant: 0.0),
            contentContainerView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor, constant: 0.0),
            contentContainerView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor, constant: 0.0),
            contentContainerView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor, constant: 0.0),

            // constrain width of content view to width of scroll view's Frame Layout Guide
            contentContainerView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor, constant: 0.0),

            // constrain the stack view >= 8-pts from the top
            // <= minus 8-pts from the bottom
            // 40-pts leading and trailing
            // stackView.topAnchor.constraint(equalTo: contentContainerView.topAnchor, constant: 0.0),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentContainerView.bottomAnchor, constant: -8.0),
            stackView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -16),

            // activate the contentView's height constraint
            contentViewHeightConstraint
        ])

        // constrain stack view centerY to contentView centerY
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
