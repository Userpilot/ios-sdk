//
//  NPSContainerView.swift
//  Userpilot
//
//  Created by Motasem Hamed on 09/02/2025.
//

import UIKit

// swiftlint:disable all
internal class NPSContainerView: UIView {
    
    // MARK: - UI Components

    /// Height of the "Ask Me Later" button. A text button, so shorter than the square dismiss
    /// buttons the other content views use.
    private static let dismissButtonHeight: CGFloat = 30

    #if DEBUG
    /// Exposed so a test can assert this view's dismiss row lines up with the other content views'.
    #endif

    /// A container for the dismiss button, with a fixed height.
    ///
    /// The button plus the 10 pt above it, matching `SlideOutContainerView` and
    /// `SurveyContainerView`, which both size this container as their button plus 10. It used to be
    /// a flat 45 with the button pushed 10 pt *past* the container's bottom, which put the button's
    /// top 25 pt down instead of 10 — 15 pt more space above it than the carousel or a survey has.
    /// Holds the dismiss button, which is positioned past this view's trailing edge so it can sit
    /// close to the card's edge. `UPOverflowTouchView` is what keeps that overhanging strip tappable —
    /// a plain `UIView` rejects the touch before the button is ever asked.
    private lazy var buttonDismissContainerView: UIView = {
        let view = UPOverflowTouchView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(
            equalToConstant: Self.dismissButtonHeight + 10).isActive = true
        return view
    }()
    
    /// The dismiss button.
    private var buttonDismiss: UPButtonView?
    
    /// The action button at the bottom of the view.
    private var actionButton: UPButtonView?

    /// The update score button
    private lazy var updateAnswerButton: UPButtonView = {
        let button = UPButtonView()
        // Built on first use, which is after `glassResolver` was set — so it has to read it here
        // rather than wait for the `didSet` that already ran.
        button.glassResolver = glassResolver
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: UPButtonView.buttonHeight).isActive = true
        return button
    }()
    
    /// A vertical stack view contains footer action buttons
    private lazy var footerButtonsStackView: UIStackView = {
        //let stackView = UIStackView(arrangedSubviews: [updateAnswerButton, actionButton])
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.backgroundColor = .clear
        stackView.spacing = ThemeHandler.DefaultValues.distanceBetweenSections
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    /// A container for footer action buttons
    private lazy var footerButtonsContianer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: UPButtonView.buttonHeight).isActive = true
        return view
    }()
    
    /// The steps progess view
    private lazy var barStepsProgressView: UPStepsBarProgressView = {
        let progressView = UPStepsBarProgressView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.heightAnchor.constraint(equalToConstant: 5).isActive = true
        return progressView
    }()
    
    /// The steps progess view
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
        view.heightAnchor.constraint(equalToConstant: ThemeHandler.DefaultValues.smallDistanceBetweenSections).isActive = true
        return view
    }()
    
    /// Breathing room below the content on a step that ends with it.
    ///
    /// The thank-you step usually has no button, so its message is the last thing in the stack and sits
    /// on the card's bottom padding alone. Hidden on every other step, where the footer buttons or the
    /// step progress already provide the gap.
    private lazy var bottomSpaceView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.isHidden = true
        view.heightAnchor.constraint(
            equalToConstant: ThemeHandler.DefaultValues.distanceBetweenSections).isActive = true
        return view
    }()

    /// A vertical stack view to manage parent views.
    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            buttonDismissContainerView, spaceView, scrollView, footerButtonsContianer,
            stepsProgressView, bottomSpaceView])
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.backgroundColor = .clear
        stackView.spacing = ThemeHandler.DefaultValues.smallDistanceBetweenSections
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    /// A scroll view to allow the central content to be scrollable.
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    /// A container view that holds the scrollable content inside the scroll view.
    private let contentContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        //view.heightAnchor.constraint(equalToConstant: 0).isActive = true
        return view
    }()
    
    /// A container for image logo.
    private lazy var imageContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.heightAnchor.constraint(equalToConstant: CGFloat(ThemeHandler.DefaultValues.npsImageDimensions)).isActive = true
        return view
    }()
    
    /// The logo image
    private let imageView: UPImageView = {
        let imageView = UPImageView()
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: CGFloat(ThemeHandler.DefaultValues.npsImageDimensions)),
            imageView.heightAnchor.constraint(equalToConstant: CGFloat(ThemeHandler.DefaultValues.npsImageDimensions))
        ])
        return imageView
    }()
    
    /// A vertical stack view for managing dynamically added sections.
    private let stepSectionsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.backgroundColor = .clear
        stackView.spacing = ThemeHandler.DefaultValues.smallDistanceBetweenSections
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private var scrollViewHeightConstraint: NSLayoutConstraint?
    private var storedConstraints: [NSLayoutConstraint] = []
    
    // MARK: - Properties
    private var imageLoader: ImageLoading!
    private var theme: NPSTheme!
    private var npsContent: NPSContent!
    private var isRTL = false
    private weak var npsContainerViewDelegate: NPSContainerViewDelegate?

    /// Decides whether Liquid Glass may be used by this view's chrome. Set by the owning
    /// view controller at construction.
    var glassResolver: GlassCapabilityResolving? {
        didSet {
            // Fades NPS content where it meets the footer action buttons.
            scrollView.applyUPBottomScrollEdgeEffect(
                allowsGlass: glassResolver?.allowsGlass(for: .chrome) ?? false)
            propagateGlassResolver()
        }
    }

    /// Hands the resolver to the buttons this view owns.
    ///
    /// Needed in both directions. The resolver arrives once, at construction — but these buttons are
    /// built and rebuilt per step (`getActionButton()`, `getCloseButton()`), so a button created later
    /// never saw it, and `UPButtonView` renders its legacy fill when it has no resolver. That is why no
    /// NPS button had glass: not the follow-up step's Submit and Update score, not the dismiss button,
    /// not the thank-you button. The factories assign it at creation; this covers whatever already
    /// exists when the resolver changes.
    private func propagateGlassResolver() {
        buttonDismiss?.glassResolver = glassResolver
        actionButton?.glassResolver = glassResolver
        updateAnswerButton.glassResolver = glassResolver
    }

    private var currentStep = 0
    private var viewHeight = CGFloat(0)
    private var userAnswer: Int = -1
    private var userFollowUp: String = ""
    private var userFollowUpKey: String = ""

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
             contentStackView].forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
            }

            // Add subviews
            addSubview(barStepsProgressView)
            addSubview(contentStackView)
            scrollView.addSubview(contentContainerView)
            contentContainerView.addSubview(stepSectionsStackView)
            footerButtonsContianer.addSubview(footerButtonsStackView)
            
            //buttonDismissContainerView.addSubview(buttonDismiss)
            stepSectionsStackView.addArrangedSubview(imageContainerView)
            imageContainerView.addSubview(imageView)

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

                footerButtonsStackView.trailingAnchor.constraint(
                    equalTo: footerButtonsContianer.trailingAnchor),
                footerButtonsStackView.centerYAnchor.constraint(
                    equalTo: footerButtonsContianer.centerYAnchor),
                
                imageView.centerYAnchor.constraint(equalTo: imageContainerView.centerYAnchor),
                imageView.centerXAnchor.constraint(equalTo: imageContainerView.centerXAnchor),
                
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
    func bindStep(withimageLoader imageLoader: ImageLoading,
                  withTheme theme: NPSTheme,
                  andContent npsContent: NPSContent,
                  withLocal isRTL: Bool,
                  npsContainerViewDelegate: NPSContainerViewDelegate) {
        self.imageLoader = imageLoader
        self.theme = theme
        self.npsContent = npsContent
        self.isRTL = isRTL
        self.npsContainerViewDelegate = npsContainerViewDelegate
        
        setupGeneralStyle()
        bindProgressBar()
        bindSurveyViews()
        setupActionButton()

        if isRTL {
            UIView.appearance().semanticContentAttribute = .forceRightToLeft
        } else {
            UIView.appearance().semanticContentAttribute = .forceLeftToRight
        }
    }

    // MARK: - Section Binding Methods

    /** Binds the sections of the provided step to the stack view. */
    private func bindSurveyViews() {
        var newView: UIView?
        switch currentStep {
        case 0:
            if let logo = theme.logo, !logo.isEmpty {
                imageContainerView.isHidden = false
            }
            let likertView = UPLikertView()
            likertView.setupView(npsStep: npsContent.content, npsTheme: theme, isRTL: isRTL, answer: userAnswer, viewStateProtocol: self)
            newView = likertView
        case 1:
            imageContainerView.isHidden = true
            let openTextView = UPOpenTextView()
            openTextView.setupView(followUpQuestion: getFollowUpQuestion(), placeholder: npsContent.content.followUp.placeholder, npsTheme: theme, isRTL: isRTL, viewStateProtocol: self)
            newView = openTextView
        case 2:
            let thankYouView = UPThankYouView()
            thankYouView.setupView(completedData: getThankYouMessage(), npsTheme: theme, isRTL: isRTL)
            newView = thankYouView
        default:
            break
        }
        
        if let newView = newView {
            stepSectionsStackView.addArrangedSubview(newView)
            updateContent(with: newView, animationSubViews: false)
        }
    }

    func updateContent(with newView: UIView, animationSubViews: Bool) {
        newView.alpha = 0
        buttonDismissContainerView.alpha = 0
        barStepsProgressView.alpha = 0
        stepsProgressView.alpha = 0
        imageContainerView.alpha = 0
        
        // Remove old views before adding the new one
        stepSectionsStackView.arrangedSubviews.forEach {
            if $0 !== imageContainerView {
                $0.removeFromSuperview()
            }
        }
        
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
        let newHeight = stepSectionsStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height

        // Animate height change smoothly
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: { [weak self] in
            if let scrollViewHeightConstraint = self?.scrollViewHeightConstraint {
                NSLayoutConstraint.deactivate([scrollViewHeightConstraint])
            }
            self?.scrollViewHeightConstraint = self?.scrollView.heightAnchor.constraint(
                lessThanOrEqualToConstant: min(newHeight, screenHeight * 0.7))
            self?.scrollViewHeightConstraint?.isActive = true

            // self?.scrollViewHeightConstraint?.constant = min(newHeight, screenHeight * 0.7)
            self?.viewHeight = min(newHeight, screenHeight * 0.7)
            self?.layoutIfNeeded()
        })
        delay(0.2) { [weak self] in
            UIView.animate(withDuration: 0.1) { [weak self] in
                guard self != nil else { return }
                newView.alpha = 1
            }
        }

        delay(0.2) { [weak self] in
            UIView.animate(withDuration: 0.2) { [weak self] in
                self?.buttonDismissContainerView.alpha = 1
                self?.barStepsProgressView.alpha = 1
                self?.stepsProgressView.alpha = 1
                self?.imageContainerView.alpha = 1
            }
        }
    }

    // MARK: - Action Methods
    private func setupGeneralStyle() {
        if let logo = theme.logo, !logo.isEmpty {
            imageView.setupView(url: logo, imageLoader: imageLoader)
        } else {
            imageContainerView.isHidden = true
        }
    }

}

extension NPSContainerView {

    // MARK: - Survey Step Content Retrieval

    // Return current survey follow-up question
    private func getFollowUpQuestion() -> FollowUpQuestion? {
        let followUpContent = npsContent.content.followUp
        
        // Universal case
        if followUpContent.type == .universal, let all = followUpContent.all {
            userFollowUpKey = all.key
            return all
        }
        
        // Conditional cases based on userAnswer
        switch userAnswer {
        case 0...6:
            if let detractors = followUpContent.detractors {
                userFollowUpKey = detractors.key
                return detractors
            }
        case 7...8:
            if let passives = followUpContent.passives {
                userFollowUpKey = passives.key
                return passives
            }
        default:
            if let promoters = followUpContent.promoters {
                userFollowUpKey = promoters.key
                return promoters
            }
        }
        return nil
    }

    // Return the "Thank You" message after survey completion
    private func getThankYouMessage() -> CompletedData? {
        let completedContent = npsContent.content.completed
        
        // Universal case
        if completedContent.type == .universal, let all = completedContent.all {
            return all
        }
        
        // Conditional cases based on userAnswer
        switch userAnswer {
        case 0...6:
            return completedContent.detractors
        case 7...8:
            return completedContent.passives
        default:
            return completedContent.promoters
        }
    }
}

extension NPSContainerView: ViewStateDelegate {

    func onViewStateChanged(isValid: Bool) {
        if currentStep == 0, isValid {
            getAnswerAndMoveToFollowUpQuestion()
        }
    }

    private func getAnswerAndMoveToFollowUpQuestion() {
        guard let upExperienceView = stepSectionsStackView.arrangedSubviews
            .compactMap({ $0 as? UPExperienceView })
            .first else { return }

        if let answer = upExperienceView.getAnswer() as? Int {
            userAnswer = answer
            currentStep = 1
            bindSurveyViews()
            setupActionButton()
        }
    }

    private func getFollowUpAnswer() {
        guard let upExperienceView = stepSectionsStackView.arrangedSubviews
            .compactMap({ $0 as? UPExperienceView })
            .first else { return }

        if let answer = upExperienceView.getAnswer() as? String {
            userFollowUp = answer
        }
    }
}

extension NPSContainerView {
    
    // MARK: - Component Setup

    /** Configures the action button based on the step's data. */
    private func setupActionButton() {
        // Hide footer buttons for the first step
        footerButtonsContianer.isHidden = currentStep == 0
        
        // Set up dismiss button
        buttonDismiss = getCloseButton()
        setupDismissButton(for: currentStep)

        // Set up action button and update for each step
        bottomSpaceView.isHidden = true
        switch currentStep {
        case 0:
            buttonDismiss?.setupViews(
                title: npsContent.content.survey.askMeLater ?? "Ask me later",
                npsTheme: theme,
                role: .tertiary
            ) { [weak self] _ in
                self?.npsContainerViewDelegate?.onNPSDismissed()
            }
        case 1:
            setupFollowUpButtons()
            footerButtonsContianer.isHidden = false
        default:
            setupThankYouButtons()
        }

        updateStepProgress()
    }

    private func getCloseButton() -> UPButtonView {
        buttonDismiss?.removeFromSuperview()
        let buttonDismiss = UPButtonView()
        buttonDismiss.glassResolver = glassResolver
        buttonDismissContainerView.addSubview(buttonDismiss)
        buttonDismiss.backgroundColor = .clear
        buttonDismiss.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            buttonDismiss.heightAnchor.constraint(equalToConstant: Self.dismissButtonHeight),
            // Flush with the container's bottom, as in the other two content views. The +10 that
            // was here pushed the button below its own container.
            buttonDismiss.bottomAnchor.constraint(equalTo: buttonDismissContainerView.bottomAnchor),
            buttonDismiss.trailingAnchor.constraint(equalTo: buttonDismissContainerView.trailingAnchor, constant: 20)
        ])
        return buttonDismiss
    }
    
    private func getActionButton() -> UPButtonView {
        actionButton?.removeFromSuperview()
        let button = UPButtonView()
        button.glassResolver = glassResolver
        button.backgroundColor = .clear
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: UPButtonView.buttonHeight).isActive = true
        return button
    }

    private func setupDismissButton(for step: Int) {
        switch step {
        case 1:
            buttonDismiss?.setupViews(
                title: npsContent.content.followUp.close,
                npsTheme: theme,
                role: .tertiary
            ) { [weak self] _ in
                self?.npsContainerViewDelegate?.onNPSSubmitted(self?.userAnswer ?? 0, self?.userFollowUpKey ?? "", self?.userFollowUp ?? "")
                self?.npsContainerViewDelegate?.onEndNPS(completedData: nil)
            }
        default:
            if let completedData = getThankYouMessage() {
                buttonDismiss?.setupViews(
                    title: completedData.button.close ?? "Close",
                    npsTheme: theme,
                    role: .tertiary
                ) { [weak self] _ in
                    self?.npsContainerViewDelegate?.onEndNPS(completedData: nil)
                }
            }
        }
    }

    private func setupFollowUpButtons() {
        // Set up action button
        actionButton = getActionButton()
        footerButtonsStackView.addArrangedSubviews([updateAnswerButton, actionButton!])

        // Two compact buttons side by side rather than one full-width CTA: they wrap their titles and
        // read as pills. The stack is pinned trailing-only, so hugging widths right-align the pair.
        actionButton?.wrapsContentWidth = true
        updateAnswerButton.wrapsContentWidth = true

        // The one step in the SDK that shows two tiers next to each other: Submit confirms, Update
        // score steps back. Same hue, 100% against 20%, which is what separates them.
        actionButton?.setupViews(
            title: npsContent.content.followUp.submit ?? "Submit",
            npsTheme: theme,
            role: .primary
        ) { [weak self] _ in
            self?.submitFollowUp()
        }

        updateAnswerButton.setupViews(
            title: npsContent.content.followUp.updateScore ?? "Update score",
            npsTheme: theme,
            role: .secondary
        ) { [weak self] _ in
            self?.currentStep = 0
            self?.bindSurveyViews()
            self?.setupActionButton()
        }
    }

    /// Submits the follow-up answer and advances to the thank-you state.
    ///
    /// Kept as one action boundary so the button callback and component tests exercise the same
    /// transition instead of duplicating the state changes at the call site.
    func submitFollowUp() {
        getFollowUpAnswer()
        npsContainerViewDelegate?.onNPSSubmitted(
            userAnswer,
            userFollowUpKey,
            userFollowUp
        )
        currentStep = 2
        bindSurveyViews()
        setupActionButton()
    }

    private func setupThankYouButtons() {
        if let completedData = getThankYouMessage() {
            stepsProgressView.isHidden = true
            barStepsProgressView.isHidden = true
            if !completedData.button.enabled {
                // Nothing follows the message, so it would otherwise rest on the card's padding alone.
                footerButtonsContianer.isHidden = true
                bottomSpaceView.isHidden = false
                return
            }
            footerButtonsStackView.clearViews()
            actionButton = getActionButton()
            footerButtonsStackView.addArrangedSubviews([actionButton!])
            actionButton?.setupViews(
                title: completedData.button.buttonText ?? "Done",
                npsTheme: theme,
                role: .primary
            ) { [weak self] _ in
                self?.npsContainerViewDelegate?.onEndNPS(completedData: completedData)
            }
        }
    }

    /// Update progress view based on visibility of step progress views
    private func updateStepProgress() {
        if stepsProgressView.isHidden == false {
            stepsProgressView.setCurrentStep(currentStep)
        } else if barStepsProgressView.isHidden == false {
            delay(0.2) { [weak self] in
                self?.barStepsProgressView.setCurrentStep(self?.currentStep ?? 0)
            }
        }
    }

    /// Update the progress of the current step in the survey dialog. */
    private func bindProgressBar() {
        // Toggle visibility based on theme settings
        if !theme.isStepsProgressEnabled {
            stepsProgressView.isHidden = true
            barStepsProgressView.isHidden = true
        } else {
            if theme.isStepsProgressBallType {
                barStepsProgressView.isHidden = true
                stepsProgressView.setupView(stepsCount: 2, theme: theme, isRTL: isRTL)
            } else {
                if let theme {
                    stepsProgressView.isHidden = true
                    barStepsProgressView.setupView(stepsCount: 2, theme: theme, isRTL: isRTL)
                }
            }
        }
    }
}

// MARK: - UPCardEdgeAware

extension NPSContainerView: UPCardEdgeAware {

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
