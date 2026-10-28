//
//  UPExperienceCarouselController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Pages complete SwiftUI onboarding screens while preserving native iOS 13 swipe behavior.
//

import SwiftUI

/// Native paging owns the horizontal gesture; each SwiftUI page owns its vertical content scroll.
internal final class UPExperienceCarouselController: UIPageViewController,
    UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let state: ExperienceRenderState
    private let model: ExperienceViewModel
    private var isTransitioning = false

    init(state: ExperienceRenderState, model: ExperienceViewModel) {
        self.state = state
        self.model = model
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
        dataSource = self
        delegate = self
        // Keep screen autocapture from reporting the carousel as a host-app screen.
        objc_setAssociatedObject(self, &ScreenNameTracker.untrackedScreenKey, true, .OBJC_ASSOCIATION_RETAIN)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        // The data source already mirrors RTL content; without this an RTL host app mirrors it twice.
        view.semanticContentAttribute = .forceLeftToRight
        if let page = page(at: model.currentStep) { setViewControllers([page], direction: .forward, animated: false) }
    }

    /// Programmatic actions and interactive swipes share the existing step-change callback.
    func updateSelection() {
        // No swiping while the card is dismissing.
        view.isUserInteractionEnabled = !state.isClosing
        guard !isTransitioning, let current = viewControllers?.first as? Page,
            current.index != model.currentStep, let next = page(at: model.currentStep) else { return }
        isTransitioning = true
        // In RTL a later step sits to the left, so the slide direction flips.
        let forward = (model.currentStep > current.index) != model.isRTL
        setViewControllers([next], direction: forward ? .forward : .reverse,
                           animated: !UIAccessibility.isReduceMotionEnabled) { [weak self] _ in
            self?.isTransitioning = false
            self?.focusCurrentPage()
            // Catch up with a step change that arrived during the animation.
            self?.updateSelection()
        }
    }

    /// VoiceOver moves to the new page instead of staying on an element that has gone.
    private func focusCurrentPage() {
        UIAccessibility.post(notification: .layoutChanged, argument: viewControllers?.first?.view)
    }

    private func page(at index: Int) -> Page? {
        guard model.flowContent?.steps.indices.contains(index) == true else { return nil }
        return Page(state: state, model: model, index: index)
    }

    // The pager is always left-to-right; RTL content swaps which neighbour is "before".
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let current = viewController as? Page else { return nil }
        return page(at: current.index + (model.isRTL ? 1 : -1))
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let current = viewController as? Page else { return nil }
        return page(at: current.index + (model.isRTL ? -1 : 1))
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            willTransitionTo pendingViewControllers: [UIViewController]) {
        // Hold programmatic page changes until the user's swipe settles.
        isTransitioning = true
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        // A cancelled swipe snaps back and leaves the step unchanged.
        if completed, let page = viewControllers?.first as? Page {
            state.selectFlowStep(page.index)
            focusCurrentPage()
        }
        isTransitioning = false
        updateSelection()
    }

    private final class Page: UIHostingController<UPExperienceCarouselPage> {
        let index: Int

        init(state: ExperienceRenderState, model: ExperienceViewModel, index: Int) {
            self.index = index
            super.init(rootView: UPExperienceCarouselPage(state: state, model: model, index: index))
            objc_setAssociatedObject(self, &ScreenNameTracker.untrackedScreenKey, true, .OBJC_ASSOCIATION_RETAIN)
            // Each page brings its own theme color, so a swipe never shows the wrong background.
            view.backgroundColor = model.carouselTheme[safe: index]?.backgroundColor ?? .white
            // Stable id for the UI test harness.
            view.accessibilityIdentifier = "userpilot-carousel-page-\(index)"
        }

        @objc required dynamic init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}

/// The header, body, button and dots travel together, including swipes begun over blank space or the footer.
private struct UPExperienceCarouselPage: View {
    @ObservedObject var state: ExperienceRenderState
    let model: ExperienceViewModel
    let index: Int

    private var theme: ExperienceTheme { model.carouselTheme[safe: index] ?? ExperienceTheme() }
    private var alignment: Alignment {
        switch theme.contentAlignment {
        case .middle, .center: return .center
        case .bottom: return .bottom
        case .top: return .top
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // The header only holds the close button; its symbol sits as far below the top as the
                // last item sits above the bottom, as on sheets and dialogs.
                if theme.isDismissButtonEnabled {
                    region(.header, width: geometry.size.width)
                        .padding(.top, UPExperienceLayout.closeTopPadding)
                        .padding(.bottom, UPExperienceLayout.spacing)
                }
                // Body scrolls on its own and sits at the theme's alignment in the space left over.
                GeometryReader { contentGeometry in
                    ScrollView(.vertical) {
                        region(.content, width: geometry.size.width)
                            .frame(minHeight: contentGeometry.size.height, alignment: alignment)
                    }
                }
                region(.footer, width: geometry.size.width)
                    .padding(.vertical, UPExperienceLayout.spacing)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(theme.backgroundColor))
        }
        // Direction comes from the experience content, not the host app.
        .environment(\.layoutDirection, model.isRTL ? .rightToLeft : .leftToRight)
        .experienceTextSize(scalingEnabled: state.textScaling)
        .disabled(state.isClosing)
        // VoiceOver users page with actions instead of a swipe.
        .accessibilityAction(named: Text("Next step")) { state.selectFlowStep(index + 1) }
        .accessibilityAction(named: Text("Previous step")) { state.selectFlowStep(index - 1) }
    }

    private func region(_ region: ExperienceRenderRegion, width: CGFloat) -> some View {
        UPExperienceFlow(state: state, model: model,
                         width: max(1, width - ThemeHandler.DefaultValues.contentMargin * 2),
                         region: region, stepIndex: index)
            .padding(.horizontal, ThemeHandler.DefaultValues.contentMargin)
    }
}
