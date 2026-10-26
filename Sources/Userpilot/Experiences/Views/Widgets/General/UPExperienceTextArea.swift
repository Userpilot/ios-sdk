//
//  UPExperienceTextArea.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Multiline input: a plain UITextView inside SwiftUI chrome; answers and limits stay in presentation state.
//

import SwiftUI

/// A visible placeholder does not become the answer or overwrite a focused text view.
internal struct UPExperienceTextArea: View {
    @SwiftUI.Environment(\.sizeCategory) private var sizeCategory
    @SwiftUI.Binding var text: String
    let textColor: UIColor
    let placeholderColor: UIColor
    let fontFamily: String?
    let placeholder: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ZStack(alignment: .topLeading) {
                UPExperienceTextView(
                    text: $text, color: textColor, placeholder: placeholder,
                    font: UPExperienceStyle.font(
                        family: fontFamily, size: UPExperienceLayout.bodySize, category: sizeCategory))
                if text.isEmpty {
                    // The text view's own label already carries the placeholder.
                    UPExperienceText(
                        text: placeholder, color: placeholderColor, fontFamily: fontFamily,
                        size: UPExperienceLayout.bodySize
                    )
                    .accessibility(hidden: true)
                    // Taps pass through to the text view underneath.
                    .padding(12).allowsHitTesting(false)
                }
            }
            // Fixed height that grows only with text size, so typing never resizes the card.
            .frame(height: UPExperienceStyle.scaledSize(120, for: sizeCategory))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(
                Color(ThemeHandler.DefaultValues.grayColor), lineWidth: 1))
            Text("\(text.count)/500")
                .experienceFont(fontFamily, size: UPExperienceLayout.footnoteSize)
                .foregroundColor(Color(placeholderColor))
        }
    }
}

/// iOS 13 has no multiline SwiftUI input, so this is a plain `UITextView` on every OS.
/// Its font comes from the shared resolver.
private struct UPExperienceTextView: UIViewRepresentable {
    @SwiftUI.Binding var text: String
    let color: UIColor
    let placeholder: String
    let font: UIFont

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        // Answers are sent exactly as typed: no autocorrect or smart punctuation.
        view.autocorrectionType = .no
        view.spellCheckingType = .no
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.autocapitalizationType = .none
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        // Only write back a real change, so the cursor doesn't jump while typing.
        if view.text != text { view.text = text }
        view.semanticContentAttribute =
            context.environment.layoutDirection == .rightToLeft
            ? .forceRightToLeft : .forceLeftToRight
        view.textAlignment = context.environment.layoutDirection == .rightToLeft ? .right : .left
        view.textColor = color
        view.font = font
        // VoiceOver reads the placeholder as the field's name.
        view.accessibilityLabel = placeholder
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: UPExperienceTextView
        init(_ parent: UPExperienceTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }
}
