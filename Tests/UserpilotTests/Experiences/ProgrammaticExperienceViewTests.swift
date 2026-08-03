//
//  ProgrammaticExperienceViewTests.swift
//  Userpilot SDK
//
//  Smoke coverage for the two experience controllers whose XIBs were replaced by code.
//  These assertions protect construction and wiring, not visual styling or pixel geometry.
//

import XCTest
@testable import Userpilot

final class ProgrammaticExperienceViewTests: XCTestCase {

    private final class PermittingGlassResolver: GlassCapabilityResolving {
        func allowsGlass(
            for kind: GlassElementKind,
            surfaceMaterial: SurfaceMaterial?
        ) -> Bool {
            true
        }

        func glassTintAlpha(for style: UIUserInterfaceStyle) -> CGFloat { 0.28 }
        var masksBackdropBehindGlassSurface: Bool { true }
    }

    private final class SingleStepDataSource: NSObject, UICollectionViewDataSource {
        func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            1
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            collectionView.dequeueReusableCell(
                withReuseIdentifier: StepCollectionViewCell.identifier,
                for: indexPath
            )
        }
    }

    override func setUp() {
        super.setUp()
        Userpilot.Registry.shared.resetForTesting()
    }

    override func tearDown() {
        UIView.appearance().semanticContentAttribute = .unspecified
        Userpilot.Registry.shared.resetForTesting()
        super.tearDown()
    }

    func testCarouselBuildsRequiredHierarchyAndWiringWithoutAXIB() {
        let userpilot = makeUserpilot()
        let controller = CarouselExperienceViewController(
            experienceViewModel: ExperienceViewModel(container: userpilot.container)
        )

        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        controller.view.layoutIfNeeded()

        XCTAssertTrue(controller.collectionView.superview === controller.view)
        XCTAssertTrue(controller.buttonDismissContainerView.superview === controller.view)
        XCTAssertTrue(controller.buttonDismiss.superview === controller.buttonDismissContainerView)
        XCTAssertTrue(controller.viewStepsProgress.superview === controller.view)
        XCTAssertTrue(controller.collectionView.dataSource === controller)
        XCTAssertTrue(controller.collectionView.delegate === controller)
        XCTAssertEqual(closeActions(in: controller.buttonDismiss, target: controller), [
            "onCloseButtonClicked:"
        ])

        let registrationProbe = SingleStepDataSource()
        controller.collectionView.dataSource = registrationProbe
        controller.collectionView.reloadData()
        controller.collectionView.layoutIfNeeded()
        XCTAssertTrue(
            controller.collectionView.cellForItem(at: IndexPath(item: 0, section: 0))
                is StepCollectionViewCell
        )
    }

    func testSurveyListBuildsRequiredHierarchyAndWiringWithoutAXIB() throws {
        let userpilot = makeUserpilot()
        let controller = SurveyListViewController(
            surveyViewModel: SurveyViewModel(container: userpilot.container)
        )

        controller.loadViewIfNeeded()

        XCTAssertTrue(controller.buttonDismissContainerView.superview === controller.view)
        XCTAssertTrue(controller.buttonDismiss.superview === controller.buttonDismissContainerView)
        XCTAssertTrue(controller.scrollView.superview === controller.view)
        XCTAssertTrue(controller.containerView.superview === controller.scrollView)
        XCTAssertTrue(controller.actionButton.superview === controller.view)
        XCTAssertEqual(closeActions(in: controller.buttonDismiss, target: controller), [
            "onCloseButtonClicked:"
        ])

        let scrollIndex = try XCTUnwrap(controller.view.subviews.firstIndex(of: controller.scrollView))
        let buttonIndex = try XCTUnwrap(controller.view.subviews.firstIndex(of: controller.actionButton))
        XCTAssertLessThan(scrollIndex, buttonIndex, "The action button must remain tappable above content.")
    }

    /// The dialog rebuilds its container when the resolver arrives, because `setupView()` runs from
    /// `init` while callers inject the resolver immediately afterwards — the first container would
    /// otherwise keep whichever radius was resolved without one.
    ///
    /// It deliberately asserts there is **no** glass view. The date picker used to paint itself as a
    /// material and no longer does: it sits on its own dim, so the glass refracted the scrim instead
    /// of the app and the two cancelled into a flat grey. It now uses UIKit's alert palette, which
    /// is what a native alert shows in either appearance.
    func testDatePickerRebuildsItsContainerWhenTheResolverIsAssigned() throws {
        let dialog = DatePickerDialog()
        let firstContainer = try XCTUnwrap(dialog.subviews.first)

        dialog.glassResolver = PermittingGlassResolver()

        let rebuiltContainer = try XCTUnwrap(dialog.subviews.first)
        XCTAssertFalse(rebuiltContainer === firstContainer)
        XCTAssertFalse(
            rebuiltContainer.subviews.contains { $0 is UPGlassEffectView },
            "The date picker uses the system alert palette, not a glass material."
        )
        XCTAssertEqual(rebuiltContainer.backgroundColor, .secondarySystemBackground)
    }

    private func makeUserpilot() -> MockUserpilot {
        MockUserpilot(
            config: Userpilot.Config(token: "VIEW-SMOKE-\(UUID().uuidString)")
                .defaultInstance(false)
        )
    }

    private func closeActions(
        in button: UIButton,
        target: UIViewController
    ) -> [String]? {
        button.actions(forTarget: target, forControlEvent: .touchUpInside)
    }
}
