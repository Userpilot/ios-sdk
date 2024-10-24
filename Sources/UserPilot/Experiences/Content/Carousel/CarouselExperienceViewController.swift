//
//  CarouselExperienceViewController.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  This class is responsible for managing and displaying the carousel experience.
//  It contains UI components such as a dismiss button, action button, step progress view,
//  and a collection view to show the steps. The class integrates with the
//  `CarouselExperienceViewModel` to handle data binding and user interactions.
//

import Foundation
import UIKit

internal class CarouselExperienceViewController: UIViewController {

    // MARK: - IBOutlets

    /// Container view for the dismiss button.
    @IBOutlet internal weak var buttonDismissContainerView: UIView!

    /// Close button to dismiss the carousel experience.
    @IBOutlet internal weak var buttonDismiss: UPCloseButton!

    /// Action button used for various step interactions.
    @IBOutlet internal weak var buttonAction: UPButtonView!

    /// View displaying the step progress indicator.
    @IBOutlet internal weak var viewStepsProgress: UPStepsProgressView!

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
    internal let carouselExperienceViewModel: CarouselExperienceViewModel

    // MARK: - Initializers

    /// Initializes the view controller with the given view model.
    init(carouselExperienceViewModel: CarouselExperienceViewModel) {
        self.carouselExperienceViewModel = carouselExperienceViewModel
        super.init(nibName: "CarouselExperienceViewController", bundle: .module)
    }

    /// Required initializer with a coder, not implemented for programmatic instantiation.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    /// Called after the view has been loaded. Sets up initial UI configurations and binds the view model.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        bindViewModel()
        isModalInPresentation = true
    }

    // Override the preferredStatusBarStyle based on the current style
    override var preferredStatusBarStyle: UIStatusBarStyle {
        guard
            let theme = carouselExperienceViewModel.mergedTheme[safe: collectionView.currentIndex]
        else { return .lightContent }
        return theme.isLightTheme ? .darkContent : .lightContent
    }

    // MARK: - Actions

    /// Action handler for the close button. Dismisses the experience view.
    /// - Parameter sender: The button triggering the close action.
    @IBAction func onCloseButtonClicked(_ sender: UIButton) {
        closeExperience()
    }
}
