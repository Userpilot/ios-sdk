//
//  UPMultipleChoiceView+TableView.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Extension of `UPMultipleChoiceView` to conform to `UITableViewDelegate` and `UITableViewDataSource` protocols.
//  Handles the logic for rendering choices, managing selections, and updating the view state.
//

import UIKit

// MARK: - UITableViewDataSource

extension UPMultipleChoiceView: UITableViewDelegate, UITableViewDataSource {

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        return choices.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard
            let choiceTableViewCell = tableView.dequeueReusableCell(
                withIdentifier: "ChoiceTableViewCell", for: indexPath) as? ChoiceTableViewCell,
            let surveyStep,
            let surveyTheme
        else {
            return UITableViewCell()
        }
        choiceTableViewCell.bindCell(choice: choices[indexPath.row],
                                     surveyStep: surveyStep,
                                     surveyTheme: surveyTheme,
                                     isRTL: isRTL,
                                     indexPath: indexPath)
        choiceTableViewCell.selectionStyle = .none
        return choiceTableViewCell
    }

    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        let lastIndex = choices.count - 1
        let hasOtherChoice = choices.last?.id == ThemeHandler.DefaultValues.surveyOtherChoice
        let wasOtherSelected = hasOtherChoice && (choices[lastIndex].isSelected == true)

        // Handle the "Other" choice input if present: cache typed text before reloading.
        if hasOtherChoice, let cell = tableView.cellForRow(
            at: IndexPath(row: lastIndex, section: 0)) as? ChoiceTableViewCell {
            choices[lastIndex].otherOptionText = cell.getOtherOptionText()
        }

        if surveyStep?.metadata?.isMultiSelect == false {
            for (index, var choice) in choices.enumerated() {
                choice.isSelected = (index == indexPath.row)
                choices[index] = choice
            }
        } else {
            choices[indexPath.row].isSelected = !(choices[indexPath.row].isSelected ?? false)
        }

        viewStateProtocol?.onViewStateChanged(isValid: isValidAnswer())

        let tappedOtherRow = hasOtherChoice && indexPath.row == lastIndex
        let otherSelectedNow = hasOtherChoice && (choices[lastIndex].isSelected == true)
        // Re-tapping the already-selected "Other" row must not reload that cell:
        // reloadData resigns the text field's first responder, which visibly
        // dismisses then re-shows the keyboard. Reload only the other rows so the
        // "Other" text field keeps its first responder and the keyboard stays put.
        let keepOtherFocused = tappedOtherRow && wasOtherSelected && otherSelectedNow

        UIView.performWithoutAnimation {
            if keepOtherFocused {
                let rowsToReload = (0..<choices.count)
                    .filter { $0 != lastIndex }
                    .map { IndexPath(row: $0, section: 0) }
                if !rowsToReload.isEmpty {
                    tableView.reloadRows(at: rowsToReload, with: .none)
                }
            } else {
                tableView.reloadData()
            }
        }

        if tappedOtherRow && otherSelectedNow {
            if let cell = tableView.cellForRow(
                at: IndexPath(row: lastIndex, section: 0)) as? ChoiceTableViewCell {
                cell.showKeyboard()
            }
        } else {
            self.endEditing(true)
        }
    }

    func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        return UITableView.automaticDimension
    }
}
