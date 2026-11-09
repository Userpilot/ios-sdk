//
//  ExperienceRenderState+NPS.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Keeps NPS score, follow-up and completion selection independent of SwiftUI view identity.
//

import Foundation

extension ExperienceRenderState {
    var npsContent: NPSContent? {
        guard case .nps(let model) = content else { return nil }
        return model.npsContent
    }

    /// The follow-up question for the chosen score.
    var followUp: FollowUpQuestion? { npsContent?.followUp(forSelection: npsScore) }

    /// The closing message for the chosen score.
    var completedData: CompletedData? { npsContent?.completed(forSelection: npsScore) }

    func selectNPSScore(_ score: Int) {
        guard !isClosing, (1...11).contains(score) else { return }
        npsScore = score
        // Stages: 0 score, 1 follow-up feedback, 2 thank-you.
        npsStep = 1
        refresh()
    }

    // "Change score" goes back to the score stage, keeping the typed feedback.
    func updateNPSScore() {
        guard !isClosing else { return }
        npsStep = 0
        refresh()
    }

    func submitNPS(showCompletion: Bool = true, includeFeedback: Bool = true) {
        guard !isClosing, npsStep == 1, case .nps(let model) = content else { return }
        model.onNPSSubmitted(npsScore, followUp?.key ?? "", includeFeedback ? npsFeedback : "")
        npsStep = 2
        // Show the thank-you stage when the content has one; otherwise close straight away.
        if showCompletion, completedData != nil { refresh() } else { close() }
    }

    func finishNPS() {
        guard !isClosing, case .nps(let model) = content else { return }
        let completed = completedData
        close { [weak model] in model?.endNPS(completed) }
    }
}
