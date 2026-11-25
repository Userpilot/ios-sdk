//
//  FlowContent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/09/2024.
//  Copyright © 2021 Userpilot. All rights reserved.
//
//  Represents a Flow, carousel or slideout experience and its steps.
//

import Foundation
import UIKit

// MARK: - FlowContentData

/// Wraps the `mobile_contents` object of a screen reply or a server push.
internal struct FlowContentData: Codable {
    // A response can contain another content type; absence is not a decoding failure.
    let flowContent: FlowContent?

    private enum CodingKeys: String, CodingKey {
        case flowContent = "mobile_contents"
    }
}

/// One `mobile_contents` payload: a carousel, a slideout, or a Flow's steps for the current screen.
internal struct FlowContent: Codable {
    let id: Int

    /// `flow` on the wire for a Flow; `FlowWalk` projects each segment onto `carousel`, `slideout` or `tooltip`.
    let type: ContentType
    let steps: [Step]
    let mobileTheme: ContentMobileTheme
    let screens: [String]
    let screenType: ScreenType
    let localeCode: String

    /// How many steps the whole Flow has; `steps` holds only the current screen's steps.
    /// Flows only; the server owns progress, so this never counts the payload.
    let stepsCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, type, steps
        case mobileTheme = "theme_data"
        case screens
        case screenType = "screen_type"
        case localeCode = "locale_code"
        case stepsCount = "steps_count"
    }

    /// Builds content directly, for fixtures and internal callers.
    ///
    /// Declared explicitly so the Flow-only `stepsCount` defaults to `nil`; see `Step.init`.
    init(
        id: Int,
        type: ContentType,
        steps: [Step],
        mobileTheme: ContentMobileTheme,
        screens: [String],
        screenType: ScreenType,
        localeCode: String,
        stepsCount: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.steps = steps
        self.mobileTheme = mobileTheme
        self.screens = screens
        self.screenType = screenType
        self.localeCode = localeCode
        self.stepsCount = stepsCount
    }

    // General
    var baseThemeId: Int {
        mobileTheme.id
    }
    // General
    var isForAllScreens: Bool {
        screenType == .all
    }

    /// `true` for a Flow segment's tooltip projection (see `FlowWalk`).
    var isTooltip: Bool {
        type == .tooltip
    }

    /// A tooltip segment's steps in author order, or `nil` when this content is not a
    /// renderable tooltip (another type, or no steps).
    ///
    /// Callers should log the rejection; this stays a pure accessor so it can be
    /// read from anywhere without a logger in hand.
    ///
    /// **This is the one place step ordering is established.** `Step.order` is
    /// decoded but no other consumer reads it — every call site uses the array
    /// index. With one step that was harmless; with several, trusting array order
    /// would silently reorder a tour whenever the backend serialised it
    /// differently. `sorted(by:)` is not guaranteed stable, so the original offset
    /// is folded into the comparison to keep duplicate `order` values in payload
    /// order.
    var tooltipSteps: [Step]? {
        guard isTooltip, !steps.isEmpty else { return nil }
        return steps.enumerated()
            .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }
            .map(\.element)
    }

}

extension FlowContent {

    /// Decodes every wire key as the synthesized decoder would, then rejects a Flow with a step whose `position`
    /// is missing, below 1, or past `steps_count` when the Flow has one. The throw drops the whole Flow candidate,
    /// like an unknown enum value. A screen's steps can sit at positions 3...4 of 4, so the payload's own
    /// step count is never the bound. A preview response skips the rule (`PreviewExperience.decode(from:)`).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        let steps = try container.decode([Step].self, forKey: .steps)
        let stepsCount = try container.decodeIfPresent(Int.self, forKey: .stepsCount)
        if type == .flow, !decoder.decodesPreviewContent,
           steps.contains(where: { !$0.hasValidPosition(stepsCount: stepsCount) }) {
            throw DecodingError.dataCorruptedError(
                forKey: .steps, in: container, debugDescription: "Flow step needs a position from 1 to steps_count"
            )
        }
        self.init(
            id: try container.decode(Int.self, forKey: .id),
            type: type,
            steps: steps,
            mobileTheme: try container.decode(ContentMobileTheme.self, forKey: .mobileTheme),
            screens: try container.decode([String].self, forKey: .screens),
            screenType: try container.decode(ScreenType.self, forKey: .screenType),
            localeCode: try container.decode(String.self, forKey: .localeCode),
            stepsCount: stepsCount
        )
    }
}

internal extension FlowContent {
    /// A Flow slideout step's `settings.position` decides first (`bottom` → sheet, `center` → dialog); then a
    /// resolved app theme, then the embedded alignment, then the cached theme's dialog flag.
    func isBottomSheet(using themes: ThemeHandling) -> Bool {
        switch steps.first?.settings?.position {
        case .bottom: return true
        case .center: return false
        default: break
        }
        if let appTheme = themes.appTheme {
            return !appTheme.isDialogExperience
        }
        if let alignment = mobileTheme.themeData?.general?.contentAlignment {
            return alignment == .bottom
        }
        return themes.getThemeById(mobileTheme.id)?.isDialogExperience == false
    }
}

// MARK: - Configuration

/// The backend sends `theme_id` and `id` with one value; reading `id` matches Android and `SurveyMobileTheme`.
internal struct ContentMobileTheme: Codable {
    let id: Int
    let themeData: ExperienceTheme?

    private enum CodingKeys: String, CodingKey {
        case id
        case themeData = "theme_data"
    }
}

// MARK: - String Extension for JSON Deserialization

internal extension String {
    /// Converts a JSON string into a `FlowContentData`; a failure is logged through `logger` and returns `nil`,
    /// as does a reply without `mobile_contents`. A tooltip step without a selector identity, a Flow step
    /// without a valid `position`, or a `tooltip` type fails the same way as an unknown enum value: the whole
    /// content is dropped.
    func toFlowContent(logger: Logging? = nil) -> FlowContentData? {
        let data: FlowContentData? = toObject(logger: logger)
        return data?.flowContent == nil ? nil : data
    }
}
