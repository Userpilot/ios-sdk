//
//  SurveyContainerView.swift
//  Userpilot
//
//  Created by Motasem Hamed on 30/01/2025.
//

import Foundation
import UIKit

internal class SurveyContainerView: UIView {

    // MARK: - UI Components

    /// A container for the dismiss button, with a fixed height.
    private lazy var buttonDismissContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize).isActive = true
        return view
    }()

    /// The action button at the bottom of the view.
    private lazy var buttonDismiss: UPDismissButton = {
        let button = UPDismissButton()
        buttonDismissContainerView.addSubview(buttonDismiss)
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: buttonDismissContainerView.topAnchor),
            button.trailingAnchor.constraint(
                equalTo: buttonDismissContainerView.trailingAnchor,
                constant: ThemeHandler.DefaultValues.dismissButtonMargin),
            button.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize),
            button.widthAnchor.constraint(equalToConstant: UPDismissButton.buttonSize)
        ])
        button.addTarget(self, action: #selector(buttonDismissClicked), for: .touchUpInside)
        return button
    }()

    /// The action button at the bottom of the view.
    private lazy var actionButton: UPButtonView = {
        let button = UPButtonView()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: UPButtonView.buttonHeight).isActive = true
        return button
    }()

    /// The action button at the bottom of the view.
    /// /// The action button at the bottom of the view.
    private lazy var barStepsProgressView: UPStepsBarProgressView = {
        let progressView = UPStepsBarProgressView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.heightAnchor.constraint(greaterThanOrEqualToConstant: 5).isActive = true
        return progressView
    }()

    private lazy var stepsProgressView: UPStepsProgressView = {
        let progressView = UPStepsProgressView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        return progressView
    }()

    /// A vertical stack view to manage the arrangement of UI elements (dismiss button, content, action button).
    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            barStepsProgressView, buttonDismissContainerView, scrollView, actionButton, stepsProgressView])
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.spacing = ThemeHandler.DefaultValues.distanceBetweenSections
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    /// A scroll view to allow the central content to be scrollable.
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    /// A container view that holds the scrollable content inside the scroll view.
    private let contentContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// A vertical stack view for managing dynamically added sections.
    private let stepSectionsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = ThemeHandler.DefaultValues.distanceBetweenSections
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private var scrollViewHeightConstraint: NSLayoutConstraint?
    private var storedConstraints: [NSLayoutConstraint] = []

    // MARK: - Properties
    private var parentViewController: UIViewController!
    private var theme: SurveyTheme!
    private var surveyContent: SurveyContent!
    private var isRTL = false
    private weak var surveyContainerViewDelegate: SurveyContainerViewDelegate?
    private var currentStep = 0

    // MARK: - Initial Setup

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - UI Setup

    /**
     Reset height fo Scroll View on screen rotation.
     */
    func resetContentHeight(_ size: CGSize) {
        if let scrollViewHeightConstraint {
            NSLayoutConstraint.deactivate([scrollViewHeightConstraint])
        }
        scrollViewHeightConstraint = scrollView.heightAnchor.constraint(
            lessThanOrEqualToConstant:
                screenHeight * ThemeHandler.DefaultValues.slideOutContentMaxHeightPercentage)
        scrollViewHeightConstraint?.isActive = true
        self.layoutIfNeeded()
    }

    /**
     Sets up the layout and constraints for the view components.
     */
    private func setupUI() {
        tryCatch {
            // Deactivate and clear previously stored constraints
            NSLayoutConstraint.deactivate(storedConstraints)
            storedConstraints.removeAll()

            // Set scroll view height
            if let scrollViewHeightConstraint {
                NSLayoutConstraint.deactivate([scrollViewHeightConstraint])
            }
            scrollViewHeightConstraint = scrollView.heightAnchor.constraint(
                lessThanOrEqualToConstant:
                    screenHeight * ThemeHandler.DefaultValues.slideOutContentMaxHeightPercentage)
            scrollViewHeightConstraint?.isActive = true

            // Disable autoresizing masks for custom layout
            [scrollView, contentContainerView, stepSectionsStackView, buttonDismissContainerView,
             actionButton, contentStackView].forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
            }

            // Add subviews
            addSubview(contentStackView)
            scrollView.addSubview(contentContainerView)
            contentContainerView.addSubview(stepSectionsStackView)

            let safeAreaLayoutGuide = safeAreaLayoutGuide
            let frameLayoutGuide = scrollView.frameLayoutGuide

            // Constraint for the content container view height
            let contentViewHeightConstraint = contentContainerView.heightAnchor.constraint(
                equalTo: frameLayoutGuide.heightAnchor, constant: 0.0)
            contentViewHeightConstraint.priority = .defaultLow

            // Define constraints
            storedConstraints.append(contentsOf: [
                // Constraints for the content stack view (full-screen with padding)
                contentStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                contentStackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
                contentStackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
                contentStackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

                // Scroll view constraints
                contentContainerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                contentContainerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                contentContainerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                contentContainerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                contentContainerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

                // Step section stack view inside content container
                stepSectionsStackView.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
                stepSectionsStackView.leadingAnchor.constraint(
                    equalTo: contentContainerView.leadingAnchor,
                    constant: 0),
                stepSectionsStackView.trailingAnchor.constraint(
                    equalTo: contentContainerView.trailingAnchor,
                    constant: 0),
                stepSectionsStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentContainerView.bottomAnchor),

                // Content container view height constraint
                contentViewHeightConstraint
            ])

            // Activate the stored constraints
            NSLayoutConstraint.activate(storedConstraints)
        }
    }

    // MARK: - Binding Methods

    /**
     Binds the step data to the view and sets up the UI based on the provided theme and content.

     - Parameters:
       - step: The `Step` object containing the step data.
       - theme: The `ExperienceTheme` containing styling attributes.
       - slideOutContainerViewDelegate: Delegate for handling actions within the view.
       - imageLoader: Object responsible for loading images.
     */
    func bindStep(withTheme theme: SurveyTheme,
                  andContent surveyContent: SurveyContent,
                  withLocal isRTL: Bool,
                  surveyContainerViewDelegate surveyContainerViewDelegate: SurveyContainerViewDelegate) {
        self.theme = theme
        self.surveyContent = surveyContent
        self.isRTL = isRTL
        self.surveyContainerViewDelegate = surveyContainerViewDelegate

        setupGeneralStyle()
        bindSurveyViews()
    }

    // MARK: - Component Setup

    /**
     Configures the dismiss button based on the theme data.
     
     - Parameter theme: The `ExperienceTheme` used to style the dismiss button.
     */
    private func setupDismissButton() {
        guard let theme else { return }
        buttonDismiss.setupView(theme: theme)
    }

    /** Configures the action button based on the step's data. */
    private func setupActionButton() {
        guard let surveyContent, let theme else { return }

        // Set up the action button with the step's button configuration and theme.
        actionButton.setupViews(
            title: surveyContent.metadata?.buttonLabel ?? "Next",
            theme: theme
        ) { [weak self] _ in
            // self?.processSurvey()
        }
        actionButton.updateEnableState(isEnabled: getCurrentStepSurveyContent().isRequired == false)
    }

    private func setupStepsProgress() {
        guard let theme else { return }
        if shouldHideProgressStep() {
            stepsProgressView.isHidden = true
            barStepsProgressView.isHidden = true
        } else {
            if theme.isStepsProgressBallType {
                barStepsProgressView.isHidden = true
                stepsProgressView.setupView(stepsCount: surveyContent.modules.count, theme: theme)
            } else {
                stepsProgressView.isHidden = true
                barStepsProgressView.setupView(stepsCount: surveyContent.modules.count, theme: theme)
            }
        }
    }

    /** Update the progress of the current step in the survey dialog. */
    private func updateStepProgress() {
        if stepsProgressView.isHidden == false {
            stepsProgressView.setCurrentStep(currentStep)
        } else if barStepsProgressView.isHidden == false {
            barStepsProgressView.setCurrentStep(currentStep + 1)
        }
    }

    /// Retrieve the answer from the current survey view and move to the next step.
    /// This function extracts the answer from the user input and transitions to the next step in the survey.
    private func getAnswerAndMoveToNextStep() {
        let upExperienceView = stepSectionsStackView.arrangedSubviews
            .compactMap { $0 as? UPExperienceView }
            .first

        let answer = upExperienceView?.getAnswer()
        let answerPayload = upExperienceView?.getAnswerPayload()

        surveyContainerViewDelegate?.onAction(answer, answerPayload)
    }

    // MARK: - Section Binding Methods

    /** Binds the sections of the provided step to the stack view. */
    private func bindSurveyViews() {
        // guard let surveyContent,  else { return }

        let contentStep = getCurrentStepSurveyContent()

        switch contentStep.type {
        case .likert:
            let likertView = UPLikertView()
            likertView.setupView(surveyStep: contentStep, surveyTheme: theme, viewStateProtocol: self)
            stepSectionsStackView.addArrangedSubview(likertView)

        case .multipleChoice:
            let multipleChoiceView = UPMultipleChoiceView()
            multipleChoiceView.setupView(surveyStep: contentStep, surveyTheme: theme, viewStateProtocol: self)
            stepSectionsStackView.addArrangedSubview(multipleChoiceView)

        case .openText:
            let openTextView = UPOpenTextView()
            openTextView.setupView(surveyStep: contentStep, surveyTheme: theme, viewStateProtocol: self)
            stepSectionsStackView.addArrangedSubview(openTextView)

        case .singleInput:
            let singleInputView = UPSingleInputView()
            singleInputView.setupView(
                surveyStep: contentStep,
                surveyTheme: theme,
                viewStateProtocol: self,
                parentViewController: parentViewController
            )
            stepSectionsStackView.addArrangedSubview(singleInputView)

        case .completed:
            let thankYouView = UPThankYouView()
            thankYouView.setupView(surveyStep: contentStep, surveyTheme: theme)
            stepSectionsStackView.addArrangedSubview(thankYouView)

        default:
            break
        }
    }

    // MARK: - Action Methods

    @objc private func buttonDismissClicked() {
        surveyContainerViewDelegate?.onClose()
    }

    private func setupGeneralStyle() {
        setupDismissButton()
        setupActionButton()
        setupStepsProgress()
    }

}

extension SurveyContainerView {

    // Return current survey step content
    private func getCurrentStepSurveyContent() -> SurveyStep {
        return surveyContent.modules[currentStep]
    }

    private func getStepsCount() -> Int {
        return surveyContent.modules.count
    }

    private func isBottomSheetSurveyContent() -> Bool {
        return theme.general?.defaultPosition == .bottom
    }

    /** In case the logic contains move to Answer, then hide progress */
    private func shouldHideProgressStep() -> Bool {
        guard theme.isStepsProgressEnabled else { return true }

        return surveyContent.modules.contains { step in
            step.logic?.contains { logic in
                logic.action == .goToModule || logic.action == .endSurvey
            } ?? false
        }
    }

}

extension SurveyContainerView: ViewStateDelegate {

    func onViewStateChanged(isValid: Bool) {
        actionButton.updateEnableState(isEnabled: isValid)
    }

}
