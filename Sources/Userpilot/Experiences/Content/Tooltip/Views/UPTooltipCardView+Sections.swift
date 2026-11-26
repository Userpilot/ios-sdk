//
//  UPTooltipCardView+Sections.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Builds the fixed tooltip body using the shared experience components.
//

import UIKit

internal extension UPTooltipCardView {
    /// Keeps title/body/action in a stable order and never creates media or extra CTA rows.
    func bindContent(_ content: TooltipContent, theme: ExperienceTheme) {
        if let title = content.title {
            let view = UPTextView()
            view.setupView(line: title, theme: theme)
            sectionsStackView.addArrangedSubview(view)
        }
        if !content.body.isEmpty {
            let view = UPTextContainerView()
            view.setupView(lines: content.body, theme: theme)
            sectionsStackView.addArrangedSubview(view)
        }
        if let line = content.button {
            let button = UPButtonView()
            button.setupViews(line: line, action: content.buttonAction, theme: theme) { [weak self] action in
                self?.onAction?(action)
            }
            sectionsStackView.addArrangedSubview(button)
        }
    }
}
