//
//  File.swift
//
//
//  Created by Motasem Hamed on 20/10/2024.
//

import Foundation
import UIKit

internal class SlideOutDialog: UIViewController, ExperienceContentProtocol {

    @IBOutlet weak private var slideOutDialogView: UIView!
    
    /// Close button to dismiss the carousel experience.
    @IBOutlet internal weak var buttonDismiss: UPCloseButton!

    /// Action button used for various step interactions.
    @IBOutlet internal weak var buttonAction: UPButtonView!
    
    @IBOutlet weak private var slideOutContainerView: SlideOutContainerView! {
        didSet {
            slideOutContainerView.heightAnchor.constraint(lessThanOrEqualToConstant: 400).isActive = true
        }
    }

    /// View model managing the carousel experience state and actions.
    internal let experienceViewModel: ExperienceViewModel

    /// Initializes the view controller with the given view model.
    init(experienceViewModel: ExperienceViewModel) {
        self.experienceViewModel = experienceViewModel
        super.init(nibName: "SlideOutDialog", bundle: .module)
    }

    /// Required initializer with a coder, not implemented for programmatic instantiation.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        slideOutDialogView.applySlideOutDialogStyle()
        bindViewModel()
    }

    func bindViewModel() {
        // Bind data from the view model and update the view accordingly.
        experienceViewModel.bindData = { [weak self] in
            guard let self = self, let slideOutContent = self.experienceViewModel.slideOutContent else { return }
            // Set up the general style and reload data when view model data changes.
            self.setupGeneralStyle()
            self.slideOutContainerView.bindStep(
                slideOutContent,
                withThemeData: self.experienceViewModel.slideOutTheme,
                andExperienceContentListener: self,
                andImageLoader: self.experienceViewModel.imageLoader)
            // Bind the action button for the first step.
            // self?.bindActionButton(0)
        }

        // Trigger any initial actions or setup needed when the view model starts.
        experienceViewModel.onStart()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        slideOutDialogView.applySlideOutDialogAnimation()
    }
    
    /// Configures the general style for the carousel experience view.
    /// Sets up background color, dismiss button visibility, and step progress indicator.
    func setupGeneralStyle() {
        
        // Set the background color for the view.
        self.slideOutDialogView.backgroundColor = experienceViewModel.slideOutTheme.backgroundColor

        // Configure the dismiss button based on the theme settings.
        if theme.isDismissButtonEnabled {
            buttonDismiss.setupView(style: experienceViewModel.slideOutTheme)
        } else {
            buttonDismissContainerView.isHidden = true
        }
    }

    /// Binds the action button for a given step index.
    /// Sets up the button with its properties and configures the action when tapped.
    /// - Parameter index: The index of the step to bind the action button for.
    func bindActionButton(_ index: Int) {
        guard
            let theme = experienceViewModel.mergedTheme[safe: index],
            let step = experienceViewModel.carouselContent?.steps[safe: index],
            let lastSection = step.sections.last,
            let button = lastSection.lines.last,
            button.type == .button
        else {
            return
        }

        // Set up the action button with the step's button configuration and style.
        buttonAction.setupViews(
            line: button,
            action: step.buttonAction,
            style: theme
        ) { [weak self] action in
            guard let self = self else { return }

            // If it's the last step, handle dismissal and trigger actions accordingly.
            if self.isLastStep() {
                self.dismiss(animated: true, completion: {
                    if action.deepLink != nil {
                        self.experienceViewModel.onDeepLinkTriggered()
                    }
                    self.experienceViewModel.onExperienceCompleted()
                })
            }
        }
    }
    

    @IBAction private func onDismissButtonClicked(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

}
