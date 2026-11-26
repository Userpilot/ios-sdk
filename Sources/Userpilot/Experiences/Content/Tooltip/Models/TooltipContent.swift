//
//  TooltipContent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 19/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Selects the supported tooltip text and single action from the decoded step.
//

import Foundation

/// A fixed card layout: optional title, body paragraphs and at most one action.
/// Rich-text lines stay intact so the existing text/button components retain their formatting.
internal struct TooltipContent {
    let title: Line?
    let body: [Line]
    let button: Line?
    let buttonAction: ButtonAction?

    init(step: Step) {
        let lines = step.sections.flatMap { $0.lines }
        title = lines.first { $0.type == .heading }
        body = lines.filter { $0.type == .paragraph }
        button = lines.first { $0.type == .button }
        buttonAction = step.buttonAction
    }
}
