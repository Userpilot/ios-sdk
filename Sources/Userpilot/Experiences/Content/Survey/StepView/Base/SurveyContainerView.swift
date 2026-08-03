//
//  SurveyContainerView.swift
//  Userpilot
//
//  Created by Motasem Hamed on 30/01/2025.
//

import Foundation
import UIKit

// swiftlint:disable all
internal class SurveyContainerView: UIView {

    // MARK: - UI Components

    /// A container for the dismiss button, with a fixed height.
    /// Holds the dismiss button, which is positioned past this view's trailing edge so it can sit
    /// close to the card's edge. `UPOverflowTouchView` is what keeps that overhanging strip tappable —
    /// a plain `UIView` rejects the touch before the button is ever asked.
    private lazy var buttonDismissContainerView: UIView = {
        let view = UPOverflowTouchView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize + 10).isActive = true
        return view
    }()

    /// The action button at the bottom of the view.
    private lazy var buttonDismiss: UPDismissButton = {
        let button = UPDismissButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonDismissClicked), for: .touchUpInside)
        button.glassResolver = glassResolver
        return button
    }()

    /// Decides whether Liquid Glass may be used by this view's chrome.
    ///
    /// Forwarded on assignment rather than read at build time: `buttonDismiss` is lazy and
    /// may already have been created by the time the owning view controller sets this.
    var glassResolver: GlassCapabilityResolving? {
        didSet { applyGlassStyling() }
    }

    /// Pushes the resolver's verdict into the chrome this view owns.
    private func applyGlassStyling() {
        let allowsGlass = glassResolver?.allowsGlass(for: .chrome) ?? false
        buttonDismiss.glassResolver = glassResolver
        actionButton.glassResolver = glassResolver
        // Fades survey content where it meets the action button instead of cutting it off.
        scrollView.applyUPBottomScrollEdgeEffect(allowsGlass: allowsGlass)
    }

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
        progressView.heightAnchor.constraint(equalToConstant: 5).isActive = true
        return progressView
    }()

    /// The progress bar's own constraints, held so the card can move it onto its top border.
    /// See ``UPCardEdgeAware``.
    private lazy var barTopConstraint = barStepsProgressView.topAnchor.constraint(
        equalTo: safeAreaLayoutGuide.topAnchor)
    private lazy var barLeadingConstraint = barStepsProgressView.leadingAnchor.constraint(
        equalTo: safeAreaLayoutGuide.leadingAnchor, constant: -20)
    private lazy var barTrailingConstraint = barStepsProgressView.trailingAnchor.constraint(
        equalTo: safeAreaLayoutGuide.trailingAnchor, constant: 20)

    /// The card's geometry, once it has told us. `nil` until then, and on any card that does not.
    private var cardEdge: UPCardEdge?

    private lazy var stepsProgressView: UPStepsProgressView = {
        let progressView = UPStepsProgressView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return progressView
    }()

    private lazy var spaceView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.heightAnchor.constraint(equalToConstant: 0).isActive = true
        return view
    }()

    /// A vertical stack view to manage the arrangement of UI elements (dismiss button, content, action button).
    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            buttonDismissContainerView, scrollView, spaceView, actionButton,
            stepsProgressView])
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
        // view.heightAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
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
    private weak var parentViewController: UIViewController!
    private var theme: SurveyTheme!
    private var surveyContent: SurveyContent!
    private var isDialogContent: Bool = false
    private var isRTL = false
    private weak var surveyContainerViewDelegate: SurveyContainerViewDelegate?
    private var currentStep = 0
    private var viewHeight = CGFloat(0)
    
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
        stepsProgressView.setNeedsDisplay()
        bindSurveyViews()
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
            addSubview(barStepsProgressView)
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
                // Held, because where they belong depends on the card: a card that reports its
                // geometry through `applyCardEdge(_:)` moves the bar onto its top border, and one
                // that does not leaves it flush with the top of the content area.
                barTopConstraint,
                barLeadingConstraint,
                barTrailingConstraint,

                // Flush to the top, like every other content view. Pinning this to the progress
                // bar's bottom reserved 25 pt for a 5 pt bar that is hidden more often than not —
                // and the space was reserved either way, since a plain hidden view still occupies
                // its constraints. The bar keeps its own position and overlays, as it does in NPS.
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
    func bindStep(
        withTheme theme: SurveyTheme,
        andContent surveyContent: SurveyContent,
        withLocal isRTL: Bool,
        isDialogContent isDialog: Bool,
        andParentViewController parentViewController: UIViewController,
        withSurveyContainerViewDelegate surveyContainerViewDelegate: SurveyContainerViewDelegate
    ) {
        self.theme = theme
        self.surveyContent = surveyContent
        self.isRTL = isRTL
        self.isDialogContent = isDialog
        self.parentViewController = parentViewController
        self.surveyContainerViewDelegate = surveyContainerViewDelegate

        setupGeneralStyle()
        bindSurveyViews()

        if isRTL {
            UIView.appearance().semanticContentAttribute = .forceRightToLeft
        } else {
            UIView.appearance().semanticContentAttribute = .forceLeftToRight
        }
    }

    func bindStep(currentStep: Int) {
        self.currentStep = currentStep
        updateStepProgress()
        bindSurveyViews()
        actionButton.updateEnableState(isEnabled: getCurrentStepSurveyContent().isRequired == false)
    }

    // MARK: - Component Setup

    /**
     Configures the dismiss button based on the theme data.
     
     - Parameter theme: The `ExperienceTheme` used to style the dismiss button.
     */
    private func setupDismissButton() {
        guard let theme else { return }
        buttonDismissContainerView.addSubview(buttonDismiss)
        NSLayoutConstraint.activate([
            buttonDismiss.bottomAnchor.constraint(equalTo: buttonDismissContainerView.bottomAnchor),
            buttonDismiss.trailingAnchor.constraint(
                equalTo: buttonDismissContainerView.trailingAnchor,
                constant: ThemeHandler.DefaultValues.dismissButtonMargin),
            buttonDismiss.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize),
            buttonDismiss.widthAnchor.constraint(equalToConstant: UPDismissButton.buttonSize)
        ])
        buttonDismiss.setupView(theme: theme)
    }

    /** Configures the action button based on the step's data. */
    private func setupActionButton() {
        guard surveyContent != nil, let theme else { return }

        // Set up the action button with the step's button configuration and theme.
        actionButton.setupViews(
            title: getCurrentStepSurveyContent().buttonLabel ?? "Next",
            theme: theme
        ) { [weak self] _ in
            self?.actionButton.isEnabled = false
            if self?.getCurrentStepSurveyContent().type == SurveyViewType.completed {
                self?.surveyContainerViewDelegate?.onAction(nil, nil)
            } else {
                self?.getAnswerAndMoveToNextStep()
            }
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
                barStepsProgressView.setupView(stepsCount: surveyContent.modules.count,
                                               theme: theme,
                                               isRTL: isRTL)
            }
        }
    }

    /** Update the progress of the current step in the survey dialog. */
    private func updateStepProgress() {
        if stepsProgressView.isHidden == false {
            stepsProgressView.setCurrentStep(currentStep)
        } else if barStepsProgressView.isHidden == false {
            delay(0.2) { [weak self] in
                guard let self else { return }
                self.barStepsProgressView.setCurrentStep(self.currentStep)
            }
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
        // stepSectionsStackView.clearViews()
        let contentStep = getCurrentStepSurveyContent()
        setupActionButton()

        var newView: UIView?
        switch contentStep.type {
        case .likert:
            let likertView = UPLikertView()
            likertView.setupView(
                surveyStep: contentStep,
                surveyTheme: theme,
                isListView: false,
                isDialog: isDialogContent,
                isRTL: isRTL,
                viewStateProtocol: self)
            newView = likertView
        case .multipleChoice:
            let multipleChoiceView = UPMultipleChoiceView()
            multipleChoiceView.setupView(
                surveyStep: contentStep,
                surveyTheme: theme,
                isListView: false,
                isRTL: isRTL,
                viewStateProtocol: self)
            newView = multipleChoiceView
        case .openText:
            let openTextView = UPOpenTextView()
            openTextView.setupView(
                surveyStep: contentStep,
                surveyTheme: theme,
                isListView: false,
                isRTL: isRTL,
                viewStateProtocol: self)
            newView = openTextView
        case .singleInput:
            let singleInputView = UPSingleInputView()
            singleInputView.glassResolver = glassResolver
            singleInputView.setupView(
                surveyStep: contentStep,
                surveyTheme: theme,
                isListView: false,
                isRTL: isRTL,
                viewStateProtocol: self,
                parentViewController: parentViewController
            )
            newView = singleInputView
        case .completed:
            let thankYouView = UPThankYouView()
            thankYouView.setupView(surveyStep: contentStep, surveyTheme: theme, isRTL: isRTL)
            newView = thankYouView
        }
        
        if let newView = newView {
            stepSectionsStackView.addArrangedSubview(newView)
            updateContent(with: newView, animationSubViews: isPreviousViewSameToCurrentView())
        }
    }

    func updateContent(
        with newView: UIView,
        animationSubViews: Bool
    ) {
        newView.alpha = 0
        if !animationSubViews {
            actionButton.alpha = 0
            barStepsProgressView.alpha = 0
        }
        // Remove old views before adding the new one
        stepSectionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stepSectionsStackView.addArrangedSubview(newView)

        // Force layout update to ensure constraints are applied
        stepSectionsStackView.setNeedsLayout()
        stepSectionsStackView.layoutIfNeeded()

        // Additional layout pass for RTL content to ensure proper text wrapping
        if isRTL {
            newView.setNeedsLayout()
            newView.layoutIfNeeded()
        }
        
        // Calculate the new height required for contentContainerView
        var newHeight = stepSectionsStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        if newView.isKind(of: UPLikertView.self) {
            if isDialogContent {
                newHeight = newHeight - 20
            }else {
                newHeight = newHeight - 40
            }
        }
        if newView.isKind(of: UPSingleInputView.self) {
            newHeight = newHeight + 30
        }

        // Animate height change smoothly
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: { [weak self] in
            if let scrollViewHeightConstraint = self?.scrollViewHeightConstraint {
                NSLayoutConstraint.deactivate([scrollViewHeightConstraint])
            }
            self?.scrollViewHeightConstraint = self?.scrollView.heightAnchor.constraint(
                lessThanOrEqualToConstant: min(newHeight, screenHeight * 0.7))
            self?.scrollViewHeightConstraint?.isActive = true
            self?.viewHeight = min(newHeight, screenHeight * 0.7)
            self?.layoutIfNeeded()
        })
        delay(0.2) { [weak self] in
            UIView.animate(withDuration: 0.1) { [weak self] in
                guard self != nil else { return }
                newView.alpha = 1
            }
        }
        if !animationSubViews {
            delay(0.2) { [weak self] in
                UIView.animate(withDuration: 0.5) { [weak self] in
                    self?.actionButton.alpha = 1
                    self?.barStepsProgressView.alpha = 1
                }
            }
        }
    }

    // MARK: - Action Methods

    @objc private func buttonDismissClicked() {
        surveyContainerViewDelegate?.onClose()
    }

    private func setupGeneralStyle() {
        setupDismissButton()
        setupStepsProgress()
    }

}

extension SurveyContainerView {

    // Return current survey step content
    private func getCurrentStepSurveyContent() -> SurveyStep {
        return surveyContent.modules[currentStep]
    }
    
    private func isPreviousViewSameToCurrentView() -> Bool {
        if currentStep - 1 < 0 { return false }
        return surveyContent.modules[currentStep].type == surveyContent.modules[currentStep - 1].type
    }

    private func getStepsCount() -> Int {
        return surveyContent.modules.count
    }

    private func isBottomSheetSurveyContent() -> Bool {
        return theme.general?.position == .bottom
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

// MARK: - UPCardEdgeAware

extension SurveyContainerView: UPCardEdgeAware {

    /// Moves the step progress bar onto the card's top border.
    ///
    /// The bar is meant to sit *on* the border, not inside the card's padding, so it escapes the
    /// content area's top inset and pulls its ends in far enough to stay within the corner curve.
    /// Without a card to measure against it stays flush with the top of the content area, which is
    /// the layout it was built with.
    func applyCardEdge(_ edge: UPCardEdge?) {
        guard cardEdge != edge else { return }
        cardEdge = edge

        barTopConstraint.constant = edge?.topOffset ?? 0
        // −20 keeps the pre-card behaviour: full-bleed across the content area and past its padding.
        barLeadingConstraint.constant = edge?.horizontalInset ?? -20
        barTrailingConstraint.constant = -(edge?.horizontalInset ?? -20)
        setNeedsLayout()
    }
}

// swiftlint:enable all
