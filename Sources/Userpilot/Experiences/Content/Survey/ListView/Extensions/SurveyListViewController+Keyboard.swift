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
            // Adjust the scroll view's content inset
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
