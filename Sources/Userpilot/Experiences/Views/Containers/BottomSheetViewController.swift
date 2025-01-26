//
//  BottomSheetViewController.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A customizable bottom sheet view controller that provides a smooth, dimmed, draggable
//  bottom sheet experience. It allows adding dynamic content, background customization,
//  and integrates gesture recognition for dismissing the sheet via a drag or tap action.
//

import Foundation
import UIKit

internal class BottomSheetViewController: UIViewController {

    // MARK: - UI Components

    /// Main bottom sheet container view with a rounded top and clipped corners
    private lazy var mainContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = ThemeHandler.DefaultValues.slideOutCornerRadius
        view.clipsToBounds = true
        return view
    }()

    /// View to hold dynamic content for the bottom sheet
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Top bar view for dragging the bottom sheet to dismiss
    private lazy var topBarView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Dimmed background view that appears behind the bottom sheet
    private lazy var dimmedView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alpha = 0
        return view
    }()

    // MARK: - Properties

    /// Minimum vertical drag height required to dismiss the bottom sheet
    private let minDismissiblePanHeight: CGFloat = 20
    /// Minimum spacing between the top edge of the view and the bottom sheet
    private var minTopSpacing: CGFloat = 100

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        // setupGestures()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animatePresent()
    }
}

// MARK: - Setup Views

private extension BottomSheetViewController {

    /// Set up the views for the bottom sheet and dimmed background
    func setupViews() {
        view.backgroundColor = .clear

        // Add dimmed background view
        view.addSubview(dimmedView)
        NSLayoutConstraint.activate([
            dimmedView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimmedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Add bottom sheet container view
        view.addSubview(mainContainerView)
        NSLayoutConstraint.activate([
            mainContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mainContainerView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: minTopSpacing)
        ])

        // Add top draggable bar view
        mainContainerView.addSubview(topBarView)
        NSLayoutConstraint.activate([
            topBarView.topAnchor.constraint(equalTo: mainContainerView.topAnchor),
            topBarView.leadingAnchor.constraint(equalTo: mainContainerView.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: mainContainerView.trailingAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: 20)
        ])

        // Add content view
        mainContainerView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(
                equalTo: mainContainerView.leadingAnchor,
                constant: ThemeHandler.DefaultValues.contentMargin),
            contentView.trailingAnchor.constraint(
                equalTo: mainContainerView.trailingAnchor,
                constant: ThemeHandler.DefaultValues.contentMargin.negative),
            contentView.topAnchor.constraint(equalTo: topBarView.bottomAnchor),
            contentView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: ThemeHandler.DefaultValues.contentBottomMargin.negative)
        ])

        /// prepare the view for slide in animation
        dimmedView.alpha = 0
        mainContainerView.transform = CGAffineTransform(translationX: 0, y: view.frame.height)
    }
}

// MARK: - Setup Gestures

private extension BottomSheetViewController {

    /// Set up tap and pan gestures for dismissing the bottom sheet
    func setupGestures() {
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapDimmedView))
//        dimmedView.addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false
        topBarView.addGestureRecognizer(panGesture)
    }

    /// Handle tap gesture on the dimmed view to dismiss the bottom sheet
    @objc func handleTapDimmedView() {
        dismissBottomSheet()
    }

    /// Handle pan gesture to track dragging and dismiss the bottom sheet when necessary
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let isDraggingDown = translation.y > 0
        guard isDraggingDown else { return }

        let pannedHeight = translation.y
        let currentY = view.frame.height - mainContainerView.frame.height

        switch gesture.state {
        case .changed:
            mainContainerView.frame.origin.y = currentY + pannedHeight
        case .ended:
            if pannedHeight >= minDismissiblePanHeight {
                dismissBottomSheet()
            } else {
                mainContainerView.frame.origin.y = currentY
            }
        default:
            break
        }
    }
}

// MARK: - Animations

internal extension BottomSheetViewController {

    /// Animate the presentation of the bottom sheet
    func animatePresent() {
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.mainContainerView.transform = .identity
        }
        UIView.animate(withDuration: 0.4) { [weak self] in
            self?.dimmedView.alpha = 1
        }
    }

    /// Dismiss the bottom sheet with an animation
    func dismissBottomSheet(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.dimmedView.alpha = 0
            self?.mainContainerView.transform = CGAffineTransform(
                translationX: 0, y: self?.mainContainerView.frame.height ?? 0)
        }, completion: { [weak self] _ in
            self?.dismiss(animated: false, completion: completion)
        })
    }
}

// MARK: - Public APIs

internal extension BottomSheetViewController {

    /// Set the dynamic content for the bottom sheet
    func setContent(_ content: UIView) {
        contentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            content.topAnchor.constraint(equalTo: contentView.topAnchor),
            content.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        view.layoutIfNeeded()
    }

    /// Customize the background color of the bottom sheet for `ExperienceTheme`
    func setBackgroundColor(_ theme: ExperienceTheme) {
        mainContainerView.backgroundColor = theme.backgroundColor
        dimmedView.isHidden = !theme.backdropEnabled
        if theme.backdropEnabled {
            dimmedView.backgroundColor = theme.backdropBackground
        }
    }

    /// Customize the background color of the bottom sheet for `SurveyTheme`
    func setBackgroundColor(_ theme: SurveyTheme) {
        mainContainerView.backgroundColor = theme.backgroundColor
        dimmedView.isHidden = !theme.backdropEnabled
        if theme.backdropEnabled {
            dimmedView.backgroundColor = theme.backdropBackground
        }
    }
}

// MARK: - Show BottomSheet view controller

internal extension UIViewController {

    /// Present a `BottomSheetViewController` modally
    func presentBottomSheet(viewController: BottomSheetViewController) {
        viewController.modalPresentationStyle = .overFullScreen
        present(viewController, animated: false, completion: nil)
    }
}
