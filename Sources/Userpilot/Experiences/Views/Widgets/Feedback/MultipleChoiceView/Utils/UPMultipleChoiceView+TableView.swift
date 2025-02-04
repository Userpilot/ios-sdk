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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return choices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
                                     isRTL: isRTL)
        choiceTableViewCell.selectionStyle = .none
        return choiceTableViewCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Handle the "Other" choice input if present.
        if choices.last?.id == ThemeHandler.DefaultValues.surveyOtherChoice {
            if let cell = tableView.cellForRow(
                at: IndexPath(row: choices.count - 1, section: 0)) as? ChoiceTableViewCell {
                choices[choices.count - 1].otherOptionText = cell.getOtherOptionText()
            }
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

        UIView.performWithoutAnimation {
            tableView.reloadData()
        }

        if choices.last?.id == ThemeHandler.DefaultValues.surveyOtherChoice && choices.last?.isSelected == true {
            if let cell = tableView.cellForRow(
                at: IndexPath(row: choices.count - 1, section: 0)) as? ChoiceTableViewCell {
                cell.showKeyboard()
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
