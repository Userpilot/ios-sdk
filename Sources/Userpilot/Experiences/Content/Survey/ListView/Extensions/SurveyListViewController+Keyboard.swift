//
//  SurveyListViewController+Keyboard.swift
//  Userpilot
//
//  Created by Motasem Hamed on 26/01/2025.
//

import UIKit

// MARK: - Keyboard Notifications Functions
extension SurveyListViewController {

    func registerKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardNotification(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardNotification(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil)
    }

    func removeKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    @objc private func keyboardNotification(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let keyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }

        let keyboardHeight = keyboardFrame.height
        let bottomSafeAreaInset = view.safeAreaInsets.bottom
        let adjustmentHeight = keyboardHeight - bottomSafeAreaInset - 70 // 70 is action button with its margin

        if notification.name == UIResponder.keyboardWillShowNotification {
            // Return if the keyboard is already visible
            if scrollView.contentInset.bottom > 0 { return }

            if let activeField = view.firstResponder as? UIView {
                let fieldFrameInScrollView = scrollView.convert(activeField.frame, from: activeField.superview)
                // Calculate the desired offset to make the field right above the keyboard
                var offsetY = fieldFrameInScrollView.maxY - (view.frame.height - keyboardHeight) + 20 // 20 for padding
                if let textField = activeField as? UITextField,
                   activeField.tag == ThemeHandler.DefaultValues.surveyOtherChoiceTag,
                   let customTag = textField.customTag {

                    let components = customTag.split(separator: ":")

                    if components.count == 2,
                       let intValue = Int(components[1]) {
                        offsetY += CGFloat(intValue * 55)
                    }
                } else if activeField is UITextView {
                    offsetY += 100
                }

                // Ensure only scroll if the field is actually hidden by the keyboard
                if offsetY > 0 {
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
                        // Adjust content inset and scroll in the same animation block
                        self.scrollView.contentInset.bottom = adjustmentHeight
                        self.scrollView.verticalScrollIndicatorInsets.bottom = adjustmentHeight
                        self.scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
                    })
                    return
                }
            }
            // Only adjust content inset if no scrolling is needed
            scrollView.contentInset.bottom = adjustmentHeight
            scrollView.verticalScrollIndicatorInsets.bottom = adjustmentHeight
        } else if notification.name == UIResponder.keyboardWillHideNotification {
            UIView.animate(withDuration: 0.2) { [weak self] in
                self?.scrollView.contentInset.bottom = 0
                self?.scrollView.verticalScrollIndicatorInsets.bottom = 0
            }
        }
    }
}
