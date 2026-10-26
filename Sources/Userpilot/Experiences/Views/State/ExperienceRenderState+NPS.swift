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

    var followUp: FollowUpQuestion? {
        guard let followUp = npsContent?.content.followUp else { return nil }
        // One question for everyone, or one per category. Scores are stored 1–11 for the shown 0–10:
        // 0–6 detractors, 7–8 passives, 9–10 promoters.
        if followUp.type == .universal, let all = followUp.all { return all }
        switch npsScore {
        case 1...7: return followUp.detractors
        case 8...9: return followUp.passives
        default: return followUp.promoters
        }
    }

    var completedData: CompletedData? {
        guard let completed = npsContent?.content.completed else { return nil }
        // Same category split as the follow-up question.
        if completed.type == .universal, let all = completed.all { return all }
        switch npsScore {
        case 1...7: return completed.detractors
        case 8...9: return completed.passives
        default: return completed.promoters
        }
    }

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
