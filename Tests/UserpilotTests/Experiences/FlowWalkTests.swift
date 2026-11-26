//
//  FlowWalkTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Verifies the index-based walk over one Flow payload and its renderer projections.
//

import XCTest
@testable import Userpilot

final class FlowWalkTests: XCTestCase {

    private let flowId = 4242

    func testConsecutiveTooltipsFormOneSegment_andEveryModalOrSlideoutIsAlone_inPayloadOrder() {
        let walk = FlowWalk(flow: flow(
            step(1, .tooltip), step(2, .tooltip), step(3, .modal),
            step(4, .modal), step(5, .tooltip), step(6, .slideout)
        ))

        XCTAssertEqual(walk.segments.map { $0.map(\.id) }, [[1, 2], [3], [4], [5], [6]])
    }

    func testNext_walksEverySegment_thenReturnsNil() throws {
        let walk = FlowWalk(flow: flow(step(1, .modal), step(2, .slideout)))

        let second = try XCTUnwrap(walk.next())

        XCTAssertEqual(second.index, 1)
        XCTAssertEqual(second.current(screen: nil).asFlowContent()?.steps.map(\.id), [2])
        XCTAssertNil(second.next())
        XCTAssertTrue(FlowWalk(flow: flow()).segments.isEmpty)
    }

    func testModalProjectsToCarousel_slideoutToSlideout_andTooltipToTooltip() {
        let walk = FlowWalk(flow: flow(step(1, .modal), step(2, .slideout), step(3, .tooltip)))

        let types = sequence(first: walk) { $0.next() }.map { $0.current(screen: nil).asFlowContent()?.type }

        XCTAssertEqual(types, [.carousel, .slideout, .tooltip])
    }

    func testProjection_keepsTheFlowsIdentity_andCarriesTheSegmentTheRendererReportsWith() throws {
        let source = flow([step(1, .modal), step(2, .modal)], stepsCount: 5)
        let run = FlowRun(endedStepIds: [1], hasStarted: true)

        let projection = try XCTUnwrap(FlowWalk(flow: source).next()).current(screen: "Checkout", run: run)

        let content = try XCTUnwrap(projection.asFlowContent())
        XCTAssertEqual(content.id, flowId)
        XCTAssertEqual(content.type, .carousel)
        XCTAssertEqual(content.steps.map(\.id), [2])
        XCTAssertEqual(content.stepsCount, 5)
        XCTAssertEqual(content.screens, source.screens)
        XCTAssertEqual(content.localeCode, source.localeCode)
        XCTAssertEqual(content.baseThemeId, source.baseThemeId)
        XCTAssertEqual(projection.experienceId(), flowId)
        XCTAssertEqual(
            projection.flowSegment(), FlowSegment(flowId: flowId, stepsCount: 5, screen: "Checkout", run: run)
        )
    }

    func testPayloadWithoutStepsCount_countsItsOwnSteps() {
        let projection = FlowWalk(flow: flow([step(1, .modal)], stepsCount: nil)).current(screen: nil)

        XCTAssertEqual(projection.flowSegment()?.stepsCount, 1)
    }

    func testTooltipSteps_getTargetingAndAPresentationFromTheirSettings() throws {
        let target = FlowStepTarget(
            targetClass: nil, targetText: nil,
            selector: ["view_tag": AnyCodable(42), "userpilot_id": AnyCodable("save")], bounds: nil
        )
        let above = step(
            1, .tooltip,
            settings: settings(position: .above, backdrop: FlowBackdrop(enabled: true, color: "#112233", opacity: 40)),
            target: target
        )
        let below = step(2, .tooltip, settings: settings(position: .below))
        let auto = step(3, .tooltip, settings: settings(position: .auto))

        let steps = try XCTUnwrap(FlowWalk(flow: flow(above, below, auto)).current(screen: nil).asFlowContent()?.steps)

        XCTAssertEqual(steps.map(\.presentation.preferredPlacement), [.top, .bottom, nil])
        XCTAssertEqual(
            steps[0].targeting?.selector?.properties, target.toStepTargeting().selector?.properties
        )
        let presentation = steps[0].presentation
        XCTAssertNil(presentation.pointerSize)
        // The dim reads `settings.backdrop` through the merged theme, so the step keeps it as authored.
        XCTAssertEqual(steps[0].settings?.backdrop, FlowBackdrop(enabled: true, color: "#112233", opacity: 40))
        XCTAssertNil(presentation.targetTapActionId)
    }

    func testTargetTapTooltip_advancesOnItsTarget_andDropsItsButtonLine() throws {
        let heading = Line(type: .heading, attrs: nil, content: nil)
        let button = Line(type: .button, attrs: nil, content: nil)
        let tapStep = step(
            1, .tooltip, settings: settings(advanceOn: .targetTap),
            sections: [Section(lines: [heading]), Section(lines: [button])]
        )
        let buttonStep = step(
            2, .tooltip, settings: settings(advanceOn: .button), sections: [Section(lines: [heading, button])]
        )

        let steps = try XCTUnwrap(FlowWalk(flow: flow(tapStep, buttonStep)).current(screen: nil).asFlowContent()?.steps)

        XCTAssertEqual(steps[0].presentation.targetTapActionId, "next")
        XCTAssertEqual(steps[0].sections.map { $0.lines.map(\.type) }, [[.heading]])
        XCTAssertNil(steps[1].presentation.targetTapActionId)
        XCTAssertEqual(steps[1].sections.map { $0.lines.map(\.type) }, [[.heading, .button]])
    }

    func testOnlyATooltipProjectionHasTooltipSteps_pagedByOrder() throws {
        let steps = [(30, 2), (10, 0), (21, 1), (22, 1)].map { id, order in
            Step(
                id: id, order: order, sections: [], buttonAction: nil, mobileTheme: nil,
                position: order + 1, stepType: .tooltip
            )
        }

        let projection = try XCTUnwrap(FlowWalk(flow: flow(steps, stepsCount: 3)).current(screen: nil).asFlowContent())

        XCTAssertEqual(projection.tooltipSteps?.map(\.id), [10, 21, 22, 30])
        XCTAssertNil(flow(steps, stepsCount: 3).tooltipSteps)
    }

    func testModalAndSlideoutSteps_reachTheirRendererUnchanged() throws {
        let modal = step(1, .modal, settings: settings(advanceOn: .button))

        let projected = try XCTUnwrap(FlowWalk(flow: flow(modal)).current(screen: nil).asFlowContent()?.steps.first)

        XCTAssertEqual(projected.id, modal.id)
        XCTAssertNil(projected.presentation)
        XCTAssertNil(projected.targeting)
        XCTAssertEqual(projected.settings, modal.settings)
    }

    func testIsCurrentSegmentEnded_needsEveryStepOfTheCurrentSegment() {
        let walk = FlowWalk(flow: flow(step(1, .tooltip), step(2, .tooltip)))

        XCTAssertFalse(walk.isCurrentSegmentEnded(FlowRun(endedStepIds: [1])))
        XCTAssertTrue(walk.isCurrentSegmentEnded(FlowRun(endedStepIds: [1, 2])))
    }

    func testContractFixture_walksATooltipAModalAndASlideoutSegment() throws {
        let reply = try XCTUnwrap(MockContentFactory.makeFlowContractPayload().toJSONString())
        let source = try XCTUnwrap(reply.experienceCandidates().first?.asFlowContent())

        let segments = sequence(first: FlowWalk(flow: source)) { $0.next() }.map { $0.current(screen: "Home") }

        XCTAssertEqual(segments.map { $0.asFlowContent()?.type }, [.tooltip, .carousel, .slideout])
        XCTAssertEqual(segments.map { $0.flowSegment()?.stepsCount }, [3, 3, 3])
        XCTAssertEqual(segments[0].asFlowContent()?.steps.first?.presentation.preferredPlacement, .bottom)
    }

    func testSlideoutStepsPosition_picksSheetOrDialogBeforeAnyTheme() throws {
        let themes = MockThemeHandler()
        themes.appTheme = try JSONDecoder().decode(
            ThemeData.self, from: Data(#"{"slideout": {"general": {"content_alignment": "center"}}}"#.utf8)
        )
        let bottom = step(1, .slideout, settings: settings(position: .bottom))
        let center = step(2, .slideout, settings: settings(position: .center))

        XCTAssertTrue(try XCTUnwrap(projected(bottom)).isBottomSheet(using: themes))
        XCTAssertFalse(try XCTUnwrap(projected(center)).isBottomSheet(using: themes))
        XCTAssertFalse(flow(step(3, .slideout)).isBottomSheet(using: themes))
    }

    // MARK: - Helpers

    private func projected(_ step: Step) -> FlowContent? {
        FlowWalk(flow: flow(step)).current(screen: nil).asFlowContent()
    }

    private func step(
        _ id: Int,
        _ type: FlowStepType,
        settings: FlowStepSettings? = nil,
        target: FlowStepTarget? = nil,
        sections: [Section] = []
    ) -> Step {
        Step(
            id: id, order: id, sections: sections, buttonAction: nil, mobileTheme: nil,
            position: id, stepType: type, settings: settings, target: target
        )
    }

    private func settings(
        position: FlowStepPosition? = nil, advanceOn: FlowAdvanceOn? = nil, backdrop: FlowBackdrop? = nil
    ) -> FlowStepSettings {
        FlowStepSettings(
            position: position, advanceOn: advanceOn, fallback: nil, dismissAction: nil, backdrop: backdrop
        )
    }

    private func flow(_ steps: Step...) -> FlowContent {
        flow(steps, stepsCount: steps.count)
    }

    private func flow(_ steps: [Step], stepsCount: Int?) -> FlowContent {
        FlowContent(
            id: flowId, type: .flow, steps: steps, mobileTheme: ContentMobileTheme(id: 1, themeData: nil),
            screens: ["Home"], screenType: .selected, localeCode: "en", stepsCount: stepsCount
        )
    }
}
