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
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardNotification(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil)
    }

    func removeKeyboardNotifications() {
        NotificationCenter.default.removeObserver(
            self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardNotification(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let keyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval
        else { return }

        let isHiding = notification.name == UIResponder.keyboardWillHideNotification
        // Only react when the first responder belongs to our presented hierarchy.
        // Without this, host-app keyboards (including IQKeyboardManager's toolbar "Done") trigger a reset.
        if !isHiding && view.firstResponder == nil { return }

        let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
        let rawOverlap = max(0, view.bounds.maxY - keyboardFrameInView.minY)
        let structuralBottomInset = max(0, view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom)
        let padding: CGFloat = 20
        let adjustment = isHiding ? 0 : max(0, rawOverlap - structuralBottomInset + padding)

        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) { [weak self] in
            guard let self else { return }
            self.additionalSafeAreaInsets.bottom = adjustment
            self.view.layoutIfNeeded()
        }
    }

}
