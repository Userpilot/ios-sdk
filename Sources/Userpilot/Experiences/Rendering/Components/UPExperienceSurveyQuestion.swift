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

internal struct UPExperienceSurveyQuestion: View {
    @ObservedObject var state: ExperienceRenderState
    let step: SurveyStep
    let theme: SurveyTheme
    let width: CGFloat
    private enum Picker: String, Identifiable {
        case date, country
        var id: String { rawValue }
    }
    @State private var presentedPicker: Picker?
    @State private var selectedDate = Date()

    private var answer: SurveyAnswerState { state.answer(for: step) }
    private var text: SwiftUI.Binding<String> {
        SwiftUI.Binding(
            get: { state.answer(for: step).text },
            set: { value in state.updateAnswer(for: step) { $0.updateText(value, for: step) } })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UPExperienceLayout.spacing) {
            UPExperienceText(
                text: (step.question ?? "") + (step.isRequired == true ? " *" : ""),
                color: theme.textColor, fontFamily: theme.fontFamily,
                size: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize), bold: true)
            if let subtitle = step.subheader, !subtitle.isEmpty {
                UPExperienceText(
                    text: subtitle, color: theme.textColor, fontFamily: theme.fontFamily,
                    size: CGFloat(ThemeHandler.DefaultValues.surveyDescriptionTextSize))
            }
            control
        }
        .sheet(item: $presentedPicker) { picker in
            if picker == .date { datePicker } else { countryPicker }
        }
    }

    @ViewBuilder
    private var control: some View {
        switch step.type {
        case .likert:
            UPExperienceRating(
                items: RatingItem.fillList(surveyStep: step), selected: answer.rating,
                primary: theme.primaryColor, textColor: theme.textColor,
                fontFamily: theme.fontFamily, width: width
            ) { rating in
                state.updateAnswer(for: step) { $0.rating = rating }
            }
            HStack {
                Text(step.metadata?.lowScore ?? "")
                Spacer()
                Text(step.metadata?.highScore ?? "")
            }.font(.footnote).foregroundColor(Color(theme.textColor))
        case .multipleChoice: choices
        case .openText:
            UPExperienceTextArea(text: text, theme: theme, placeholder: step.metadata?.placeholder ?? "")
        case .singleInput: singleInput
        case .completed: EmptyView()
        }
    }

    private var choices: some View {
        VStack(spacing: UPExperienceLayout.spacing) {
            ForEach((step.metadata?.choices ?? []).indices, id: \.self) { index in
                choiceButton(index, title: step.metadata?.choices?[index].value ?? "")
            }
            if step.metadata?.otherChoice?.enabled == true {
                choiceButton(step.metadata?.choices?.count ?? 0, title: "Other")
                if answer.selectedChoices.contains(step.metadata?.choices?.count ?? 0) {
                    TextField(
                        step.metadata?.otherChoice?.placeholder ?? "",
                        text: SwiftUI.Binding(
                            get: { state.answer(for: step).otherText },
                            set: { value in state.updateAnswer(for: step) { $0.otherText = value } })
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
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
                    Image(systemName: choiceIcon(selected))
                        .foregroundColor(Color(selected ? theme.primaryColor : theme.textSecondaryColor))
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
        .accessibility(value: Text(selected ? "Selected" : ""))
    }

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
                    .foregroundColor(Color(theme.textColor))
                Button(
                    action: { presentedPicker = .date },
                    label: {
                        Image(systemName: "calendar").foregroundColor(Color(theme.textColor))
                    }
                ).accessibility(label: Text("Choose date"))
            }
            .padding(12)
            .frame(minHeight: 50)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(theme.textSecondaryColor), lineWidth: 1))
        } else {
            HStack {
                if step.metadata?.inputType == .phone {
                    Button(
                        action: { presentedPicker = .country },
                        label: {
                            Text(answer.countryCode + " ▾").foregroundColor(Color(theme.textColor))
                        }
                    )
                    .accessibility(label: Text("Country code"))
                }
                TextField(step.metadata?.placeholder ?? "", text: text)
                    .keyboardType(step.inputKeyboardType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(Color(theme.textColor))
            }
            .padding(12)
            .frame(minHeight: 50)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(theme.textSecondaryColor), lineWidth: 1))
        }
    }

    private var datePicker: some View {
        VStack {
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date).labelsHidden()
            Button("Done") {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                state.updateAnswer(for: step) { $0.text = formatter.string(from: selectedDate) }
                presentedPicker = nil
            }.padding()
        }
    }

    private var countryPicker: some View {
        let countries = loadJSONFile(named: "countries", as: [CountryEntity].self) ?? []
        return VStack {
            HStack {
                Text("Country").font(.headline)
                Spacer()
                Button("Close") { presentedPicker = nil }
            }.padding()
            List(countries.indices, id: \.self) { index in
                Button(countries[index].flag + " " + countries[index].name + " " + countries[index].dialCode) {
                    state.updateAnswer(for: step) { $0.countryCode = countries[index].dialCode }
                    presentedPicker = nil
                }
            }
        }
    }
}
