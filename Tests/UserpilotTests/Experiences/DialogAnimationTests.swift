//
//  DialogAnimationTests.swift
//  Userpilot SDK
//
//  Covers `Config.dialogAnimation(_:)` and its path down to the centred dialog. The animation is
//  chosen from a value that has to survive three hops — config, view model, view controller — and
//  a break in any of them is invisible in a screenshot.
//

import XCTest
@testable import Userpilot

final class DialogAnimationTests: XCTestCase {

    override func tearDown() {
        UIView.setAnimationsEnabled(true)
        super.tearDown()
    }

    private func makeUserpilot(
        _ configure: (Userpilot.Config) -> Void = { _ in }
    ) -> MockUserpilot {
        let config = Userpilot.Config(token: "DIALOG-ANIM-\(UUID().uuidString)")
            .defaultInstance(false)
        configure(config)
        return MockUserpilot(config: config)
    }

    // MARK: - Config

    func testDefaultAnimationIsFade() {
        XCTAssertEqual(Userpilot.Config(token: "TOKEN").dialogAnimationType, .fade)
    }

    func testDialogAnimationSetterMutatesAndReturnsSelf() {
        let config = Userpilot.Config(token: "TOKEN")

        let returned = config.dialogAnimation(.slide)

        XCTAssertTrue(returned === config)
        XCTAssertEqual(config.dialogAnimationType, .slide)
        XCTAssertEqual(config.dialogAnimation(.fade).dialogAnimationType, .fade)
    }

    func testSlideOutDialogAdoptsAnimationFromViewModel() {
        let userpilot = makeUserpilot { $0.dialogAnimation(.slide) }
        let viewModel = ExperienceViewModel(container: userpilot.container)

        let dialog = SlideOutDialogViewController(experienceViewModel: viewModel)

        XCTAssertEqual(dialog.dialogAnimation, .slide)
    }

    func testSurveyDialogAdoptsAnimationFromViewModel() {
        let userpilot = makeUserpilot { $0.dialogAnimation(.slide) }
        let viewModel = SurveyViewModel(container: userpilot.container)

        let dialog = SurveyDialogViewController(surveyViewModel: viewModel)

        XCTAssertEqual(dialog.dialogAnimation, .slide)
    }

    func testSlideDismissalMovesTheRenderedDialogWithoutFadingItsCard() {
        let dialog = DialogViewController()
        dialog.dialogAnimation = .slide
        dialog.loadViewIfNeeded()
        dialog.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        dialog.setContent(content: UIView())
        dialog.view.layoutIfNeeded()
        dialog.mainContainerView.alpha = 1
        dialog.mainContainerView.transform = .identity
        dialog.dimmedView.alpha = 1
        UIView.setAnimationsEnabled(false)

        dialog.dismissDialog()

        XCTAssertEqual(dialog.mainContainerView.alpha, 1)
        XCTAssertNotEqual(dialog.mainContainerView.transform, .identity)
        XCTAssertEqual(dialog.dimmedView.alpha, 0)
    }

    func testFadeDismissalFadesTheRenderedDialogWithoutMovingItsCard() {
        let dialog = DialogViewController()
        dialog.dialogAnimation = .fade
        dialog.loadViewIfNeeded()
        dialog.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        dialog.setContent(content: UIView())
        dialog.view.layoutIfNeeded()
        dialog.mainContainerView.alpha = 1
        dialog.mainContainerView.transform = .identity
        dialog.dimmedView.alpha = 1
        UIView.setAnimationsEnabled(false)

        dialog.dismissDialog()

        XCTAssertEqual(dialog.mainContainerView.alpha, 0)
        XCTAssertEqual(dialog.mainContainerView.transform, .identity)
        XCTAssertEqual(dialog.dimmedView.alpha, 0)
    }

    func testObjCRawValuesAreStable() {
        // The enum is `@objc`, so the raw values are part of the public surface.
        XCTAssertEqual(Userpilot.DialogAnimation.fade.rawValue, 0)
        XCTAssertEqual(Userpilot.DialogAnimation.slide.rawValue, 1)
    }
}
