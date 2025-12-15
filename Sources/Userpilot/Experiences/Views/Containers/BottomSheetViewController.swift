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

    private lazy var mainContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        view.layer.masksToBounds = false
        view.layer.cornerRadius = ThemeHandler.DefaultValues.slideOutCornerRadius
        return view
    }()

    private lazy var contentView: UIView = {
        let view = UIView()
        view.clipsToBounds = false
        view.layer.masksToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var dimmedView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alpha = 0
        view.addTapGesture { [weak self] in
            self?.view.endEditing(true)
        }
        return view
    }()

    private var blurEffectView: UIVisualEffectView?
    private var mainContainerBottomConstraint: NSLayoutConstraint?
    private var appSemanticContentAttribute: UIUserInterfaceLayoutDirection?

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        appSemanticContentAttribute = UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute)
        setupViews()
        // setupGestures()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animatePresent()
    }

    deinit {
        UIView.appearance().semanticContentAttribute = appSemanticContentAttribute == .leftToRight
            ? .forceLeftToRight : .forceRightToLeft
    }

    // MARK: - Setup Views

    private func setupViews() {
        view.backgroundColor = .clear

        // Dimmed background
        view.addSubview(dimmedView)
        NSLayoutConstraint.activate([
            dimmedView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimmedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Main container
        view.addSubview(mainContainerView)
        mainContainerBottomConstraint = mainContainerView.bottomAnchor.constraint(
            equalTo: view.bottomAnchor,
            constant: view.frame.height)
        NSLayoutConstraint.activate([
            mainContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainContainerBottomConstraint!
        ])

        // Content view inside main container
        mainContainerView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(
                equalTo: mainContainerView.leadingAnchor,
                constant: ThemeHandler.DefaultValues.contentMargin),
            contentView.trailingAnchor.constraint(
                equalTo: mainContainerView.trailingAnchor,
                constant: -ThemeHandler.DefaultValues.contentMargin),
            contentView.topAnchor.constraint(equalTo: mainContainerView.topAnchor),
            contentView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -ThemeHandler.DefaultValues.contentBottomMargin)
        ])
    }

    // MARK: - Blur Effect

    private func applyBlurEffect(backgroundColor: UIColor, radius: CGFloat) {
        blurEffectView?.removeFromSuperview()

        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.clipsToBounds = true
        blurView.layer.cornerRadius = radius
        blurView.backgroundColor = backgroundColor

        mainContainerView.insertSubview(blurView, at: 0)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: mainContainerView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: mainContainerView.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: mainContainerView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: mainContainerView.trailingAnchor)
        ])
        blurEffectView = blurView
    }

    // MARK: - Gestures

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapDimmedView))
        dimmedView.addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false
        mainContainerView.addGestureRecognizer(panGesture)
    }

    @objc private func handleTapDimmedView() {
        // dismissBottomSheet()
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        guard translation.y > 0 else { return }

        let currentY = view.frame.height - mainContainerView.frame.height
        switch gesture.state {
        case .changed:
            mainContainerView.frame.origin.y = currentY + translation.y
        case .ended:
            if translation.y >= 20 {
                dismissBottomSheet()
            } else {
                mainContainerView.frame.origin.y = currentY
            }
        default:
            break
        }
    }

    // MARK: - Animations

    private func animatePresent() {
        view.layoutIfNeeded()
        mainContainerBottomConstraint?.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.dimmedView.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    func dismissBottomSheet(completion: (() -> Void)? = nil) {
        mainContainerBottomConstraint?.constant = view.frame.height
        UIView.animate(withDuration: 0.2, animations: {
            self.dimmedView.alpha = 0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: completion)
        })
    }

    // MARK: - Public APIs

    func setContent(content: UIView) {
        contentView.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            content.topAnchor.constraint(equalTo: contentView.topAnchor),
            content.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func setBackgroundColor(_ theme: ExperienceTheme) {
        applyBlurEffect(backgroundColor: theme.backgroundColor, radius: 25)
        dimmedView.isHidden = !theme.backdropEnabled
        if theme.backdropEnabled {
            dimmedView.backgroundColor = theme.backdropBackground
        }
    }

    func setBackgroundColor(_ theme: SurveyTheme) {
        applyBlurEffect(backgroundColor: theme.backgroundColor, radius: theme.borderRadius)
        dimmedView.isHidden = !theme.backdropEnabled
        if theme.backdropEnabled {
            dimmedView.backgroundColor = theme.backdropBackground
        }
    }

    func setBackgroundColor(_ theme: NPSTheme) {
        applyBlurEffect(backgroundColor: theme.backgroundColor, radius: theme.borderRadius)
        dimmedView.isHidden = false
        dimmedView.backgroundColor = .black.withOpacity(0.4)
    }
}

// MARK: - Present Bottom Sheet

internal extension UIViewController {
    func presentBottomSheet(viewController: UIViewController) {
        viewController.modalPresentationStyle = .overFullScreen
        present(viewController, animated: false, completion: nil)
    }
}
