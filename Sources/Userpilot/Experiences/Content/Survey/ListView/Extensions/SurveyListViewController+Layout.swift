//
//  SurveyListViewController+Layout.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The survey list's view hierarchy and constraints — what `SurveyListViewController.xib` used to
//  declare, and the reason it no longer needs to: the floating action button means the layout has
//  two shapes, which a XIB cannot express.
//
//  Measurements live in `ThemeHandler.DefaultValues` with the rest of the SDK's spacing.
//

import UIKit

// MARK: - Floating action button

extension SurveyListViewController {

    /// Whether the chrome floats over the scrolling content, at both edges.
    ///
    /// Same gate as the rest of the chrome, and the same arrangement the carousel step uses: on
    /// iOS 26 the content runs to the display edge and the chrome sits on top of it, which is what
    /// Apple's scroll edge effect needs in order to render at all — with the content stopping
    /// short of the chrome there is nothing passing underneath to fade, and the effect draws nothing
    internal var floatsChrome: Bool {
        surveyViewModel.glassResolver.allowsGlass(for: .chrome)
    }

    /// The band at the bottom of the scroll view the floating button occupies, and that the
    /// content has to be able to clear. Zero when the button does not float, because then the
    /// scroll view stops above it and there is nothing to clear.
    ///
    /// This is also the *baseline* the keyboard handling adjusts from — see
    /// `SurveyListViewController+Keyboard`. It comes to the same 90pt the non-floating layout
    /// reserves below the scroll view (24 gap + 50 button + 16 margin), so the reachable content
    /// is unchanged; only what is painted behind the button changes.
    internal var scrollViewBottomClearance: CGFloat {
        guard floatsChrome else { return 0 }
        return ThemeHandler.DefaultValues.surveyListQuestionSpacing
            + UPButtonView.buttonHeight
            + ThemeHandler.DefaultValues.surveyListButtonBottomMargin
    }

    /// The band at the top of the scroll view the dismiss row occupies, and that the content has to
    /// be able to clear. Zero when the chrome does not float, because then the scroll view starts
    /// below the dismiss row and there is nothing to clear.
    ///
    /// Comes to the same offset the non-floating layout puts between the safe area and the first
    /// question (20 row margin + 35 button + 12 gap), so the content still begins in the same place;
    /// only what is painted behind the dismiss button changes.
    internal var scrollViewTopClearance: CGFloat {
        guard floatsChrome else { return 0 }
        return ThemeHandler.DefaultValues.dismissRowTopMargin
            + UPDismissButton.buttonSize
            + ThemeHandler.DefaultValues.surveyListContentTopMargin
    }

    /// Where the scrolling content starts: at the display's top edge under the floating dismiss
    /// button, or below the dismiss row as before.
    ///
    /// The display edge rather than the safe area, for the same reason as the bottom: content fills
    /// the display and passes behind the chrome, while the controls stay inside the safe area. The
    /// status bar inset is added back as content inset by `.always`, on top of
    /// ``scrollViewTopClearance``.
    private func scrollViewTopConstraint() -> NSLayoutConstraint {
        guard floatsChrome else {
            return scrollView.topAnchor.constraint(
                equalTo: buttonDismissContainerView.bottomAnchor,
                constant: ThemeHandler.DefaultValues.surveyListContentTopMargin)
        }
        return scrollView.topAnchor.constraint(equalTo: view.topAnchor)
    }

    /// Where the scrolling content stops: at the display's bottom edge under the floating button,
    /// or above the button as before.
    ///
    /// The edge rather than the safe area, because that is what Apple's guidance asks for — content
    /// fills the display and passes behind the chrome, while the *controls* stay inside the safe
    /// area. Stopping the content at the safe area leaves a band across the home indicator that
    /// content never reaches, which is the seam Apple's own apps do not have. What keeps it legible
    /// is the scroll edge effect, and what keeps it reachable is the safe area inset that
    /// `.always` adds on top of `scrollViewBottomClearance`.
    ///
    /// Exactly one constraint either way. The earlier attempt at this floated the button by
    /// deactivating the XIB's pairing and adding a constraint at runtime, which left the scroll
    /// view with seven vertical constraints and `hasAmbiguousLayout == true` — the reason it was
    /// reverted. Choosing the constraint while the layout is authored is what removes the ambiguity.
    private func scrollViewBottomConstraint() -> NSLayoutConstraint {
        guard floatsChrome else {
            return actionButton.topAnchor.constraint(
                equalTo: scrollView.bottomAnchor,
                constant: ThemeHandler.DefaultValues.surveyListQuestionSpacing)
        }
        return scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    }
}

// MARK: - View hierarchy

extension SurveyListViewController {

    /// Adds the subviews and pins them, in place of what the XIB used to declare.
    ///
    /// The action button goes in last so it draws over the scrolling content, and so it keeps its
    /// taps once the scroll view extends underneath it — the carousel step had to correct the same
    /// z-order at runtime.
    internal func buildViewHierarchy() {
        // Overwritten by the theme in `setupGeneralStyle()`; this is what shows until then.
        view.backgroundColor = .white

        buttonDismiss.addTarget(self, action: #selector(onCloseButtonClicked(_:)), for: .touchUpInside)

        // Scroll view first: when chrome floats it reaches the display edges, so the dismiss
        // row and action button have to be added after it or they lose their taps.
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        view.addSubview(buttonDismissContainerView)
        buttonDismissContainerView.addSubview(buttonDismiss)
        view.addSubview(actionButton)

        let safeArea = view.safeAreaLayoutGuide
        let contentLayoutGuide = scrollView.contentLayoutGuide
        let frameLayoutGuide = scrollView.frameLayoutGuide

        NSLayoutConstraint.activate([
            buttonDismissContainerView.topAnchor.constraint(
                equalTo: safeArea.topAnchor,
                constant: ThemeHandler.DefaultValues.dismissRowTopMargin),
            buttonDismissContainerView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            buttonDismissContainerView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            buttonDismissContainerView.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize),

            buttonDismiss.topAnchor.constraint(equalTo: buttonDismissContainerView.topAnchor),
            buttonDismiss.trailingAnchor.constraint(
                equalTo: buttonDismissContainerView.trailingAnchor,
                constant: ThemeHandler.DefaultValues.dismissButtonMargin.negative),
            buttonDismiss.widthAnchor.constraint(equalToConstant: UPDismissButton.buttonSize),
            buttonDismiss.heightAnchor.constraint(equalToConstant: UPDismissButton.buttonSize),

            // Below the dismiss row, or behind it when the chrome floats — see
            // `scrollViewTopConstraint()`. Chosen here, while the layout is authored, so there is
            // exactly one vertical top constraint either way.
            scrollViewTopConstraint(),
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scrollViewBottomConstraint(),

            actionButton.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor,
                                                 constant: ThemeHandler.DefaultValues.contentMargin),
            actionButton.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor,
                                                  constant: ThemeHandler.DefaultValues.contentMargin.negative),
            actionButton.bottomAnchor.constraint(
                equalTo: safeArea.bottomAnchor,
                constant: ThemeHandler.DefaultValues.surveyListButtonBottomMargin.negative),
            actionButton.heightAnchor.constraint(equalToConstant: UPButtonView.buttonHeight),

            // Vertical scrolling only: the questions fill the frame's width, and the content grows
            // downward. The XIB instead pinned the stack's trailing edge 393pt past the content
            // guide's — a frozen device width, dragged in by accident — which collapsed
            // `contentSize.width` to zero. Nothing depended on that, and pinning all four edges is
            // what makes the content size honest.
            containerView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor)
        ])
    }
}
