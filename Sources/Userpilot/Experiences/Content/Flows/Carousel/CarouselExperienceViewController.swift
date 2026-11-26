//
//  CarouselExperienceViewController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  This class is responsible for managing and displaying the carousel experience.
//  It contains UI components such as a dismiss button, action button, step progress view,
//  and a collection view to show the steps. The class integrates with the
//  `ExperienceViewModel` to handle data binding and user interactions.
//

import Foundation
import UIKit

internal final class CarouselExperienceViewController: UIViewController {

    // MARK: - IBOutlets
    /// Container view for the dismiss button.
    @IBOutlet internal weak var buttonDismissContainerView: UIView!

    /// Close button to dismiss the carousel experience.
    @IBOutlet internal weak var buttonDismiss: UPDismissButton!

    /// View displaying the step progress indicator.
    @IBOutlet internal weak var viewStepsProgress: UPStepsProgressView!

    /// Counter-style progress indicator, `2 of 3`, in the dots' row. Shown instead of the dots
    /// (`viewStepsProgress`) only when this carousel is one step of a Flow and the step's theme sets the progress
    /// style to `counter`; hidden otherwise.
    internal lazy var viewStepsCounter: UPStepsCounterView = {
        let progressView = UPStepsCounterView()
        progressView.isHidden = true
        return progressView
    }()

    /// Bar-style progress indicator along the top edge. Shown instead of the dots (`viewStepsProgress`) only when
    /// this carousel is one step of a Flow and the step's theme sets the progress style to `bar`; hidden otherwise.
    internal lazy var viewStepsBarProgress: UPStepsBarProgressView = {
        let progressView = UPStepsBarProgressView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true
        return progressView
    }()

    /// Collection view displaying the carousel steps.
    @IBOutlet internal weak var collectionView: UICollectionView! {
        didSet {
            collectionView.register(StepCollectionViewCell.self,
                                    forCellWithReuseIdentifier: StepCollectionViewCell.identifier)
            collectionView.bounces = false
            collectionView.alwaysBounceHorizontal = false
            collectionView.alwaysBounceVertical = false
        }
    }

    // MARK: - Properties

    /// View model managing the carousel experience state and actions.
    internal let experienceViewModel: ExperienceViewModel
    private var appSemanticContentAttribute: UIUserInterfaceLayoutDirection?

    /// Set by the first close of any kind; only that close may report the step, and taps during the dismiss
    /// animation do nothing.
    private(set) var isClosing = false

    // MARK: - Initializers

    /// Initializes the view controller with the given view model.
    init(experienceViewModel: ExperienceViewModel) {
        self.experienceViewModel = experienceViewModel
        super.init(nibName: "CarouselExperienceViewController", bundle: Userpilot.resourceBundle)
    }

    /// Required initializer with a coder, not implemented for programmatic instantiation.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    /// Called after the view has been loaded. Sets up initial UI configurations and binds the view model.
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        bindViewModel()

        if experienceViewModel.isRTL {
            appSemanticContentAttribute = UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute)
        }

        // This flag tells automatic screen tracking to ignore screens that the SDK is presenting
        objc_setAssociatedObject(
            self,
            &ScreenNameTracker.untrackedScreenKey,
            true,
            .OBJC_ASSOCIATION_RETAIN
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        experienceViewModel.onExperienceSeen()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let appSemanticContentAttribute {
            UIView.appearance().semanticContentAttribute = appSemanticContentAttribute == .leftToRight
            ? .forceLeftToRight : .forceRightToLeft
        }
    }

    /// Handle screen rotation
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let index = collectionView.currentIndex
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.viewStepsProgress.setNeedsDisplay()
            self.collectionView.scrollToItem(at: IndexPath(row: index, section: 0),
                                             at: .centeredHorizontally,
                                             animated: false)
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.reloadData()
        }, completion: nil)
    }

    // Override the preferredStatusBarStyle based on the current style
    override var preferredStatusBarStyle: UIStatusBarStyle {
        guard
            let theme = experienceViewModel.carouselTheme[safe: collectionView.currentIndex]
        else { return .lightContent }
        return theme.isLightTheme ? .darkContent : .lightContent
    }

    // MARK: - Actions

    /// Action handler for the close button. Dismisses the experience view.
    /// - Parameter sender: The button triggering the close action.
    @IBAction func onCloseButtonClicked(_ sender: UIButton) {
        guard !isClosing else { return }
        closeExperience()
    }

    /// True only for the first close or last-step action; taps during the dismiss animation report nothing.
    func claimCloseReport() -> Bool {
        guard !isClosing else { return false }
        isClosing = true
        return true
    }
}

// MARK: - UPExperienceDelegate

extension CarouselExperienceViewController: UPExperienceDelegate {
    /// The host app's close (`manualClose`) reports like the close button, or nothing when a tap already closed
    /// the carousel. An SDK-driven close sends no event and fires no host callback, and taps during its dismissal
    /// report nothing.
    func triggerCloseExperience(
        manualClose: Bool,
        completion: (() -> Void)?
    ) {
        if manualClose {
            closeExperience(completion: completion)
        } else {
            isClosing = true
            dismiss(animated: true) { [weak self] in
                if let completion {
                    completion()
                } else {
                    self?.experienceViewModel.onExperienceDismissalCompleted()
                }
            }
        }
    }
}
