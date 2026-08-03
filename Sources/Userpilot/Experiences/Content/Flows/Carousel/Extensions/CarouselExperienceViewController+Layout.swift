//
//  CarouselExperienceViewController+Layout.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The carousel's view hierarchy and constraints — what `CarouselExperienceViewController.xib` used
//  to declare, plus the steps' collection view layout, which the XIB described and then had
//  overwritten on every bind.
//
//  Measurements live in `ThemeHandler.DefaultValues` with the rest of the SDK's spacing.
//

import UIKit

// MARK: - Steps layout

extension CarouselExperienceViewController {

    /// The steps layout: one full-width page per step, no gaps.
    ///
    /// `setupLocale()` builds a fresh one once the content's locale is known, so RTL flows flip.
    /// Both callers come here, so the configuration exists once.
    internal static func makeStepsLayout() -> UPCollectionViewLayout {
        let layout = UPCollectionViewLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        return layout
    }
}

// MARK: - View hierarchy

extension CarouselExperienceViewController {

    /// Adds the subviews and pins them, in place of what the XIB used to declare.
    ///
    /// Insertion order is the z-order the XIB had: the steps go in first, so the dismiss button
    /// and the step progress bar draw over the step content.
    internal func buildViewHierarchy() {
        view.backgroundColor = .clear

        collectionView.dataSource = self
        collectionView.delegate = self
        buttonDismiss.addTarget(self, action: #selector(onCloseButtonClicked(_:)), for: .touchUpInside)

        view.addSubview(collectionView)
        view.addSubview(buttonDismissContainerView)
        buttonDismissContainerView.addSubview(buttonDismiss)
        view.addSubview(viewStepsProgress)

        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            // Edge to edge, ignoring the safe area: a step paints its own card full-bleed and
            // insets its content itself.
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            buttonDismissContainerView.topAnchor.constraint(
                equalTo: safeArea.topAnchor,
                constant: ThemeHandler.DefaultValues.dismissRowTopMargin),
            buttonDismissContainerView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            buttonDismissContainerView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            buttonDismissContainerView.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize),

            buttonDismiss.topAnchor.constraint(equalTo: buttonDismissContainerView.topAnchor),
            buttonDismiss.trailingAnchor.constraint(
                equalTo: buttonDismissContainerView.trailingAnchor,
                constant: ThemeHandler.DefaultValues.dismissButtonMargin.negative),
            buttonDismiss.widthAnchor.constraint(equalToConstant: UPDismissButton.buttonSize),
            buttonDismiss.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize),

            viewStepsProgress.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            viewStepsProgress.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            viewStepsProgress.bottomAnchor.constraint(
                equalTo: safeArea.bottomAnchor,
                constant: ThemeHandler.DefaultValues.stepsProgressBottomMargin.negative),
            viewStepsProgress.heightAnchor.constraint(
                equalToConstant: ThemeHandler.DefaultValues.stepsProgressHeight)
        ])
    }
}
