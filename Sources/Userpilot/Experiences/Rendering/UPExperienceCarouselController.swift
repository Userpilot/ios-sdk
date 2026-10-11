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
        objc_setAssociatedObject(self, &ScreenNameTracker.untrackedScreenKey, true, .OBJC_ASSOCIATION_RETAIN)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        if let page = page(at: model.currentStep) { setViewControllers([page], direction: .forward, animated: false) }
    }

    /// Programmatic actions and interactive swipes share the existing step-change callback.
    func updateSelection() {
        view.isUserInteractionEnabled = !state.isClosing
        guard !isTransitioning, let current = viewControllers?.first as? Page,
            current.index != model.currentStep, let next = page(at: model.currentStep) else { return }
        isTransitioning = true
        let forward = (model.currentStep > current.index) != model.isRTL
        setViewControllers([next], direction: forward ? .forward : .reverse,
                           animated: !UIAccessibility.isReduceMotionEnabled) { [weak self] _ in
            self?.isTransitioning = false
            self?.updateSelection()
        }
    }

    private func page(at index: Int) -> Page? {
        guard model.flowContent?.steps.indices.contains(index) == true else { return nil }
        return Page(state: state, model: model, index: index)
    }

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
        isTransitioning = true
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed, let page = viewControllers?.first as? Page { state.selectFlowStep(page.index) }
        isTransitioning = false
        updateSelection()
    }

    private final class Page: UIHostingController<UPExperienceCarouselPage> {
        let index: Int

        init(state: ExperienceRenderState, model: ExperienceViewModel, index: Int) {
            self.index = index
            super.init(rootView: UPExperienceCarouselPage(state: state, model: model, index: index))
            objc_setAssociatedObject(self, &ScreenNameTracker.untrackedScreenKey, true, .OBJC_ASSOCIATION_RETAIN)
            view.backgroundColor = model.carouselTheme[safe: index]?.backgroundColor ?? .white
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
                if theme.isDismissButtonEnabled {
                    region(.header, width: geometry.size.width)
                        .padding(.vertical, UPExperienceLayout.spacing)
                }
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
        .environment(\.layoutDirection, model.isRTL ? .rightToLeft : .leftToRight)
        .disabled(state.isClosing)
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
