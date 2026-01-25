//
//  NPSBottomSheetViewController.swift
//  Userpilot
//
//  Created by Motasem Hamed on 09/02/2025.
//

import UIKit

internal class NPSBottomSheetViewController: BottomSheetViewController {

    // MARK: - UI Elements
    /// Container view that holds the slide-out content
    internal lazy var npsContainerView: NPSContainerView = {
        let npsContainerView = NPSContainerView()
        npsContainerView.translatesAutoresizingMaskIntoConstraints = false
        return npsContainerView
    }()
    private var appSemanticContentAttribute: UIUserInterfaceLayoutDirection?

    // MARK: - Properties

    /// View model managing the carousel experience state and actions
    internal let npsViewModel: NPSViewModel

    // MARK: - Initializers

    /// Initializes the view controller with the given view model.
    /// - Parameter experienceViewModel: The view model to bind with the dialog.
    init(npsViewModel: NPSViewModel) {
        self.npsViewModel = npsViewModel
        super.init(nibName: nil, bundle: nil)
    }

    /// Required initializer with a coder, not implemented for programmatic instantiation.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        setContent(content: npsContainerView)
        registerKeyboardNotifications()
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
        npsViewModel.onExperienceSeen()
        appSemanticContentAttribute = UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if npsViewModel.isRTL {
            UIView.appearance().semanticContentAttribute = .forceRightToLeft
        } else {
            UIView.appearance().semanticContentAttribute = .forceLeftToRight
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let appSemanticContentAttribute {
            UIView.appearance().semanticContentAttribute = appSemanticContentAttribute == .leftToRight
            ? .forceLeftToRight : .forceRightToLeft
        }
    }

    deinit {
        removeKeyboardNotifications()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.npsContainerView.resetContentHeight(size)
        }, completion: nil)
    }

}

// MARK: - View Model Binding
extension NPSBottomSheetViewController {

    /// Binds the view model data to the view.
    func bindViewModel() {
        // Bind data from the view model and update the view accordingly.
        npsViewModel.bindData = { [weak self] canBindData in
            guard
                let self, canBindData,
                let npsContent = self.npsViewModel.npsContent,
                let npsTheme = self.npsViewModel.npsTheme
            else {
                self?.dismissBottomSheet()
                return
            }
            self.setupGeneralStyle()
            self.npsContainerView.bindStep(
                withimageLoader: npsViewModel.imageLoader,
                withTheme: npsTheme,
                andContent: npsContent,
                withLocal: npsViewModel.isRTL,
                npsContainerViewDelegate: self)
        }

        // Trigger any initial actions or setup needed when the view model starts.
        npsViewModel.onStart()
    }

    /// Sets up the general style for the dialog, including background color.
    func setupGeneralStyle() {
        guard let theme = npsViewModel.npsTheme else { return }
        setBackgroundColor(theme)
    }
}

// MARK: - UPExperience

extension NPSBottomSheetViewController: UPExperience {
    func triggerCloseExperience(isInternalEvent: Bool) {
        dismissBottomSheet()
    }
}

// MARK: - SurveyContainerViewDelegate

extension NPSBottomSheetViewController: NPSContainerViewDelegate {

    func onNPSDismissed() {
        npsViewModel.onNPSDismissed()
        dismissBottomSheet()
    }

    func onNPSSubmitted(
        _ userAnswer: Int,
        _ userFollowUpKey: String,
        _ userFollowUp: String
    ) {
        npsViewModel.onNPSSubmitted(userAnswer, userFollowUpKey, userFollowUp)
    }

    func onEndNPS(completedData: CompletedData?) {
        npsViewModel.endNPS(completedData)
        dismissBottomSheet()
    }

}
