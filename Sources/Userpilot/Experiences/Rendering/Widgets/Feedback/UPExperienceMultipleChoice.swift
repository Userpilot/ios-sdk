//
//  UPExperienceMultipleChoice.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The choice rows of a multiple-choice survey question, including the Other row and its field.
//

import SwiftUI

/// Single- or multiple-choice rows; a chosen Other row becomes the field its answer is typed in.
internal struct UPExperienceMultipleChoice: View {
    let state: ExperienceRenderState
    @ObservedObject var answerModel: SurveyAnswerModel
    let step: SurveyStep
    let theme: SurveyTheme

    private var answer: SurveyAnswerState { answerModel.value }

    var body: some View {
        VStack(spacing: UPExperienceLayout.choiceSpacing) {
            ForEach((step.metadata?.choices ?? []).indices, id: \.self) { index in
                choiceButton(index, title: step.metadata?.choices?[index].value ?? "")
            }
            // "Other" takes the index after the last authored choice; once picked, its row is where the answer is
            // typed.
            if step.metadata?.otherChoice?.enabled == true {
                let other = step.metadata?.choices?.count ?? 0
                if answer.selectedChoices.contains(other) {
                    otherField(other)
                } else {
                    choiceButton(other, title: "Other")
                }
            }
        }
    }

    private func choiceButton(_ index: Int, title: String) -> some View {
        let selected = answer.selectedChoices.contains(index)
        return Button(
            action: { toggleChoice(index) },
            label: {
                choiceRow(selected) {
                    // Decorative: VoiceOver gets the selected trait instead.
                    Image(systemName: choiceIcon(selected))
                        .foregroundColor(Color(selected ? theme.primaryColor : theme.textSecondaryColor))
                        .accessibility(hidden: true)
                    UPExperienceText(
                        text: title, color: theme.textColor, fontFamily: theme.fontFamily,
                        size: UPExperienceLayout.bodySize)
                }
            }
        )
        .buttonStyle(PlainButtonStyle())
        .accessibility(addTraits: selected ? .isSelected : [])
    }

    /// The picked Other row: its mark unpicks it, and the field takes the title's place and opens the keyboard.
    private func otherField(_ index: Int) -> some View {
        choiceRow(true) {
            Button(action: { toggleChoice(index) }, label: {
                Image(systemName: choiceIcon(true)).foregroundColor(Color(theme.primaryColor))
            })
            .buttonStyle(PlainButtonStyle())
            .accessibility(label: Text("Other"))
            .accessibility(addTraits: .isSelected)
            UPExperienceOtherField(
                text: SwiftUI.Binding(
                    get: { answerModel.value.otherText },
                    set: { value in state.updateText(for: step) { $0.otherText = value } }),
                placeholder: step.metadata?.otherChoice?.placeholder ?? "",
                color: theme.textColor, placeholderColor: theme.textSecondaryColorAlpha80,
                fontFamily: theme.fontFamily)
        }
    }

    private func toggleChoice(_ index: Int) {
        state.updateAnswer(for: step) { $0.toggleChoice(index, for: step) }
    }

    /// A bordered choice row: the primary color marks the chosen ones.
    private func choiceRow<Content: View>(_ selected: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: UPExperienceLayout.inputPadding, content: content)
            .padding(UPExperienceLayout.inputPadding)
            .frame(maxWidth: .infinity, minHeight: UPExperienceLayout.choiceMinHeight)
            .background(Color(theme.primaryColor).opacity(selected ? 0.1 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: UPExperienceLayout.fieldCornerRadius)
                    .stroke(Color(selected ? theme.primaryColor : theme.textSecondaryColor), lineWidth: 1))
    }

    /// Checkboxes for multi-select, radio buttons for single-select.
    private func choiceIcon(_ selected: Bool) -> String {
        if step.metadata?.isMultiSelect == true { return selected ? "checkmark.square.fill" : "square" }
        return selected ? "largecircle.fill.circle" : "circle"
    }
}

/// The Other answer, typed where the option's title was. A plain `UITextField`, so it can take focus and open the
/// keyboard as soon as Other is picked, on iOS 13 too.
private struct UPExperienceOtherField: UIViewRepresentable {
    @SwiftUI.Binding var text: String
    let placeholder: String
    let color: UIColor
    let placeholderColor: UIColor
    let fontFamily: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        // Answers are sent exactly as typed.
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .done
        // Fill the row beside the mark rather than growing with the text.
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // Once the row is on screen.
        performOn(.main) { [weak field] in field?.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        // Only write back a real change, so the cursor doesn't jump while typing.
        if field.text != text { field.text = text }
        let font = ExperienceFonts.font(
            family: fontFamily, size: UPExperienceLayout.bodySize, category: context.environment.sizeCategory)
        field.font = font
        field.textColor = color
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder, attributes: [.foregroundColor: placeholderColor, .font: font])
        field.textAlignment = context.environment.layoutDirection == .rightToLeft ? .right : .left
        // VoiceOver reads the placeholder as the field's name.
        field.accessibilityLabel = placeholder
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: UPExperienceOtherField
        init(_ parent: UPExperienceOtherField) { self.parent = parent }
        @objc func textChanged(_ field: UITextField) { parent.text = field.text ?? "" }
        func textFieldShouldReturn(_ field: UITextField) -> Bool { field.resignFirstResponder() }
    }
}
