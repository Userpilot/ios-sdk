//
//  TooltipFixture.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Typed tooltip content for tests. File-scope and non-private so every tooltip
//  test file shares one definition.
//

import Foundation
@testable import Userpilot

enum TooltipFixture {

    /// The button deep link `flowContent(deepLinkOnStep:)` puts on one step.
    static let deepLink = "myapp://tooltip-destination"

    /// Flow 77's tooltip segment as the `FlowWalk` projection hands it over: step `index` sits at
    /// `position` `order + 1` of `stepCount`, so the last step paged is the Flow's last.
    static func flowContent(
        stepCount: Int,
        selectorOnEveryStep: Bool = true,
        hasButtonLine: Bool = true,
        orders: [Int]? = nil,
        deepLinkOnStep: Int? = nil,
        stepThemes: [ExperienceTheme]? = nil,
        stepPresentations: [StepPresentation?]? = nil
    ) -> FlowContent {
        let resolved = orders ?? Array(0..<stepCount)
        return FlowContent(
            id: 77,
            type: .tooltip,
            steps: resolved.enumerated().map { index, order in
                step(
                    id: index,
                    order: order,
                    hasButtonLine: hasButtonLine,
                    hasSelector: selectorOnEveryStep || index == 0,
                    deepLink: index == deepLinkOnStep ? TooltipFixture.deepLink : nil,
                    mobileTheme: stepThemes?[safe: index] ?? ExperienceTheme(),
                    presentation: stepPresentations?[safe: index] ?? nil
                )
            },
            mobileTheme: ContentMobileTheme(id: 1, themeData: ExperienceTheme()),
            screens: [],
            screenType: .all,
            localeCode: "en",
            stepsCount: stepCount
        )
    }

    /// A tooltip step at `position` `order + 1` with a "Got it" button line and its own target selector.
    static func step(
        id: Int,
        order: Int,
        hasButtonLine: Bool = true,
        hasSelector: Bool = true,
        deepLink: String? = nil,
        mobileTheme: ExperienceTheme = ExperienceTheme(),
        presentation: StepPresentation? = nil
    ) -> Step {
        Step(
            id: id,
            order: order,
            sections: hasButtonLine ? [buttonSection(title: "Got it")] : [],
            buttonAction: ButtonAction(buttonAction: "next", deepLink: deepLink),
            mobileTheme: mobileTheme,
            targeting: StepTargeting(selector: hasSelector ? selector(id: id) : nil),
            presentation: presentation,
            position: order + 1,
            stepType: .tooltip
        )
    }

    /// A step's projected presentation with only the given fields set.
    static func presentation(pointerEnabled: Bool? = nil, targetTapAction: String? = nil) -> StepPresentation {
        StepPresentation(
            preferredPlacement: nil,
            pointer: pointerEnabled.map { TooltipPointer(enabled: $0) },
            targetTapAction: targetTapAction
        )
    }

    /// A theme whose card colour names its payload slot, so a test can tell
    /// *which* step's `theme_data` reached the renderer by reading one string.
    static func markedTheme(_ slot: Int) -> ExperienceTheme {
        var theme = ExperienceTheme()
        theme.colors = ColorsStyle(
            backgroundColor: "slot-\(slot)", textColor: nil, titleColor: nil)
        return theme
    }

    // MARK: Flow

    /// Flow 40 as one screen reply on `Home`, with steps 401, 402, … at positions `firstPosition`, …, or at
    /// `positions` when given. A tooltip step targets `target_<id>`, advances as `advanceOn` says, and runs
    /// `fallbacks[id]` when that target is never found. `backdrops[id]` becomes that step's
    /// `settings.backdrop`. Mirrors Android's `ExperiencesPublisherTooltipFlowTest` payload.
    static func flowPayload(
        types: [String],
        stepsCount: Int? = nil,
        firstPosition: Int = 1,
        positions: [Int]? = nil,
        advanceOn: String = "target_tap",
        fallbacks: [Int: String] = [:],
        dismissAction: String = "end_flow",
        backdrops: [Int: [String: Any]] = [:]
    ) -> [String: Any] {
        let steps = types.enumerated().map { index, type -> [String: Any] in
            let id = 401 + index
            let isTooltip = type == "tooltip"
            let target: Any = isTooltip ? ["selector": ["accessibility_identifier": "target_\(id)"]] : NSNull()
            var settings: [String: Any] = [
                "advance_on": isTooltip ? advanceOn : "button",
                "fallback": fallbacks[id].map { $0 as Any } ?? NSNull(),
                "dismiss_action": dismissAction
            ]
            settings["backdrop"] = backdrops[id]
            return [
                "id": id, "order": index, "position": positions?[safe: index] ?? firstPosition + index,
                "step_type": type,
                "sections": [[String: Any]](), "button_action": NSNull(), "theme_data": NSNull(),
                "target": target,
                "settings": settings
            ]
        }
        return ["mobile_contents": [
            "id": 40, "type": "flow", "steps_count": stepsCount ?? types.count, "steps": steps,
            "theme_data": ["id": 11, "theme_data": NSNull()], "screens": ["Home"],
            "screen_type": "selected", "locale_code": "en"
        ] as [String: Any]]
    }

    /// The first segment of `payload` as the publisher hands it to its renderer, on `Home`.
    static func flowSegment(_ payload: [String: Any]) -> ExperienceContent? {
        guard let flow = payload.toJSONString()?.toFlowContent()?.flowContent else { return nil }
        let segment = FlowWalk(flow: flow).current(screen: "Home")
        return segment.flowSegment() == nil ? nil : segment
    }

    /// The action button, discovered structurally as the last line of the last
    /// section — the same shape `UPTooltipCardView.bindSections` looks for.
    private static func buttonSection(title: String) -> Section {
        Section(lines: [
            Line(type: .button, attrs: nil, content: [Content(text: title, marks: nil)])
        ])
    }

    /// A distinct accessibility identifier per step, so two steps never resolve
    /// to the same view and `selector` changes observably on advance.
    private static func selector(id: Int) -> ElementSelector {
        ElementSelector(
            properties: SelectorProperties(
                accessibilityIdentifier: "tooltip-target-\(id)").toMap())
    }
}

/// Owns a `MockUserpilot` for the duration of a test.
///
/// `TooltipViewModel.userpilot` is weak, so a test that let the mock fall out
/// of scope would see the delegate silently become nil and fail for the wrong
/// reason. Holding it here ties its lifetime to the harness.
final class TooltipTestHarness {
    let userpilot: MockUserpilot
    /// Internal SDK events the view model published, in order.
    private(set) var events: [SDKEvent] = []
    /// What the view model handed the publisher, unless a test replaces `onPublishFlowStepOutcome`.
    private(set) var outcomes: [FlowStepOutcome] = []
    var flowEvents: [ExperienceEvent] { outcomes.flatMap(\.events) }

    /// Admits `flow` as a tooltip segment of Flow `flow.id`, with a fresh run.
    init(flow: FlowContent) {
        userpilot = MockUserpilot(
            config: Userpilot.Config(token: "TOOLTIP-\(UUID().uuidString)").defaultInstance(false)
        )
        // `MockUserpilot` does not register targeting; the view model resolves it
        // at init even though these tests never resolve a real target.
        userpilot.container.registerLazy(
            ElementTargeting.self, initializer: ElementResolver.init)
        let segment = FlowSegment(
            flowId: flow.id, stepsCount: flow.stepsCount ?? flow.steps.count, screen: nil, run: FlowRun())
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow, segment: segment) }
        userpilot.experiencesPublisher.onPublishInternalSDKEvent = { [weak self] in
            self?.events.append($0)
        }
        userpilot.experiencesPublisher.onPublishFlowStepOutcome = { [weak self] in
            self?.outcomes.append($0)
        }
    }

    /// A new view model over this harness's segment.
    func makeViewModel() -> TooltipViewModel {
        TooltipViewModel(container: userpilot.container)
    }
}
