//
//  NPSContent.swift
//  Userpilot
//
//  Created by Motasem Hamed on 09/02/2025.
//

import Foundation
import UIKit

// MARK: - NPSContentData
internal struct NPSContentData: Decodable {
    let npsContent: NPSContent

    enum CodingKeys: String, CodingKey {
        case npsContent = "nps"
    }
}

// MARK: - NPSContent
internal struct NPSContent: Decodable {
    let localeCode: String
    let timeDelay: Int
    let content: NPSStep
    let npsTheme: NPSTheme
    let screens: [String]
    let screenType: ScreenType

    private enum CodingKeys: String, CodingKey {
        case content, screens
        case npsTheme = "theme_data"
        case screenType = "screen_type"
        case localeCode = "locale_code"
        case timeDelay = "time_delay"
    }

    var isForAllScreens: Bool {
        return screenType == .all
    }

    var delayDuration: TimeInterval {
        return TimeInterval(timeDelay) * 1000
    }
}

// MARK: - NPSStep
internal struct NPSStep: Decodable {
    let survey: Survey
    let followUp: FollowUp
    let completed: Completed

    private enum CodingKeys: String, CodingKey {
        case survey, completed
        case followUp = "follow_up"
    }
}

// MARK: - Survey
internal struct Survey: Decodable {
    let question: String?
    let key: String?
    let lowScore: String?
    let highScore: String?
    let askMeLater: String?

    private enum CodingKeys: String, CodingKey {
        case question, key
        case lowScore = "low_score"
        case highScore = "high_score"
        case askMeLater = "ask_me_later"
    }
}

// MARK: - FollowUp
internal struct FollowUp: Decodable {
    let type: NPSStepType
    let updateScore: String?
    let submit: String?
    let placeholder: String?
    let close: String?
    let all: FollowUpQuestion?
    let detractors: FollowUpQuestion?
    let passives: FollowUpQuestion?
    let promoters: FollowUpQuestion?

    private enum CodingKeys: String, CodingKey {
        case type, submit, placeholder, close, all, detractors, passives, promoters
        case updateScore = "update_score"
    }
}

// MARK: - FollowUpQuestion
internal struct FollowUpQuestion: Decodable {
    let question: String?
    let key: String
}

// MARK: - Completed
internal struct Completed: Decodable {
    let all: CompletedData?
    let detractors: CompletedData?
    let passives: CompletedData?
    let promoters: CompletedData?
    let type: NPSStepType
}

// MARK: - CompletedData
internal struct CompletedData: Decodable {
    let header: String?
    let subheader: String?
    let button: ButtonData
}

// MARK: - ButtonData
internal struct ButtonData: Decodable {
    let buttonText: String?
    let close: String?
    let enabled: Bool
    let iosDeepLink: String?
    let buttonAction: ButtonActionType?

    enum CodingKeys: String, CodingKey {
        case buttonAction = "button_action"
        case buttonText = "button_text"
        case close, enabled
        case iosDeepLink = "ios_deep_link"
    }
}

// MARK: - NPSTheme
internal struct NPSTheme: Decodable {
    let general: NPSThemeGeneral?
    let font: NPSThemeText?
    let box: NPSThemeBox?
    let progress: ProgressBarTheme?

    enum CodingKeys: String, CodingKey {
        case general = "main"
        case font = "text"
        case box
        case progress = "progress_bar"
    }

    var logo: String? {
        return general?.logo
    }

    // Computed Properties
    var backgroundColor: UIColor {
        general?.backgroundColor?.color ?? .white
    }

    var backgroundColorAsString: String {
        general?.backgroundColor ?? "#ffffff"
    }

    var primaryColor: UIColor {
        general?.primary?.color ?? .black
    }

    var primaryColorAsString: String {
        general?.primary ?? "#000000"
    }

    var secondaryColor: UIColor {
        primaryColor.withAlphaComponent(0.2)
    }

    var textColor: UIColor {
        if font?.colorType == .manual {
            font?.fontColor?.color ?? .black
        } else {
            backgroundColorAsString.invertColor().color
        }
    }

    var textSecondaryColorAlpha80: UIColor {
        textColor.withAlphaComponent(0.8)
    }

    var fontFamily: String? {
        font?.fontFamily
    }

    // progress
    var isStepsProgressEnabled: Bool {
        progress?.enabled ?? false
    }

    var isStepsProgressColorManual: Bool {
        progress?.colorType == .manual
    }

    var isStepsProgressBallType: Bool {
        progress?.type == .ball
    }

    var stepsProgressColor: UIColor {
        progress?.color?.color ?? .black
    }

    var stepsProgressColorAsString: String {
        progress?.color ?? ThemeHandler.DefaultValues.blackColor
    }

}

// MARK: - NPSThemeGeneral
internal struct NPSThemeGeneral: Decodable {
    let backgroundColor: String?
    let logo: String?
    let primary: String?

    enum CodingKeys: String, CodingKey {
        case logo, primary
        case backgroundColor = "background_color"
    }
}

// MARK: - NPSThemeText
internal struct NPSThemeText: Decodable {
    let fontColor: String?
    let colorType: ColorType?
    let fontFamily: String?

    enum CodingKeys: String, CodingKey {
        case fontColor = "font_color"
        case colorType = "font_color_type"
        case fontFamily = "font_family"
    }

}

internal struct ProgressBarTheme: Decodable {
    let enabled: Bool?
    let color: String?
    let colorType: ColorType?
    let type: ProgressStyleType?

    private enum CodingKeys: String, CodingKey {
        case enabled, type
        case color = "font_color"
        case colorType = "font_color_type"
    }
}

// MARK: - NPSThemeBox
internal struct NPSThemeBox: Decodable {
    let color: String
    let enabled: Bool
    let intensity: Int
    let radius: Int
    let type: String
    let width: Int
}

// MARK: - Enums
internal enum NPSStepType: String, Decodable {
    case universal
    case scoreBased = "score_based"
}

// MARK: - String Extension for JSON Deserialization

internal extension String {
    /// Converts a JSON string into a `NPSContentData` object using `JSONDecoder`.
    func toNPSContent() -> NPSContentData? {
        if let surveyContent: NPSContentData = self.toObject() {
            return surveyContent
        } else {
            return nil
        }
    }
}
