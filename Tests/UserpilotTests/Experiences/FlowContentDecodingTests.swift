//
//  FlowContentDecodingTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Decodes the mobile Flow contract (`type: flow`) through the same candidate parser the
//  socket reply uses. Mirrors Android's FlowContentDecodingTest by case.
//

import XCTest
@testable import Userpilot

final class FlowContentDecodingTests: XCTestCase {

    func testContractExample_decodesEveryFlowField() throws {
        let flow = try decodeFlow(MockContentFactory.makeFlowContractPayload())

        XCTAssertEqual(flow.type, .flow)
        XCTAssertEqual(flow.stepsCount, 3)
        XCTAssertEqual(flow.steps.map(\.id), [9001, 9002, 9003])
        XCTAssertEqual(flow.steps.map(\.position), [1, 2, 3])
        XCTAssertEqual(flow.steps.map(\.stepType), [.tooltip, .modal, .slideout])

        let tooltip = flow.steps[0]
        XCTAssertEqual(tooltip.settings, FlowStepSettings(
            position: .below,
            advanceOn: .button,
            fallback: .skipStep,
            dismissAction: .dismissFlowShowNextSession,
            backdrop: FlowBackdrop(enabled: true, color: "#000000", opacity: 50)
        ))
        let target = try XCTUnwrap(tooltip.target)
        XCTAssertEqual(target.targetClass, "UIButton")
        XCTAssertEqual(target.targetText, "Save")
        XCTAssertEqual(target.bounds, FlowStepTargetBounds(posX: 16, posY: 320.5, width: 120, height: 48))
        let selector = try XCTUnwrap(target.toStepTargeting().selector)
        XCTAssertTrue(selector.isSupportedVersion)
        XCTAssertEqual(selector.effectiveProperties, [
            "accessibility_identifier": "checkout_save", "tag": "42", "userpilot_id": "checkout.save"
        ])
        XCTAssertEqual(tooltip.buttonAction?.buttonAction, "next")

        let slideout = flow.steps[2]
        XCTAssertEqual(slideout.settings?.position, .bottom)
        XCTAssertEqual(slideout.settings?.dismissAction, .dismissFlowNeverShowAgain)
        XCTAssertEqual(slideout.settings?.backdrop, FlowBackdrop(enabled: false, color: "#1A1A1A", opacity: 30))
        XCTAssertEqual(slideout.buttonAction?.buttonAction, "link")
        XCTAssertEqual(slideout.buttonAction?.deepLink, "shop://carts")
    }

    func testModalStep_decodesNullTargetAndNullOptionalSettings() throws {
        let flow = try decodeFlow(MockContentFactory.makeFlowContractPayload())

        XCTAssertNil(flow.steps[1].target)
        XCTAssertEqual(flow.steps[1].settings, FlowStepSettings(
            position: nil, advanceOn: .button, fallback: nil, dismissAction: .endFlow, backdrop: nil
        ))
        XCTAssertNil(flow.steps[2].target)
    }

    /// `position` is the one step key a Flow requires; see the position rule below.
    func testMissingOptionalFlowKeys_decodeAsAbsent() throws {
        let flow = try decodeFlow(contract(
            editingFlow: { $0["steps_count"] = nil },
            editingStep: { step in
                step["step_type"] = nil
                step["settings"] = [String: Any]()
                step["target"] = [String: Any]()
            }
        ))
        let step = flow.steps[0]

        XCTAssertNil(flow.stepsCount)
        XCTAssertNil(step.stepType)
        XCTAssertEqual(step.settings, Self.emptySettings)
        try assertEmptyTarget(step.target)

        let withoutBlocks = try decodeFlow(contract(step: 1) { step in
            step["settings"] = nil
            step["target"] = nil
        })
        XCTAssertNil(withoutBlocks.steps[1].settings)
        XCTAssertNil(withoutBlocks.steps[1].target)
    }

    /// iOS also accepts an explicit null `selector` off tooltip steps; Android's map adapter rejects it
    /// on every step, and the server always sends a non-empty selector with a target.
    func testExplicitNullOptionalFlowKeys_decodeAsAbsent() throws {
        let flow = try decodeFlow(contract(
            editingFlow: { $0["steps_count"] = NSNull() },
            editingStep: { step in
                step["step_type"] = NSNull()
                step["settings"] = [
                    "position": NSNull(), "advance_on": NSNull(), "fallback": NSNull(), "dismiss_action": NSNull(),
                    "backdrop": ["enabled": NSNull(), "color": NSNull(), "opacity": NSNull()]
                ]
                step["target"] = [
                    "target_class": NSNull(), "target_text": NSNull(), "selector": NSNull(), "bounds": NSNull()
                ]
            }
        ))
        let step = flow.steps[0]

        XCTAssertNil(flow.stepsCount)
        XCTAssertNil(step.stepType)
        XCTAssertEqual(step.settings, FlowStepSettings(
            position: nil, advanceOn: nil, fallback: nil, dismissAction: nil,
            backdrop: FlowBackdrop(enabled: nil, color: nil, opacity: nil)
        ))
        try assertEmptyTarget(step.target)

        let nullBlocks = try decodeFlow(contract(step: 1) { step in
            step["settings"] = NSNull()
            step["target"] = NSNull()
        })
        XCTAssertNil(nullBlocks.steps[1].settings)
        XCTAssertNil(nullBlocks.steps[1].target)
    }

    func testUnknownStepTypeOrSettingsValue_dropsTheFlowAndKeepsASurveySibling() throws {
        struct UnknownValue {
            let step: Int
            let path: String
            let edit: (inout [String: Any]) -> Void
        }
        let unknownValues = [
            UnknownValue(step: 0, path: "mobile_contents.steps.0.step_type", edit: { $0["step_type"] = "popover" }),
            UnknownValue(
                step: 0, path: "mobile_contents.steps.0.settings.position", edit: Self.setting("position", to: "left")
            ),
            UnknownValue(
                step: 0, path: "mobile_contents.steps.0.settings.advance_on",
                edit: Self.setting("advance_on", to: "swipe")
            ),
            UnknownValue(
                step: 0, path: "mobile_contents.steps.0.settings.fallback", edit: Self.setting("fallback", to: "retry")
            ),
            UnknownValue(
                step: 1, path: "mobile_contents.steps.1.settings.dismiss_action",
                edit: Self.setting("dismiss_action", to: "forever")
            )
        ]
        for unknown in unknownValues {
            var reply = try contract(step: unknown.step, editingStep: unknown.edit)
            reply.merge(MockContentFactory.makeSurveyContentPayload()) { flow, _ in flow }
            let logger = MockLogger()
            var loggedPath = false
            // Inspect arguments directly: MockLogger's printf formatter does not support OSLog privacy markers.
            logger.onError = { _, arguments in loggedPath = String(describing: arguments).contains(unknown.path) }

            let candidates = try XCTUnwrap(reply.toJSONString()).experienceCandidates(logger: logger)

            XCTAssertEqual(candidates.count, 1, unknown.path)
            XCTAssertEqual(candidates.first?.asSurveyContent()?.id, 12, unknown.path)
            XCTAssertEqual(logger.loggedErrors.count, 1, unknown.path)
            XCTAssertTrue(loggedPath, unknown.path)
        }
    }

    /// `tooltip` is only the Flow walk's projection, so a reply sending it as its type is refused.
    func testARawTooltipType_dropsTheContentAndKeepsASurveyOrNPSSibling() throws {
        struct Sibling {
            let name: String
            let payload: [String: Any]
            let isKept: (ExperienceContent?) -> Bool
        }
        let siblings = [
            Sibling(name: "survey", payload: MockContentFactory.makeSurveyContentPayload()) {
                $0?.asSurveyContent()?.id == 12
            },
            Sibling(name: "nps", payload: MockContentFactory.makeNPSContentPayload()) { $0?.asNPSContent() != nil }
        ]
        for sibling in siblings {
            var reply = try contract(editingFlow: { $0["type"] = "tooltip" }, editingStep: { _ in })
            reply.merge(sibling.payload) { flow, _ in flow }
            let logger = MockLogger()
            var loggedPath = false
            logger.onError = { _, arguments in
                loggedPath = String(describing: arguments).contains("mobile_contents.type")
            }

            let candidates = try XCTUnwrap(reply.toJSONString()).experienceCandidates(logger: logger)

            XCTAssertEqual(candidates.count, 1, sibling.name)
            XCTAssertTrue(sibling.isKept(candidates.first), sibling.name)
            XCTAssertEqual(logger.loggedErrors.count, 1, sibling.name)
            XCTAssertTrue(loggedPath, sibling.name)
        }
    }

    func testNumericAndBooleanSelectorValues_mapToStringIdentities() throws {
        let json = """
        {"selector":{"tag":42,"userpilot_id":7.5,"auto_tag":true,"accessibility_label":"Save",
        "accessibility_identifier":null,"custom":{"nested":1}}}
        """
        let target = try JSONDecoder().decode(FlowStepTarget.self, from: Data(json.utf8))

        let selector = try XCTUnwrap(target.toStepTargeting().selector)

        XCTAssertTrue(selector.isSupportedVersion)
        XCTAssertEqual(selector.effectiveProperties, [
            "tag": "42", "userpilot_id": "7.5", "auto_tag": "true", "accessibility_label": "Save"
        ])
        XCTAssertEqual(
            NativeElementTargetingStrategy().inflateSelector(from: selector.effectiveProperties) as? SelectorProperties,
            SelectorProperties(userpilotID: "7.5", autoTag: "true", tag: "42", accessibilityLabel: "Save")
        )
    }

    // MARK: - Helpers

    private static let emptySettings = FlowStepSettings(
        position: nil, advanceOn: nil, fallback: nil, dismissAction: nil, backdrop: nil
    )

    private static func setting(_ key: String, to value: String) -> (inout [String: Any]) -> Void {
        return { step in
            var settings = step["settings"] as? [String: Any] ?? [:]
            settings[key] = value
            step["settings"] = settings
        }
    }

    private func decodeFlow(_ payload: [String: Any]) throws -> FlowContent {
        let json = try XCTUnwrap(payload.toJSONString())
        return try XCTUnwrap(json.experienceCandidates().first?.asFlowContent(), "Flow did not decode")
    }

    /// The contract payload with `editFlow` applied to `mobile_contents` and `editStep` to one step.
    private func contract(
        editingFlow editFlow: (inout [String: Any]) -> Void = { _ in },
        step index: Int = 0,
        editingStep editStep: (inout [String: Any]) -> Void
    ) throws -> [String: Any] {
        var payload = MockContentFactory.makeFlowContractPayload()
        var flow = try XCTUnwrap(payload["mobile_contents"] as? [String: Any])
        var steps = try XCTUnwrap(flow["steps"] as? [[String: Any]])
        editStep(&steps[index])
        flow["steps"] = steps
        editFlow(&flow)
        payload["mobile_contents"] = flow
        return payload
    }

    private func assertEmptyTarget(
        _ target: FlowStepTarget?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let target = try XCTUnwrap(target, file: file, line: line)
        XCTAssertNil(target.targetClass, file: file, line: line)
        XCTAssertNil(target.targetText, file: file, line: line)
        XCTAssertNil(target.selector, file: file, line: line)
        XCTAssertNil(target.bounds, file: file, line: line)
        XCTAssertEqual(target.toStepTargeting().selector?.effectiveProperties, [:], file: file, line: line)
    }
}

// MARK: - Tooltip selector rule

extension FlowContentDecodingTests {

    func testTooltipStepWithoutAUsableSelector_dropsTheFlowAndKeepsASurveySibling() throws {
        let unusableTargets: [(name: String, edit: (inout [String: Any]) -> Void)] = [
            ("target null", { $0["target"] = NSNull() }),
            ("target missing", { $0["target"] = nil }),
            ("selector null", Self.editTarget { $0["selector"] = NSNull() }),
            ("selector empty", Self.editTarget { $0["selector"] = [String: Any]() }),
            ("selector missing", Self.editTarget { $0["selector"] = nil }),
            ("selector all null", Self.editTarget {
                $0["selector"] = ["accessibility_identifier": NSNull(), "tag": NSNull()]
            }),
            ("selector nested only", Self.editTarget { $0["selector"] = ["custom": ["nested": 1], "tag": NSNull()] })
        ]
        for unusable in unusableTargets {
            var reply = try contract(editingStep: unusable.edit)
            reply.merge(MockContentFactory.makeSurveyContentPayload()) { flow, _ in flow }
            let logger = MockLogger()
            var loggedPath = false
            logger.onError = { _, arguments in
                loggedPath = String(describing: arguments).contains("mobile_contents.steps.0.target")
            }

            let candidates = try XCTUnwrap(reply.toJSONString()).experienceCandidates(logger: logger)

            XCTAssertEqual(candidates.count, 1, unusable.name)
            XCTAssertEqual(candidates.first?.asSurveyContent()?.id, 12, unusable.name)
            XCTAssertEqual(logger.loggedErrors.count, 1, unusable.name)
            XCTAssertTrue(loggedPath, unusable.name)
        }
    }

    func testModalAndSlideoutSteps_needNoSelector() throws {
        let nullTarget = try decodeFlow(contract(step: 1) { $0["target"] = NSNull() })
        let missingTarget = try decodeFlow(contract(step: 1) { $0["target"] = nil })
        let emptySelector = try decodeFlow(contract(step: 2) { $0["target"] = ["selector": [String: Any]()] })

        XCTAssertNil(nullTarget.steps[1].target)
        XCTAssertNil(missingTarget.steps[1].target)
        XCTAssertEqual(emptySelector.steps[2].target?.selector?.isEmpty, true)
    }

    func testATooltipSelectorWithOneIdentityAmongNulls_isKept() throws {
        let flow = try decodeFlow(contract(editingStep: Self.editTarget {
            $0["selector"] = ["accessibility_identifier": NSNull(), "tag": 42]
        }))

        XCTAssertEqual(flow.steps[0].target?.toStepTargeting().selector?.effectiveProperties, ["tag": "42"])
    }

    private static func editTarget(
        _ edit: @escaping (inout [String: Any]) -> Void
    ) -> (inout [String: Any]) -> Void {
        return { step in
            var target = step["target"] as? [String: Any] ?? [:]
            edit(&target)
            step["target"] = target
        }
    }
}

// MARK: - Flow step position rule

extension FlowContentDecodingTests {

    func testAFlowStepPositionMissingNullZeroOrPastStepsCount_dropsTheFlowAndKeepsASurveySibling() throws {
        let badPositions: [(name: String, edit: (inout [String: Any]) -> Void)] = [
            ("position missing", { $0["position"] = nil }),
            ("position null", { $0["position"] = NSNull() }),
            ("position zero", { $0["position"] = 0 }),
            ("position past steps_count", { $0["position"] = 4 })
        ]
        for bad in badPositions {
            var reply = try contract(step: 1, editingStep: bad.edit)
            reply.merge(MockContentFactory.makeSurveyContentPayload()) { flow, _ in flow }
            let logger = MockLogger()

            let candidates = try XCTUnwrap(reply.toJSONString()).experienceCandidates(logger: logger)

            XCTAssertEqual(candidates.count, 1, bad.name)
            XCTAssertEqual(candidates.first?.asSurveyContent()?.id, 12, bad.name)
            XCTAssertEqual(logger.loggedErrors.count, 1, bad.name)
        }
    }

    /// A screen's reply carries only its own steps, so their positions can start past 1.
    func testAScreensStepsAtTheEndOfTheFlow_areAccepted() throws {
        let flow = try decodeFlow(contract(
            editingFlow: { flow in
                let steps = flow["steps"] as? [[String: Any]] ?? []
                flow["steps"] = zip(steps.dropFirst(), [3, 4]).map { step, position -> [String: Any] in
                    var step = step
                    step["position"] = position
                    return step
                }
                flow["steps_count"] = 4
            },
            editingStep: { _ in }
        ))

        XCTAssertEqual(flow.steps.map(\.position), [3, 4])
    }

    func testAStandaloneCarouselWithoutPositions_isStillAccepted() throws {
        let json = try XCTUnwrap(MockContentFactory.makeFlowContentPayload().toJSONString())

        let carousel = try XCTUnwrap(json.experienceCandidates().first?.asFlowContent())

        XCTAssertEqual(carousel.type, .carousel)
        XCTAssertTrue(carousel.steps.allSatisfy { $0.position == nil })
    }

    func testAPreviewResponse_skipsThePositionAndTooltipSelectorRules() throws {
        let payload = try contract(
            editingFlow: { flow in
                var steps = flow["steps"] as? [[String: Any]] ?? []
                steps[0]["target"] = NSNull()
                flow["steps"] = steps
            },
            step: 1,
            editingStep: { $0["position"] = NSNull() }
        )
        let flow = try XCTUnwrap(payload["mobile_contents"])
        let response: [String: Any] = ["mobile_content": flow, "content_type": "flow"]
        let data = try JSONSerialization.data(withJSONObject: response)

        let preview = try PreviewExperience.decode(from: data)

        XCTAssertEqual(preview.flow?.steps[0].stepType, .tooltip)
        XCTAssertNil(preview.flow?.steps[0].target)
        XCTAssertNil(preview.flow?.steps[1].position)
        XCTAssertThrowsError(try JSONDecoder().decode(PreviewExperience.self, from: data))
    }
}
