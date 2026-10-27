//
//  UPExperienceSurveyQuestion.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Maps survey modules to reusable SwiftUI controls backed by explicit answer state.
//

import SwiftUI

/// Observes only its own answer, so typing in one question doesn't redraw the others.
internal struct UPExperienceSurveyQuestion: View {
    let state: ExperienceRenderState
    @ObservedObject var answerModel: SurveyAnswerModel
    let step: SurveyStep
    let theme: SurveyTheme
    let width: CGFloat
    /// Pickers open inline, so they inherit the experience's text size and light or dark style.
    @State private var showsDatePicker = false
    @State private var showsCountryWheel = false
    @State private var selectedDate = Date()
    @State private var selectedCountry: Int?

    private static let countries = loadJSONFile(named: "countries", as: [CountryEntity].self) ?? []
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

    var body: some View {
        // Spaced as on Android: title, description just under it, then the answer control.
        VStack(alignment: .leading, spacing: 0) {
            // Required questions are marked with a red asterisk.
            UPExperienceText(
                text: step.question ?? "",
                color: theme.textColor, fontFamily: theme.fontFamily,
                size: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize), bold: true,
                suffix: step.isRequired == true ? " *" : "")
            if let subtitle = step.subheader, !subtitle.isEmpty {
                UPExperienceText(
                    text: subtitle, color: theme.textColor, fontFamily: theme.fontFamily,
                    size: CGFloat(ThemeHandler.DefaultValues.surveyDescriptionTextSize))
                    .padding(.top, UPExperienceLayout.titleSpacing)
            }
            control
                .padding(.top, UPExperienceLayout.controlSpacing)
        }
    }

    @ViewBuilder
    private var control: some View {
        switch step.type {
        case .likert:
            VStack(spacing: UPExperienceLayout.scaleLabelSpacing) {
                UPExperienceRating(
                    items: step.ratingItems, selected: answer.rating,
                    primary: theme.primaryColor, textColor: theme.textColor,
                    fontFamily: theme.fontFamily, width: width
                ) { rating in
                    state.updateAnswer(for: step) { $0.rating = rating }
                }
                // Low and high score labels under the scale's two ends.
                HStack(alignment: .top) {
                    UPExperienceText(
                        text: step.metadata?.lowScore ?? "", color: theme.textColor, fontFamily: theme.fontFamily,
                        size: UPExperienceLayout.footnoteSize)
                    UPExperienceText(
                        text: step.metadata?.highScore ?? "", color: theme.textColor, fontFamily: theme.fontFamily,
                        size: UPExperienceLayout.footnoteSize, alignment: .trailing)
                }
            }
        case .multipleChoice: choices
        case .openText:
            UPExperienceTextArea(
                text: text, textColor: theme.textColor, placeholderColor: theme.textSecondaryColorAlpha80,
                fontFamily: theme.fontFamily, placeholder: step.metadata?.placeholder ?? "")
        case .singleInput: singleInput
        case .completed: EmptyView()
        }
    }

    private var choices: some View {
        VStack(spacing: UPExperienceLayout.choiceSpacing) {
            ForEach((step.metadata?.choices ?? []).indices, id: \.self) { index in
                choiceButton(index, title: step.metadata?.choices?[index].value ?? "")
            }
            // "Other" takes the index after the last authored choice; picking it reveals a text field.
            if step.metadata?.otherChoice?.enabled == true {
                choiceButton(step.metadata?.choices?.count ?? 0, title: "Other")
                if answer.selectedChoices.contains(step.metadata?.choices?.count ?? 0) {
                    TextField(
                        step.metadata?.otherChoice?.placeholder ?? "",
                        text: SwiftUI.Binding(
                            get: { answerModel.value.otherText },
                            set: { value in state.updateText(for: step) { $0.otherText = value } })
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .experienceFont(theme.fontFamily, size: UPExperienceLayout.bodySize)
                    .foregroundColor(Color(theme.textColor))
                }
            }
        }
    }

    private func choiceButton(_ index: Int, title: String) -> some View {
        let selected = answer.selectedChoices.contains(index)
        return Button(
            action: { state.updateAnswer(for: step) { $0.toggleChoice(index, for: step) } },
            label: {
                HStack(spacing: 12) {
                    // Decorative: VoiceOver gets the selected trait instead.
                    Image(systemName: choiceIcon(selected))
                        .foregroundColor(Color(selected ? theme.primaryColor : theme.textSecondaryColor))
                        .accessibility(hidden: true)
                    UPExperienceText(text: title, color: theme.textColor, fontFamily: theme.fontFamily, size: 16)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color(theme.primaryColor).opacity(selected ? 0.1 : 0))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(selected ? theme.primaryColor : theme.textSecondaryColor), lineWidth: 1))
            }
        )
        .buttonStyle(PlainButtonStyle())
        .accessibility(addTraits: selected ? .isSelected : [])
    }

    // Checkboxes for multi-select, radio buttons for single-select.
    private func choiceIcon(_ selected: Bool) -> String {
        if step.metadata?.isMultiSelect == true { return selected ? "checkmark.square.fill" : "square" }
        return selected ? "largecircle.fill.circle" : "circle"
    }

    @ViewBuilder
    private var singleInput: some View {
        if step.metadata?.inputType == .date {
            HStack {
                TextField("dd/mm/yyyy", text: text)
                    .keyboardType(.numberPad)
                    .experienceFont(theme.fontFamily, size: UPExperienceLayout.bodySize)
                    .foregroundColor(Color(theme.textColor))
                Button(action: openDatePicker, label: {
                    Image(systemName: "calendar").foregroundColor(Color(theme.textColor))
                }).accessibility(label: Text("Choose date"))
            }
            .padding(12)
            .frame(minHeight: 50)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(theme.textSecondaryColor), lineWidth: 1))
            // Apple's calendar in a sheet with Cancel and OK, as Android opens Material's date dialog.
            .sheet(isPresented: $showsDatePicker) { datePickerSheet }
        } else {
            VStack(spacing: UPExperienceLayout.fieldSpacing) {
                HStack {
                    if step.metadata?.inputType == .phone { countryCodeButton }
                    TextField(step.metadata?.placeholder ?? "", text: text)
                        .keyboardType(step.inputKeyboardType)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .experienceFont(theme.fontFamily, size: UPExperienceLayout.bodySize)
                        .foregroundColor(Color(theme.textColor))
                }
                .padding(12)
                .frame(minHeight: 50)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(theme.textSecondaryColor), lineWidth: 1))
                if showsCountryWheel { countryPicker }
            }
        }
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
        .accentColor(Color(theme.primaryColor))
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

    private var countryIndex: SwiftUI.Binding<Int> {
        SwiftUI.Binding(
            // Several countries share a dial code, so remember the exact row the user picked.
            get: {
                selectedCountry ?? Self.countries.firstIndex { $0.dialCode == answerModel.value.countryCode } ?? 0
            },
            set: { index in
                guard let country = Self.countries[safe: index] else { return }
                selectedCountry = index
                state.updateAnswer(for: step) { $0.countryCode = country.dialCode }
            })
    }

    /// A SwiftUI dropdown (`Menu` with a checkmarked `Picker`) on iOS 14+; iOS 13 opens a wheel below the field.
    @ViewBuilder
    private var countryCodeButton: some View {
        let label = Text(answer.countryCode + " ▾")
            .experienceFont(theme.fontFamily, size: UPExperienceLayout.bodySize)
            .foregroundColor(Color(theme.textColor))
        if #available(iOS 14.0, *) {
            Menu(content: { countryPicker }, label: { label })
                .accentColor(Color(theme.textColor))
                .accessibility(label: Text("Country code"))
        } else {
            Button(
                action: {
                    showsCountryWheel.toggle()
                    state.remeasure()
                },
                label: { label }
            ).accessibility(label: Text("Country code"))
        }
    }

    private var countryPicker: some View {
        SwiftUI.Picker(selection: countryIndex, label: Text("Country")) {
            ForEach(Self.countries.indices, id: \.self) { index in
                let country = Self.countries[index]
                Text(country.flag + " " + country.name + " " + country.dialCode).tag(index)
            }
        }
        .labelsHidden()
    }
}
