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
        if followUp.type == .universal, let all = followUp.all { return all }
        switch npsScore {
        case 1...7: return followUp.detractors
        case 8...9: return followUp.passives
        default: return followUp.promoters
        }
    }

    var completedData: CompletedData? {
        guard let completed = npsContent?.content.completed else { return nil }
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
        npsStep = 1
        refresh()
    }

    func updateNPSScore() {
        guard !isClosing else { return }
        npsStep = 0
        refresh()
    }

    func submitNPS(showCompletion: Bool = true, includeFeedback: Bool = true) {
        guard !isClosing, npsStep == 1, case .nps(let model) = content else { return }
        model.onNPSSubmitted(npsScore, followUp?.key ?? "", includeFeedback ? npsFeedback : "")
        npsStep = 2
        if showCompletion, completedData != nil { refresh() } else { close() }
    }

    func finishNPS() {
        guard !isClosing, case .nps(let model) = content else { return }
        let completed = completedData
        close { [weak model] in model?.endNPS(completed) }
    }
}
