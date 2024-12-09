//
//  IdentifyViewController+CompanyProperties.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 16/09/2024.
//

import Foundation

// MARK: - Company properties methods

extension IdentifyViewController {

    internal func showAddCompanyPropertyDialog(_ propertyTitle: String = "", _ propertyValue: String = "") {
        DialogManager.shared().showAPIAlertDialog(propertyTitle: propertyTitle,
                                                  propertyValue: propertyValue,
                                                  doneButtonHandler: { [weak self] propertyTitle, propertyValue in
            guard let self else { return }
            self.addCompanyProperty(propertyTitle, propertyValue)
        })
    }

    private func addCompanyProperty(_ propertyTitle: String, _ propertyValue: String) {
        let propertyView = PropertyView()

        propertyView.onEditProperty = { [weak self] propertyTitle, propertyValue in
            guard let self else { return }
            self.showAddCompanyPropertyDialog(propertyTitle, propertyValue)
        }

        propertyView.onDeleteProperty = { [weak self] propertyTitle, _ in
            guard let self else { return }
            if let view = companyPropertiesViews[propertyTitle] {
                self.companyPropertiesStackView.removeItemFromStackView(view)
                view.removeFromSuperview()
                companyPropertiesViews.removeValue(forKey: propertyTitle)
            }
        }
        if let view = companyPropertiesViews[propertyTitle] {
            self.companyPropertiesStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
            companyPropertiesViews.removeValue(forKey: propertyTitle)
        }
        propertyView.bindData(propertyName: propertyTitle, propertyValue: propertyValue)
        companyPropertiesStackView.addItemToStackView(propertyView)
        companyPropertiesViews[propertyTitle] = propertyView
    }
}
