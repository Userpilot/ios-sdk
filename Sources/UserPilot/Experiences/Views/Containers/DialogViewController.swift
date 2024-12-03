//
//  DialogViewController.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 21/10/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  A view controller that presents a modal dialog with a customizable content area.
//  The dialog features a dimmed background and smooth presentation and dismissal animations.
//  It allows dynamic content to be added and provides options for customizing the background color.
//

import Foundation
import UIKit

internal class DialogViewController: UIViewController {

    // MARK: - UI Elements

    /// Main container view for the dialog
    private lazy var mainContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = ThemeHandler.DefaultValues.slideOutCornerRadius
        view.clipsToBounds = true
        return view
    }()

    /// View to hold dynamic content within the dialog
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Dimmed background view for the dialog
    private lazy var dimmedView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alpha = 0
        return view
    }()

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animatePresent()
    }

    // MARK: - Setup Views
    /// Sets up the view hierarchy and constraints for the dialog.
    private func setupViews() {
        view.backgroundColor = .clear
        view.addSubview(dimmedView)

        // Constraints for the dimmed background view
        NSLayoutConstraint.activate([
            dimmedView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimmedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Add the main container view to the dialog
        view.addSubview(mainContainerView)

        // Center the main container view and set its width
        NSLayoutConstraint.activate([
            mainContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mainContainerView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width * 0.9)
        ])

        // Set up the content view within the main container
        mainContainerView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(
                equalTo: mainContainerView.leadingAnchor,
                constant: ThemeHandler.DefaultValues.contentMargin),
            contentView.trailingAnchor.constraint(
                equalTo: mainContainerView.trailingAnchor,
                constant: ThemeHandler.DefaultValues.contentMargin.negative),
            contentView.topAnchor.constraint(
                equalTo: mainContainerView.topAnchor,
                constant: ThemeHandler.DefaultValues.contentMargin),
            contentView.bottomAnchor.constraint(
                equalTo: mainContainerView.bottomAnchor,
                constant: ThemeHandler.DefaultValues.contentBottomMargin.negative)
        ])

        dimmedView.alpha = 0
        mainContainerView.alpha = 0
    }
}

// MARK: - Animations

extension DialogViewController {

    /// Animates the presentation of the dialog.
    private func animatePresent() {
        mainContainerView.frame.origin.y += 50
        UIView.animate(withDuration: 0.4) {
            self.dimmedView.alpha = 1.0
            self.mainContainerView.alpha = 1.0
            self.mainContainerView.frame.origin.y -= 50
        }
    }

    /// Dismisses the dialog with a fade-out animation.
    func dismissDialog(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            guard let self else { return }
            self.dimmedView.alpha = 0
            self.mainContainerView.alpha = 0
        }, completion: { [weak self] _ in
            self?.dismiss(animated: false, completion: completion)
        })
    }
}

// MARK: - Public APIs

extension DialogViewController {

    /// Sets the content of the dialog.
    /// - Parameter content: A UIView to be displayed in the dialog.
    func setContent(content: UIView) {
        contentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            content.topAnchor.constraint(equalTo: contentView.topAnchor),
            content.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        view.layoutIfNeeded()
    }

    /// Sets the background color of the main container view.
    /// - Parameter color: The UIColor to set as the background color.
    func setBackgroundColor(_ theme: ExperienceTheme) {
        mainContainerView.backgroundColor = theme.backgroundColor
        dimmedView.isHidden = !theme.backdropEnabled
        if theme.backdropEnabled {
            dimmedView.backgroundColor = theme.backdropBackground
        }
    }
}

// MARK: - Show Dialog view controller

internal extension UIViewController {
    /// Presents a dialog view controller modally.
    /// - Parameter viewController: The DialogViewController to present.
    func presentDialog(viewController: DialogViewController) {
        viewController.modalPresentationStyle = .overFullScreen
        present(viewController, animated: false, completion: nil)
    }
}
