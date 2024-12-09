//
//  IdentifyViewController+UserProperties.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 16/09/2024.
//

import Foundation

// MARK: - User properties methods

extension IdentifyViewController {

    internal func showAddUserPropertyDiaog(_ propertyTitle: String = "", _ propertyValue: String = "") {
        DialogManager.shared().showAPIAlertDialog(propertyTitle: propertyTitle,
                                                  propertyValue: propertyValue,
                                                  doneButtonHandler: { [weak self] propertyTitle, propertyValue in
            guard let self else { return }
            self.addUserProperty(propertyTitle, propertyValue)
        })
    }

    private func addUserProperty(_ propertyTitle: String, _ propertyValue: String) {
        let propertyView = PropertyView()

        propertyView.onEditProperty = { [weak self] propertyTitle, propertyValue in
            guard let self else { return }
            self.showAddUserPropertyDiaog(propertyTitle, propertyValue)
        }

        propertyView.onDeleteProperty = { [weak self] propertyTitle, _ in
            guard let self else { return }
            if let view = userPropertiesViews[propertyTitle] {
                self.userPropertiesStackView.removeItemFromStackView(view)
                view.removeFromSuperview()
                userPropertiesViews.removeValue(forKey: propertyTitle)
            }
        }
        if let view = userPropertiesViews[propertyTitle] {
            self.userPropertiesStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
            userPropertiesViews.removeValue(forKey: propertyTitle)
        }
        propertyView.bindData(propertyName: propertyTitle, propertyValue: propertyValue)
        userPropertiesStackView.addItemToStackView(propertyView)
        userPropertiesViews[propertyTitle] = propertyView
    }
}
