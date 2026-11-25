//
//  TooltipViewModel+Presentation.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Selects the current step and its merged theme without changing paging semantics.
//

import UIKit

// MARK: - Presentation Configuration

internal extension TooltipViewModel {

    // MARK: Theme

    /// Merged theme for the step showing now.
    ///
    /// `mergedTheme` holds one entry per step in raw payload order, but the segment
    /// pages through `tooltipSteps`, which is sorted by `order`. Indexing
    /// `mergedTheme` with `currentStepIndex` would therefore borrow another step's
    /// theme whenever the two orders disagree, so the current step is mapped back
    /// to its payload slot first.
    ///
    /// The slot is found by `(id, order)` plus occurrence rank, not `id` alone:
    /// ids come from the backend and may repeat, but the sort is stable on payload
    /// offset, so the n-th step with a given `(id, order)` in paging order is the
    /// n-th one in payload order. Every page therefore resolves its own slot even
    /// for a malformed payload. Reads the `tooltip` branch, never `slideOut` — see
    /// `ThemeData.tooltip`. Anything missing or out of range falls back to the
    /// first step's theme, then to an empty theme whose accessors supply defaults.
    var tooltipTheme: ExperienceTheme {
        let fallback = mergedTheme.first?.tooltip ?? ExperienceTheme()
        guard let current = currentTooltipStep,
              let payload = flowContent?.steps else { return fallback }
        let matches: (Step) -> Bool = { $0.id == current.id && $0.order == current.order }
        let rank = tooltipSteps.prefix(currentStepIndex).filter(matches).count
        let slots = payload.indices.filter { matches(payload[$0]) }
        guard let slot = slots[safe: rank],
              let theme = mergedTheme[safe: slot]?.tooltip else { return fallback }
        return theme
    }

    // MARK: Steps

    /// The step showing now; nil until content is bound.
    var currentTooltipStep: Step? {
        tooltipSteps[safe: currentStepIndex]
    }

    /// Whether the step showing now is the last one this presentation shows; `>=` so a shortened segment
    /// still ends. The overlay closes after it and the publisher continues the walk.
    var isLastStepOfSegment: Bool {
        currentStepIndex >= tooltipSteps.count - 1
    }

    /// The card's 0-based progress index: the step's `position - 1`, else the segment index.
    var progressStepIndex: Int {
        currentTooltipStep?.position.map { $0 - 1 } ?? currentStepIndex
    }

    /// The card's progress total: the Flow's `steps_count`, else the segment's size.
    var progressStepsCount: Int {
        flowSegment?.stepsCount ?? tooltipSteps.count
    }

    /// Which element to anchor to, and how hard to try.
    ///
    /// Reads the *current* step, so each step of a segment anchors to its own
    /// element rather than the first step's.
    var targeting: StepTargeting? {
        currentTooltipStep?.targeting
    }

    /// How the card is drawn relative to that element.
    var presentation: StepPresentation? {
        currentTooltipStep?.presentation
    }

    /// The selector to resolve, when the step's target carries a usable one.
    var selector: ElementSelector? {
        targeting?.selector
    }

}
