//
//  MockContentFactory.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 15/07/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

@testable import Userpilot
import UIKit

// swiftlint:disable all

internal enum MockContentFactory {

    static func makeFlowContentPayload() -> [String: Any] {
        return [
            "mobile_contents": [
                "id": 77,
                "type": "carousel",
                "token": "mobile:77",
                "locale_code": "default",
                "screen_type": "all",
                "screens": [],
                "steps": [
                    [
                        "id": 114,
                        "layout": "image_title_text",
                        "order": 0,
                        "mobile_content_id": 77,
                        "theme_data": [
                            "button": [
                                "background_color": "#002E01",
                                "border_color": "#002E01",
                                "label_color": "#FFFFFF"
                            ],
                            "colors": [:]
                        ],
                        "button_action": [
                            "android_deep_link": NSNull(),
                            "button_action": "next",
                            "ios_deep_link": NSNull()
                        ],
                        "sections": [
                            [
                                "lines": [
                                    [
                                        "attrs": [
                                            "__type__": "image",
                                            "actual_size": [
                                                "height": 245,
                                                "width": 301
                                            ],
                                            "alt": NSNull(),
                                            "hash": "U3Qlh0~q%2~W00VsjZVs00icM{N]00V@o1V@",
                                            "src": "https://media.userpilot.io/appex/images/2q1MRsWjzqHKYFMGtRfjCmoM5Ai-Mobile%20Design%20Image%2013.png",
                                            "style": [
                                                "border_radius": 0,
                                                "height": "auto",
                                                "object_fit": "fill",
                                                "width": "auto"
                                            ]
                                        ],
                                        "content": [],
                                        "type": "image"
                                    ]
                                ]
                            ],
                            [
                                "lines": [
                                    [
                                        "attrs": [
                                            "__type__": "heading",
                                            "level": "h2",
                                            "text_align": "center"
                                        ],
                                        "content": [
                                            [
                                                "marks": [],
                                                "text": "Save the date, webinar is coming",
                                                "type": "text"
                                            ]
                                        ],
                                        "type": "heading"
                                    ]
                                ]
                            ],
                            [
                                "lines": [
                                    [
                                        "attrs": [
                                            "__type__": "paragraph",
                                            "text_align": "center"
                                        ],
                                        "content": [
                                            [
                                                "marks": [
                                                    [
                                                        "attrs": [
                                                            "font_size": "16px"
                                                        ],
                                                        "type": "textStyle"
                                                    ]
                                                ],
                                                "text": "We're hosting a webinar February 5th. Click the button to book your spot.Registration is fee!",
                                                "type": "text"
                                            ]
                                        ],
                                        "type": "paragraph"
                                    ]
                                ]
                            ],
                            [
                                "lines": [
                                    [
                                        "attrs": [
                                            "__type__": "button",
                                            "text_align": "center"
                                        ],
                                        "content": [
                                            [
                                                "marks": [
                                                    [
                                                        "attrs": [
                                                            "font_size": "16px"
                                                        ],
                                                        "type": "textStyle"
                                                    ],
                                                    [
                                                        "attrs": NSNull(),
                                                        "type": "bold"
                                                    ]
                                                ],
                                                "text": "Book a Seat",
                                                "type": "text"
                                            ]
                                        ],
                                        "type": "button"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ],
                "theme_data": [
                    "id": 1,
                    "theme_id": 1,
                    "theme_type": "custom",
                    "theme_data": [
                        "button": [
                            "background_color": "#4E4CE8",
                            "border_color": "#4E4CE8",
                            "border_radius": 6,
                            "border_width": 0,
                            "label_color": "#FFFFFF"
                        ],
                        "colors": [
                            "background_color": "#FFFFFF",
                            "text_color": "#000000",
                            "title_color": "#000000"
                        ],
                        "dismiss_content": [
                            "color": "#656567",
                            "color_type": "automatic",
                            "enabled": true
                        ],
                        "general": [
                            "content_alignment": "top",
                            "font_family": "Default"
                        ],
                        "progress": [
                            "color": "#4E4CE8",
                            "color_type": "automatic",
                            "enabled": false
                        ]
                    ]
                ]
            ],
            "request_id": NSNull()
        ]
    }
    
    
    // MARK: – NEW: Survey ------------------------------------------------------------------
    
    static func makeSurveyContent(id: Int = 1, token: String = "survey-token") -> SurveyContent {
        return SurveyContent(
            id: id,
            token: token,
            type: .step,
            modules: [makeSurveyStep()],
            metadata: SurveyContentMetaData(buttonLabel: "Continue"),
            surveyTheme: makeSurveyMobileTheme(),
            screens: ["Home"],
            screenType: .all,
            localeCode: "en",
            timeDelay: 0
        )
    }
    
    static func makeSurveyMobileTheme() -> SurveyMobileTheme {
        return SurveyMobileTheme(
            id: 202,
            themeData: makeSurveyTheme()
        )
    }
    
    static func makeSurveyStep() -> SurveyStep {
        return SurveyStep(
            id: 1,
            isRequired: true,
            logic: nil,
            metadata: makeSurveyMetadata(),
            question: "How do you rate our app?",
            subheader: "We value your feedback.",
            type: .likert,
            buttonLabel: "Submit"
        )
    }
    
    static func makeSurveyMetadata() -> Metadata {
        return Metadata(
            highScore: "Great",
            lowScore: "Poor",
            range: 5,
            type: .stars,
            placeholder: nil,
            choices: nil,
            isMultiSelect: nil,
            otherChoice: nil,
            enablePropertyCreation: nil,
            inputType: nil,
            maxLength: nil,
            propertyName: nil,
            buttonAction: nil,
            iosDeepLink: nil,
            enabled: nil
        )
    }
    
    static func makeSurveyTheme() -> SurveyTheme {
        return SurveyTheme(
            general: SurveyGeneral(
                position: .bottom,
                primaryColor: "#007AFF",
                backgroundColor: "#FFFFFF",
                cornerRadius: 12
            ),
            font: SurveyFont(
                fontFamily: "Arial",
                fontColor: "#000000",
                colorType: .manual
            ),
            progress: ProgressStyle(
                color: "#00FF00",
                colorType: .manual,
                enabled: true,
                type: .ball
            ),
            backdrop: Backdrop(
                color: "#000000",
                enabled: true,
                opacity: 50
            )
        )
    }
    
    // Survey as Payload
    static func makeSurveyContentPayload() -> [String: Any] {
        return [
            "surveys": [
                "id": 12,
                "token": "survey:12",
                "type": "step",
                "modules": [
                    [   // Step 1 – Likert
                        "id": 101,
                        "type": "likert_scale",
                        "question": "How satisfied are you with the app?",
                        "is_required": true,
                        "metadata": [
                            "high_score": "Very satisfied",
                            "low_score": "Not at all",
                            "range": 5,
                            "type": "stars"
                        ],
                        "logic": NSNull(),  // no branching logic in this sample
                        "button_label": "Next"
                    ],
                    [   // Step 2 – Open‑text
                        "id": 102,
                        "type": "open_text",
                        "question": "Tell us why you chose that score",
                        "placeholder": "Your feedback…",
                        "is_required": false,
                        "button_label": "Submit"
                    ]
                ],
                "metadata": [
                    "cta_label": "Start survey"
                ],
                "theme_data": [
                    "id": 4,
                    "theme_data": [
                        "button": [
                            "background_color": "#4E4CE8",
                            "border_color": "#4E4CE8",
                            "label_color": "#FFFFFF"
                        ],
                        "colors": [
                            "background_color": "#FFFFFF",
                            "text_color": "#000000",
                            "title_color": "#000000"
                        ],
                        "general": [
                            "font_family": "Default",
                            "content_alignment": "top"
                        ],
                        "progress": [
                            "enabled": true,
                            "color": "#4E4CE8",
                            "color_type": "automatic"
                        ]
                    ]
                ],
                "screens": [],
                "screen_type": "all",
                "locale_code": "default",
                "time_delay": 0
            ]
        ]
    }
    
    // MARK: – NEW: NPS ------------------------------------------------------------------
    
    /// Payload that deserialises into `NPSContentData`.
    static func makeNPSContentPayload() -> [String: Any] {
        return [
            "nps": [
                "locale_code": "en",
                "time_delay": 0,
                "screens": [],
                "screen_type": "all",
                "content": [
                    // ––– Initial 0‑10 score step –––
                    "survey": [
                        "question": "How likely are you to recommend us to a friend?",
                        "key": "nps_score",
                        "low_score": "Not likely",
                        "high_score": "Very likely",
                        "ask_me_later": "Maybe later"
                    ],
                    // ––– Follow‑up open‑text –––
                    "follow_up": [
                        "type": "universal",
                        "update_score": "Change my score",
                        "submit": "Send feedback",
                        "placeholder": "Tell us more …",
                        "close": "Skip",
                        "all": [
                            "question": "Why did you give that score?",
                            "key": "nps_followup"
                        ]
                    ],
                    // ––– Thank‑you screen –––
                    "completed": [
                        "type": "universal",
                        "all": [
                            "header": "Thank you!",
                            "subheader": "Your feedback helps us improve.",
                            "button": [
                                "button_text": "Close",
                                "enabled": true,
                                "button_action": "do_nothing",
                                "deep_link_ios": NSNull()
                            ]
                        ]
                    ]
                ],
                "theme_data": [
                    "main": [
                        "background_color": "#FFFFFF",
                        "primary": "#4E4CE8",
                        "logo": NSNull()
                    ],
                    "text": [
                        "font_color": "#000000",
                        "font_color_type": "automatic",
                        "font_family": "Default"
                    ],
                    "box": [
                        "radius": 12
                    ],
                    "progress_bar": [
                        "enabled": false,
                        "type": "bar",
                        "font_color": NSNull(),
                        "font_color_type": NSNull()
                    ]
                ]
            ]
        ]
    }
}

// swiftlint:enable all
