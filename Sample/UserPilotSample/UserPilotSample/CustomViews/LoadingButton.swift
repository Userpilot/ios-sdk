//
//  LoadingButton.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit

class LoadingButton: UIButton {

    // MARK: - State
    struct ButtonState {
        var state: UIControl.State
        var title: String?
        var image: UIImage?
    }

    private (set) var buttonStates: [ButtonState] = []

    // MARK: - Loader
    private lazy var loaderImage: UIImageView = {
        let loaderImage = UIImageView()
        loaderImage.image = UIImage(named: "whiteLoader")
        self.addSubview(loaderImage)
        loaderImage.translatesAutoresizingMaskIntoConstraints = false
        let xCenterConstraint = NSLayoutConstraint(item: self,
                                                   attribute: .centerX,
                                                   relatedBy: .equal,
                                                   toItem: loaderImage,
                                                   attribute: .centerX,
                                                   multiplier: 1,
                                                   constant: 0)
        let yCenterConstraint = NSLayoutConstraint(item: self,
                                                   attribute: .centerY,
                                                   relatedBy: .equal,
                                                   toItem: loaderImage,
                                                   attribute: .centerY,
                                                   multiplier: 1,
                                                   constant: 0)
        self.addConstraints([xCenterConstraint, yCenterConstraint])
        return loaderImage
    }()

    func showLoading() {
        DispatchQueue.main.async { [weak self] in
            self?.animateLoaderImage()
            self?.loaderImage.isHidden = false

            var buttonStates: [ButtonState] = []
            for state in [UIControl.State.disabled] {
                let buttonState = ButtonState(state: state,
                                              title: self?.title(for: state),
                                              image: self?.image(for: state))
                buttonStates.append(buttonState)
                self?.setTitle("", for: state)
                self?.setImage(UIImage(), for: state)
            }
            self?.backgroundColor = .systemGray
            self?.buttonStates = buttonStates
            self?.isEnabled = false
        }
    }

    func hideLoading() {
        DispatchQueue.main.async { [weak self] in
            self?.loaderImage.isHidden = true
            guard let buttons = self?.buttonStates else { return }
            for buttonState in buttons {
                self?.setTitle(buttonState.title, for: buttonState.state)
                self?.setImage(buttonState.image, for: buttonState.state)
            }
            self?.isEnabled = true
            self?.stopAnimation()
        }
    }

    func animateLoaderImage() {
        UIView.animate(withDuration: 1, delay: 0.0, options: .curveLinear, animations: {
            self.loaderImage.transform = self.loaderImage.transform.rotated(by: .pi)
        }, completion: { _ in
            if self.loaderImage.isHidden { return }
            self.animateLoaderImage()
        })
    }

    func stopAnimation() {
        self.loaderImage.transform = .identity
        self.layer.removeAllAnimations()

    }
}
