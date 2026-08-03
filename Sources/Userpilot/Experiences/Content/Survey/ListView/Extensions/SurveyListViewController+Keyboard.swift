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
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardNotification(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil)
    }

    func removeKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardNotification(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let keyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }

        let isHiding = notification.name == UIResponder.keyboardWillHideNotification
        // Only react when the first responder belongs to our presented hierarchy.
        if !isHiding && view.firstResponder == nil { return }

        let keyboardHeight = keyboardFrame.height
        let bottomSafeAreaInset = view.safeAreaInsets.bottom
        let adjustmentHeight = keyboardHeight - bottomSafeAreaInset - 70 // 70 is action button with its margin

        // What the bottom inset is when no keyboard is up: zero, or the floating action button's
        // clearance. Everything below reads and writes relative to it — comparing against zero
        // instead would read the clearance as "keyboard already handled" and skip the adjustment
        // entirely, leaving the field the user is typing in behind the keyboard.
        let baseInset = scrollViewBottomClearance

        if !isHiding {
            // Return if the keyboard is already visible
            if scrollView.contentInset.bottom > baseInset { return }

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
                    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
                        // Adjust content inset and scroll in the same animation block
                        self.setScrollViewBottomInset(max(baseInset, adjustmentHeight))
                        self.scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
                    })
                    return
                }
            }
            // Only adjust content inset if no scrolling is needed
            setScrollViewBottomInset(max(baseInset, adjustmentHeight))
        } else {
            UIView.animate(withDuration: 0.2) { [weak self] in
                guard let self else { return }
                // Back to the baseline, not to zero: the floating button's clearance has to
                // survive the keyboard going away.
                self.setScrollViewBottomInset(baseInset)
            }
        }
    }

    /// Keeps the content inset and the scroll indicator's inset in step.
    private func setScrollViewBottomInset(_ inset: CGFloat) {
        scrollView.contentInset.bottom = inset
        scrollView.verticalScrollIndicatorInsets.bottom = inset
    }
}
