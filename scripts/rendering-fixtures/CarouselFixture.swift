//
//  CarouselFixture.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Provides local onboarding pages for real XCUITest gestures without backend access.
//

import UIKit
@testable import Userpilot

final class CarouselFixture {
    private let userpilot = MockUserpilot(config: Userpilot.Config(token: "LOCAL-RENDER-FIXTURE").defaultInstance(false))

    func makeController() -> UIViewController {
        userpilot.themeHandler.onMergeExperienceThemes = { _, global, step in
            ThemeData(carousel: step ?? global ?? ExperienceTheme(), slideOut: global, survey: nil)
        }
        var payload = MockContentFactory.makeFlowContentPayload()
        guard var content = payload["mobile_contents"] as? [String: Any],
              let template = (content["steps"] as? [[String: Any]])?.first else {
            preconditionFailure("Local carousel fixture must decode")
        }
        content["steps"] = (0..<3).map { index -> [String: Any] in
            var step = template
            step["id"] = 114 + index
            step["order"] = index
            step["theme_data"] = [
                "button": ["background_color": "#4E4CE8", "label_color": "#FFFFFF"],
                "colors": ["background_color": ["#FFFFFF", "#ECF5FF", "#FFF6E8"][index],
                           "text_color": "#101828", "title_color": "#101828"],
                "general": ["content_alignment": "top"],
                "dismiss_content": ["enabled": true],
                "progress": ["enabled": true]
            ]
            var lines = [line("Onboarding page \(index + 1)", type: "heading")]
            if index == 2 {
                lines += (1...22).map { line("Paragraph \($0). This page has enough content to require vertical scrolling.") }
                lines.append(line("End of long page"))
            } else {
                lines.append(line("Swipe from the header, action or empty space to change pages."))
            }
            lines.append(line("Next page \(index + 1)", type: "button"))
            step["sections"] = lines.map { ["lines": [$0]] }
            return step
        }
        payload["mobile_contents"] = content
        guard let flow = payload.toJSONString()?.toFlowContent()?.flowContent else {
            preconditionFailure("Local carousel fixture must decode")
        }
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        let state = ExperienceRenderState(.flow(ExperienceViewModel(container: userpilot.container)))
        return UPExperienceHostingController(state: state, style: .fullScreen)
    }

    private func line(_ text: String, type: String = "paragraph") -> [String: Any] {
        ["type": type, "attrs": ["__type__": type, "text_align": "center", "level": "h2"],
         "content": [["type": "text", "text": text, "marks": []]]]
    }
}
