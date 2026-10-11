//
//  UPExperienceInput.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Bridges multiline text editing while keeping answers and validation in presentation state.
//

import SwiftUI

/// UITextView remains necessary for multiline editing on the supported iOS 13 baseline.
internal struct UPExperienceInput: UIViewRepresentable {
    @SwiftUI.Binding var text: String
    let color: UIColor
    let fontFamily: String?
    let placeholder: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        view.disableAutoCorrect()
        view.layer.borderWidth = 1
        view.layer.borderColor = ThemeHandler.DefaultValues.grayColor.cgColor
        view.layer.cornerRadius = 8
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text { view.text = text }
        view.semanticContentAttribute =
            context.environment.layoutDirection == .rightToLeft
            ? .forceRightToLeft : .forceLeftToRight
        view.textAlignment = context.environment.layoutDirection == .rightToLeft ? .right : .left
        view.textColor = color
        view.font = UIFont.matching(fontName: fontFamily, fontWeight: [], fontSize: 16)
        view.accessibilityLabel = placeholder
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: UPExperienceInput
        init(_ parent: UPExperienceInput) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }
}

/// A visible placeholder does not become the answer or overwrite a focused text view.
internal struct UPExperienceTextArea: View {
    @SwiftUI.Binding var text: String
    let theme: SurveyTheme
    let placeholder: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ZStack(alignment: .topLeading) {
                UPExperienceInput(
                    text: $text, color: theme.textColor, fontFamily: theme.fontFamily,
                    placeholder: placeholder)
                if text.isEmpty {
                    UPExperienceText(
                        text: placeholder, color: theme.textSecondaryColorAlpha80,
                        fontFamily: theme.fontFamily, size: 16
                    )
                    .padding(12).allowsHitTesting(false)
                }
            }
            .frame(height: 120)
            Text("\(text.count)/500")
                .font(.footnote).foregroundColor(Color(theme.textSecondaryColorAlpha80))
        }
    }
}
