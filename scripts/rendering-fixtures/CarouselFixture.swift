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
            if index == 0 { lines.append(linkLine()) }
            lines.append(line("Next page \(index + 1)", type: "button"))
            step["sections"] = lines.map { ["lines": [$0]] }
            return step
        }
        if let locale = ProcessInfo.processInfo.environment["FIXTURE_LOCALE"] { content["locale_code"] = locale }
        payload["mobile_contents"] = content
        guard let flow = payload.toJSONString()?.toFlowContent()?.flowContent else {
            preconditionFailure("Local carousel fixture must decode")
        }
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        let state = ExperienceRenderState(
            .flow(ExperienceViewModel(container: userpilot.container)),
            textScaling: ProcessInfo.processInfo.arguments.contains("-text-scaling"))
        return UPExperienceHostingController(state: state, style: .fullScreen)
    }

    /// "Read our privacy policy before you start." with only the two middle words linked.
    private func linkLine() -> [String: Any] {
        ["type": "paragraph", "attrs": ["__type__": "paragraph", "text_align": "center"],
         "content": [
            ["type": "text", "text": "Read our ", "marks": []],
            ["type": "text", "text": "privacy policy",
             "marks": [["type": "link", "attrs": ["href": MockContentFactory.privacyURL]]]],
            ["type": "text", "text": " before you start.", "marks": []]
         ]]
    }

    private func line(_ text: String, type: String = "paragraph") -> [String: Any] {
        ["type": type, "attrs": ["__type__": type, "text_align": "center", "level": "h2"],
         "content": [["type": "text", "text": text, "marks": []]]]
    }
}

/// Non-carousel experiences for VoiceOver checks: `rich-text` (a flow dialog) and `survey-list`
/// (a full-screen list with a chosen rating and option).
final class ExperienceFixture {
    private let userpilot = MockUserpilot(config: Userpilot.Config(token: "LOCAL-A11Y-FIXTURE").defaultInstance(false))

    func makeController(kind: String, textScaling: Bool) -> UIViewController {
        userpilot.themeHandler.onMergeExperienceThemes = { _, theme, _ in
            ThemeData(carousel: theme ?? ExperienceTheme(), slideOut: theme ?? ExperienceTheme(), survey: nil)
        }
        userpilot.themeHandler.onMergeSurveyThemes = { _, theme in theme ?? MockContentFactory.makeSurveyTheme() }
        if kind == "survey-inputs", let survey = Self.inputsSurvey() {
            if ProcessInfo.processInfo.arguments.contains("-dark-theme") {
                let base = MockContentFactory.makeSurveyTheme()
                userpilot.themeHandler.onMergeSurveyThemes = { _, _ in
                    SurveyTheme(
                        general: SurveyGeneral(position: .bottom, primaryColor: "#0A84FF",
                                               backgroundColor: "#1C1C1E", cornerRadius: 12),
                        font: SurveyFont(fontFamily: "Default", fontColor: "#FFFFFF", colorType: .manual),
                        progress: base.progress, backdrop: base.backdrop)
                }
            }
            userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
            let state = ExperienceRenderState(
                .survey(SurveyViewModel(container: userpilot.container)), textScaling: textScaling)
            return UPExperienceHostingController(state: state, style: .fullScreen)
        }
        if kind == "survey-list", let survey = try? MockContentFactory.makeQuestionSurvey(type: .list) {
            userpilot.experiencesPublisher.onGetActiveMobileContent = { .survey(content: survey) }
            let state = ExperienceRenderState(
                .survey(SurveyViewModel(container: userpilot.container)), textScaling: textScaling)
            if let rating = survey.modules.first(where: { $0.type == .likert }),
               let choices = survey.modules.first(where: { $0.type == .multipleChoice }) {
                state.updateAnswer(for: rating) { $0.rating = 3 }
                state.updateAnswer(for: choices) { $0.toggleChoice(0, for: choices) }
            }
            return UPExperienceHostingController(state: state, style: .fullScreen)
        }
        guard let flow = MockContentFactory.makeRichTextFlowPayload().toJSONString()?.toFlowContent()?.flowContent else {
            preconditionFailure("Local rich-text fixture must decode")
        }
        userpilot.experiencesPublisher.onGetActiveMobileContent = { .flow(content: flow) }
        let state = ExperienceRenderState(
            .flow(ExperienceViewModel(container: userpilot.container)), textScaling: textScaling)
        return UPExperienceHostingController(state: state, style: .dialog)
    }

    /// Rating, date and phone inputs, for checking the inline pickers by eye: `-experience-fixture survey-inputs`.
    private static func inputsSurvey() -> SurveyContent? {
        let modules: [[String: Any]] = [
            ["id": 1, "type": "likert_scale", "question": "Rate us", "metadata": ["type": "numbers", "range": 5]],
            ["id": 2, "type": "single_input", "question": "Your birthday", "metadata": ["input_type": "date"]],
            ["id": 3, "type": "single_input", "question": "Your phone",
             "metadata": ["input_type": "phone_number", "placeholder": "Phone number"]]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: modules),
              let decoded = try? JSONDecoder().decode([SurveyStep].self, from: data) else { return nil }
        return SurveyContent(
            id: 400, type: .list, modules: decoded, metadata: SurveyContentMetaData(buttonLabel: "Send"),
            surveyTheme: MockContentFactory.makeSurveyMobileTheme(), screens: [], screenType: .all,
            localeCode: "en", timeDelay: 0)
    }
}
