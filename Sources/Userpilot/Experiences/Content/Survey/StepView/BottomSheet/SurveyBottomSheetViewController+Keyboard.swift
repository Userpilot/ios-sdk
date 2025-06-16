//
//  SurveyBottomSheetViewController+Keyboard.swift
//  Userpilot
//
//  Created by Motasem Hamed on 12/02/2025.
//

import UIKit

// MARK: - Keyboard Notifications Functions
extension SurveyBottomSheetViewController {

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
            let keyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval
        else { return }

        let keyboardHeight = keyboardFrame.height
        let bottomSafeAreaInset = view.safeAreaInsets.bottom
        let adjustmentHeight = keyboardHeight - bottomSafeAreaInset + 20 // 70 is action button with its margin

        if notification.name == UIResponder.keyboardWillShowNotification {
            UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) { [weak self] in
                self?.view.transform = CGAffineTransform(translationX: 0, y: -adjustmentHeight)
            }
        } else if notification.name == UIResponder.keyboardWillHideNotification {
            UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) { [weak self] in
                self?.view.transform = .identity
            }
        }
    }

}
