//
//  UPExperienceQuestionInput.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The typed answer of a survey question: the open-text box or a one-line field.
//

import SwiftUI

/// Open text in the multiline box; a single input in a one-line field, with the dial-code control inside a phone
/// field and the calendar inside a date field, which opens Apple's calendar in a sheet.
internal struct UPExperienceQuestionInput: View {
    let state: ExperienceRenderState
    @ObservedObject var answerModel: SurveyAnswerModel
    let step: SurveyStep
    @SwiftUI.Environment(\.experienceStyle) private var style
    /// Pickers open inline, so they inherit the experience's text size and light or dark style.
    @State private var showsDatePicker = false
    @State private var showsCountryWheel = false
    @State private var selectedDate = Date()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private var answer: SurveyAnswerState { answerModel.value }
    // Typing goes through the text path, which validates without re-measuring the card.
    private var text: SwiftUI.Binding<String> {
        SwiftUI.Binding(
            get: { answerModel.value.text },
            set: { value in state.updateText(for: step) { $0.updateText(value, for: step) } })
    }

    @ViewBuilder
    var body: some View {
        if step.type == .openText {
            UPExperienceTextArea(text: text, placeholder: step.metadata?.placeholder ?? "")
        } else if step.metadata?.inputType == .date {
            dateField
        } else {
            VStack(spacing: UPExperienceLayout.fieldSpacing) {
                field {
                    if step.metadata?.inputType == .phone {
                        UPExperienceCountrySelector(
                            code: answer.countryCode, onSelect: selectCountryCode, onToggleWheel: toggleCountryWheel)
                    }
                    TextField(step.metadata?.placeholder ?? "", text: text)
                        .keyboardType(step.inputKeyboardType)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .experienceFont(style.fontName, size: UPExperienceLayout.bodySize)
                        .foregroundColor(Color(style.text))
                }
                if showsCountryWheel {
                    UPExperienceCountrySelector.wheel(code: answer.countryCode, onSelect: selectCountryCode)
                }
            }
        }
    }

    private var dateField: some View {
        field {
            TextField("dd/mm/yyyy", text: text)
                .keyboardType(.numberPad)
                .experienceFont(style.fontName, size: UPExperienceLayout.bodySize)
                .foregroundColor(Color(style.text))
            Button(action: openDatePicker, label: {
                Image(systemName: "calendar").foregroundColor(Color(style.text))
            }).accessibility(label: Text("Choose date"))
        }
        // Apple's calendar in a sheet with Cancel and OK, as Android opens Material's date dialog.
        .sheet(isPresented: $showsDatePicker) { datePickerSheet }
    }

    /// The bordered one-line field around `content`.
    private func field<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(content: content)
            .padding(UPExperienceLayout.inputPadding)
            .frame(minHeight: UPExperienceLayout.inputMinHeight)
            .overlay(
                RoundedRectangle(cornerRadius: UPExperienceLayout.fieldCornerRadius)
                    .stroke(Color(style.secondaryText), lineWidth: 1))
    }

    private func selectCountryCode(_ code: String) {
        state.updateAnswer(for: step) { $0.countryCode = code }
    }

    /// iOS 13 shows the country wheel under the field; the card is measured again to make room for it.
    private func toggleCountryWheel() {
        showsCountryWheel.toggle()
        state.remeasure()
    }

    private func openDatePicker() {
        // Open on the typed date when there is one.
        selectedDate = Self.dateFormatter.date(from: answer.text) ?? Date()
        showsDatePicker = true
    }

    /// OK writes the picked day; Cancel leaves the answer as it was.
    private var datePickerSheet: some View {
        NavigationView {
            datePicker
                .padding()
                .navigationBarItems(
                    leading: Button("Cancel") { showsDatePicker = false },
                    trailing: Button("OK") {
                        state.updateAnswer(for: step) { $0.text = Self.dateFormatter.string(from: selectedDate) }
                        showsDatePicker = false
                    })
        }
        .accentColor(Color(style.primary))
    }

    /// Apple's calendar on iOS 14+; iOS 13 has only the wheel.
    @ViewBuilder
    private var datePicker: some View {
        if #available(iOS 14.0, *) {
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .labelsHidden()
        } else {
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .labelsHidden()
        }
    }
}
