//
//  FlowRendererEventOrderTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Modal and slideout renderers report a tap's outcome before their dismiss animation, and a
//  second tap during that animation reports nothing. A manual close from outside reports like the
//  close button; an SDK close reports nothing.
//

import XCTest
@testable import Userpilot

final class FlowRendererEventOrderTests: XCTestCase {

    /// The bottom sheet and the dialog behind one interface, so each slideout test runs on both.
    private struct SlideOutRenderer {
        let name: String
        let act: (ButtonAction?) -> Void
        let close: () -> Void
        /// `triggerCloseExperience(manualClose:)`, as the publisher calls it.
        let closeFromOutside: (Bool) -> Void
    }

    private static let next = ButtonAction(buttonAction: "next", deepLink: nil)
    private static let link = ButtonAction(buttonAction: "link", deepLink: "shop://carts")

    private var userpilot: MockUserpilot!
    private var calls: [String] = []

    override func setUp() {
        super.setUp()
        userpilot = MockUserpilot.make(
            config: Userpilot.Config(token: "FLOW-ORDER-\(UUID().uuidString)").defaultInstance(false)
        )
        let publisher = userpilot.experiencesPublisher
        publisher.onPublishFlowStepOutcome = { [weak self] in self?.calls += $0.events.map(\.eventName) }
        publisher.onPublishInternalSDKEvent = { [weak self] in self?.calls.append($0.eventName) }
        publisher.onSetCompletionDeepLink = { [weak self] in self?.calls.append("link \($0.absoluteString)") }
        publisher.onExperienceDidFinishDismissing = { [weak self] in self?.calls.append("dismissal completed") }
    }

    override func tearDown() {
        userpilot = nil
        calls = []
        super.tearDown()
    }

    func testAFlowSlideOutStep_reportsItsCloseAtTheTap_once() {
        let renderers: [(name: String, close: () -> Void)] = [
            ("bottom sheet", loadedBottomSheet(isFlowStep: true).onClose),
            ("dialog", loadedDialog(isFlowStep: true).onClose)
        ]
        for renderer in renderers {
            calls = []

            renderer.close()
            renderer.close()

            XCTAssertEqual(calls, ["dismissed_mobile_content"], renderer.name)
        }
    }

    func testAFlowSlideOutStep_reportsItsActionAtTheTap() {
        let renderers: [(name: String, act: (ButtonAction?) -> Void)] = [
            ("bottom sheet", loadedBottomSheet(isFlowStep: true).onAction),
            ("dialog", loadedDialog(isFlowStep: true).onAction)
        ]
        for renderer in renderers {
            calls = []

            renderer.act(Self.next)

            XCTAssertEqual(calls, ["completed_mobile_content_step"], renderer.name)
        }
    }

    /// Standalone content has no Flow run to latch a second tap, and records its deep link before dismissing.
    func testAStandaloneSlideOut_recordsItsDeepLinkAtTheTap_andIgnoresASecondTap() {
        for renderer in slideOuts(isFlowStep: false) {
            calls = []

            renderer.act(Self.link)
            renderer.act(Self.link)
            renderer.close()

            XCTAssertEqual(calls, [
                "link shop://carts", "completed_mobile_content_step", "complete_mobile_content"
            ], renderer.name)
        }
    }

    /// The host app's `endExperience()` closes with `manualClose`, which ends the step as its close button
    /// does, for a Flow step and for standalone content alike.
    func testAManualClose_reportsTheSlideOutsDismissal_once_andLatchesALaterTap() {
        for isFlowStep in [true, false] {
            for renderer in slideOuts(isFlowStep: isFlowStep) {
                calls = []

                renderer.closeFromOutside(true)
                renderer.close()
                renderer.closeFromOutside(true)

                XCTAssertEqual(calls, ["dismissed_mobile_content"], "\(renderer.name), Flow step: \(isFlowStep)")
            }
        }
    }

    func testAnSDKClose_dismissesASlideOutSilently() {
        for isFlowStep in [true, false] {
            for renderer in slideOuts(isFlowStep: isFlowStep) {
                calls = []

                renderer.closeFromOutside(false)

                XCTAssertEqual(calls, [], "\(renderer.name), Flow step: \(isFlowStep)")
            }
        }
    }

    func testAFlowCarouselStep_reportsItsActionAtTheTap() {
        let sut = CarouselExperienceViewController(experienceViewModel: viewModel(type: .carousel, isFlowStep: true))
        sut.loadViewIfNeeded()

        sut.onActionButtonClicked(Self.next)

        XCTAssertEqual(calls.first, "completed_mobile_content_step")
    }

    /// A carousel that was never presented completes each `dismiss` at once, so a tap that still
    /// dismisses shows up as "dismissal completed".
    func testAStandaloneCarousel_recordsItsLastStepsDeepLinkAtTheTap_andIgnoresASecondTap() {
        let sut = loadedCarousel(isFlowStep: false)

        sut.onActionButtonClicked(Self.link)
        sut.onActionButtonClicked(ButtonAction(buttonAction: "link", deepLink: "shop://orders"))
        sut.onCloseButtonClicked(UIButton())

        XCTAssertEqual(calls, [
            "link shop://carts", "completed_mobile_content_step", "complete_mobile_content", "dismissal completed"
        ])
    }

    func testAManualClose_reportsTheCarouselsDismissal_once_andLatchesALaterTap() {
        for isFlowStep in [true, false] {
            calls = []
            let sut = loadedCarousel(isFlowStep: isFlowStep)

            sut.triggerCloseExperience(manualClose: true, completion: nil)
            sut.onCloseButtonClicked(UIButton())
            sut.onActionButtonClicked(Self.link)
            sut.triggerCloseExperience(manualClose: true, completion: nil)

            XCTAssertEqual(reported, ["dismissed_mobile_content"], "Flow step: \(isFlowStep)")
        }
    }

    func testALateActionTap_onAClosingCarousel_doesNotPageForward() {
        let sut = loadedCarousel(isFlowStep: false, stepCount: 2)

        sut.onCloseButtonClicked(UIButton())
        sut.onActionButtonClicked(Self.next)

        XCTAssertEqual(sut.experienceViewModel.currentStep, 0)
        XCTAssertEqual(calls, ["dismissed_mobile_content", "dismissal completed"])
    }

    func testAnSDKClose_dismissesTheCarouselSilently() {
        for isFlowStep in [true, false] {
            calls = []
            let sut = loadedCarousel(isFlowStep: isFlowStep)

            sut.triggerCloseExperience(manualClose: false, completion: nil)

            XCTAssertEqual(reported, [], "Flow step: \(isFlowStep)")
        }
    }

    // MARK: - Helpers

    /// What the renderer reported, without UIKit's dismissal completions.
    private var reported: [String] { calls.filter { $0 != "dismissal completed" } }

    private func slideOuts(isFlowStep: Bool) -> [SlideOutRenderer] {
        let bottomSheet = loadedBottomSheet(isFlowStep: isFlowStep)
        let dialog = loadedDialog(isFlowStep: isFlowStep)
        return [
            SlideOutRenderer(
                name: "bottom sheet", act: bottomSheet.onAction, close: bottomSheet.onClose,
                closeFromOutside: { bottomSheet.triggerCloseExperience(manualClose: $0, completion: nil) }),
            SlideOutRenderer(
                name: "dialog", act: dialog.onAction, close: dialog.onClose,
                closeFromOutside: { dialog.triggerCloseExperience(manualClose: $0, completion: nil) })
        ]
    }

    private func loadedBottomSheet(isFlowStep: Bool) -> SlideOutBottomSheetViewController {
        let sut = SlideOutBottomSheetViewController(
            experienceViewModel: viewModel(type: .slideout, isFlowStep: isFlowStep)
        )
        sut.loadViewIfNeeded()
        return sut
    }

    private func loadedDialog(isFlowStep: Bool) -> SlideOutDialogViewController {
        let sut = SlideOutDialogViewController(experienceViewModel: viewModel(type: .slideout, isFlowStep: isFlowStep))
        sut.loadViewIfNeeded()
        return sut
    }

    private func loadedCarousel(isFlowStep: Bool, stepCount: Int = 1) -> CarouselExperienceViewController {
        let sut = CarouselExperienceViewController(
            experienceViewModel: viewModel(type: .carousel, isFlowStep: isFlowStep, stepCount: stepCount)
        )
        sut.loadViewIfNeeded()
        return sut
    }

    /// A one-step renderer: step 301 at position 2 of Flow 88 (`steps_count` 3), or standalone content, which
    /// may hold `stepCount` steps from 301 on.
    private func viewModel(type: ContentType, isFlowStep: Bool, stepCount: Int = 1) -> ExperienceViewModel {
        let steps = (0..<stepCount).map {
            Step(
                id: 301 + $0, order: $0, sections: [], buttonAction: Self.link, mobileTheme: ExperienceTheme(),
                position: isFlowStep ? 2 : nil
            )
        }
        let content = FlowContent(
            id: 88, type: type, steps: steps,
            mobileTheme: ContentMobileTheme(id: 1, themeData: ExperienceTheme()),
            screens: [], screenType: .all, localeCode: "en", stepsCount: isFlowStep ? 3 : nil
        )
        let segment = FlowSegment(flowId: 88, stepsCount: 3, screen: "Home", run: FlowRun())
        userpilot.experiencesPublisher.onGetActiveMobileContent = {
            isFlowStep ? .flow(content: content, segment: segment) : .flow(content: content)
        }
        userpilot.themeHandler.onMergeExperienceThemes = { _, _, _ in
            ThemeData(carousel: ExperienceTheme(), slideOut: ExperienceTheme(), survey: nil)
        }
        return ExperienceViewModel(container: userpilot.container)
    }
}
