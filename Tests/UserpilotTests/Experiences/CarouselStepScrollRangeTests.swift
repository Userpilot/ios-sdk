//
//  CarouselStepScrollRangeTests.swift
//  UserpilotTests
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  A carousel step whose content fits must not scroll. With the floating action button the step's
//  scroll view runs to the safe area and carries a bottom content inset for the button's clearance,
//  which is exactly the amount of phantom scroll range this pins to zero.
//

import XCTest
@testable import Userpilot

final class CarouselStepScrollRangeTests: XCTestCase {

    /// Answers the glass question without needing an iOS 26 runtime: the layout branch is decided
    /// by the resolver's verdict, not by `#available`, so the arithmetic is testable everywhere.
    private final class StubResolver: GlassCapabilityResolving {
        let allows: Bool
        init(allows: Bool) { self.allows = allows }
        func allowsGlass(for kind: GlassElementKind, surfaceMaterial: SurfaceMaterial?) -> Bool { allows }
        func glassTintAlpha(for style: UIUserInterfaceStyle) -> CGFloat { 0.28 }
        var masksBackdropBehindGlassSurface: Bool { true }
    }

    private static let cellFrame = CGRect(x: 0, y: 0, width: 402, height: 874)

    private var window: UIWindow?

    override func tearDown() {
        window = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeStep(paragraphs: Int) throws -> Step {
        let paragraph: [String: Any] = [
            "type": "paragraph",
            "attrs": ["text_align": "center"],
            "content": [["text": String(repeating: "Userpilot carousel step content. ", count: 4)]]
        ]
        let button: [String: Any] = [
            "type": "button",
            "attrs": ["text_align": "center"],
            "content": [["text": "Next"]]
        ]
        let payload: [String: Any] = [
            "id": 1,
            "order": 0,
            "button_action": ["button_action": "next"],
            "sections": Array(repeating: ["lines": [paragraph]], count: paragraphs) + [["lines": [button]]]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(Step.self, from: data)
    }

    /// Hosted in a real window, because the floating layout runs the scroll view to the display's
    /// bottom edge and the arithmetic then depends on the device's safe area inset. Off-window the
    /// insets are zero and these tests cannot tell a correct clearance from one that ignores them.
    private func makeCell(
        step: Step,
        glass: Bool,
        theme: ExperienceTheme = ExperienceTheme()
    ) -> StepCollectionViewCell {
        let host = UIWindow(frame: Self.cellFrame)
        host.isHidden = false
        let cell = StepCollectionViewCell(frame: Self.cellFrame)
        host.addSubview(cell)
        window = host

        cell.glassResolver = StubResolver(allows: glass)
        cell.bindStep(step, withTheme: theme, andImageLoader: MockImageLoader(), withLocale: false)
        cell.layoutIfNeeded()
        return cell
    }

    /// How far the content can be dragged past its resting position — the thing the user sees as
    /// "this scrolls even though there is nothing to scroll to".
    private func verticalScrollRange(of scrollView: UIScrollView) -> CGFloat {
        let inset = scrollView.adjustedContentInset
        return scrollView.contentSize.height + inset.top + inset.bottom - scrollView.bounds.height
    }

    private func clearance(theme: ExperienceTheme) -> CGFloat {
        let buttonMargin = theme.isStepsProgressEnabled
            ? ThemeHandler.DefaultValues.buttonBottomMarginWithStepProgress
            : ThemeHandler.DefaultValues.buttonBottomMarginWithoutStepProgress
        return UPButtonView.buttonHeight + buttonMargin + ThemeHandler.DefaultValues.distanceBetweenSections
    }

    // MARK: - Edge to edge

    func testFloatingStepRunsContentToTheDisplayEdge() throws {
        let cell = makeCell(step: try makeStep(paragraphs: 1), glass: true)

        // Apple's guidance: content fills the display and passes behind the chrome. Stopping at the
        // safe area leaves a band across the home indicator that content never reaches.
        XCTAssertEqual(cell.theScrollView.frame.maxY, cell.contentView.bounds.maxY, accuracy: 0.5)
    }

    func testLegacyStepStillStopsAboveTheButton() throws {
        let cell = makeCell(step: try makeStep(paragraphs: 1), glass: false)

        XCTAssertEqual(cell.theScrollView.frame.maxY,
                       cell.actionButton.frame.minY - ThemeHandler.DefaultValues.distanceBetweenSections,
                       accuracy: 0.5)
        XCTAssertLessThan(cell.theScrollView.frame.maxY, cell.contentView.bounds.maxY)
    }

    // MARK: - Content that fits must not scroll

    func testShortStepDoesNotScrollAcrossLayoutModes() throws {
        var progressTheme = ExperienceTheme()
        progressTheme.progress = ProgressStyle(color: nil, colorType: nil, enabled: true, type: nil)
        let cases: [(glass: Bool, theme: ExperienceTheme)] = [
            (true, ExperienceTheme()),
            (false, ExperienceTheme()),
            (true, progressTheme)
        ]

        for value in cases {
            let cell = makeCell(
                step: try makeStep(paragraphs: 1),
                glass: value.glass,
                theme: value.theme
            )
            XCTAssertEqual(verticalScrollRange(of: cell.theScrollView), 0, accuracy: 0.5)
        }
    }

    // MARK: - Content that overflows still scrolls, and still clears the button

    func testTallStepStillScrolls() throws {
        let theme = ExperienceTheme()
        let cell = makeCell(step: try makeStep(paragraphs: 12), glass: true, theme: theme)
        let scrollView = cell.theScrollView

        XCTAssertGreaterThan(
            verticalScrollRange(of: scrollView), 0,
            "Content taller than the step must still scroll."
        )
        XCTAssertEqual(
            scrollView.contentInset.bottom, clearance(theme: theme), accuracy: 0.5,
            "The floating button's clearance inset must survive: without it the last section "
                + "would rest underneath the button."
        )
    }
}
