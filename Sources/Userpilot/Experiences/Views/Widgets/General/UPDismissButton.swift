//
//  File.swift
//
//  UPDismissButton.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//
//  [Brief Description]
//  A custom close button that utilizes a system image for the close action.
//

import Foundation
import UIKit

internal class UPDismissButton: UIButton {

    // MARK: - Properties
    static let buttonSize = CGFloat(35)

    // MARK: - Initializers
    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeView()
    }

    // MARK: - Setup Methods
    private func initializeView() {
        // For iOS 15+, disable clipping to allow scale animations to be fully visible
        layer.masksToBounds = false
        clipsToBounds = false
        applyConfiguration()
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    /// Handler for button tap with haptic feedback
    @objc private func buttonTapped() {
        // Add haptic feedback for iOS 13+
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }

    private func applyConfiguration() {
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let closeImage = UIImage(systemName: "xmark", withConfiguration: imageConfig)
        setTitle("", for: .normal)

        if #available(iOS 15.0, *) {
            var config: UIButton.Configuration

            if #available(iOS 26.0, *) {
                config = .prominentClearGlass()
            } else {
                // iOS 15-25: Use plain style with custom background
                config = .plain()
                config.background.backgroundColor = UIColor.gray.withAlphaComponent(0.22)
                config.background.cornerRadius = UPDismissButton.buttonSize / 2
                config.background.strokeColor = UIColor.white.withAlphaComponent(0.3)
                config.background.strokeWidth = 0.5
            }

            let templateImage = closeImage?.withRenderingMode(.alwaysTemplate)
            config.image = templateImage
            config.imagePlacement = .leading
            config.imagePadding = 0

            self.configuration = config
            self.tintColor = .white
        } else {
            // iOS 14 fallback with rounded container similar to iOS 26 style
            let templateImage = closeImage?.withRenderingMode(.alwaysTemplate)
            self.setImage(templateImage, for: .normal)
            self.tintColor = .white

            // Add rounded background container
            self.backgroundColor = UIColor.black.withAlphaComponent(0.15)
            self.layer.cornerRadius = UPDismissButton.buttonSize / 2
            self.layer.masksToBounds = true

            // Add subtle border for depth
            self.layer.borderWidth = 0.5
            self.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        }
    }

    // MARK: - Public Methods
    func setXIconColor(_ color: UIColor) {
        self.tintColor = color
        if #available(iOS 15.0, *) {
            if var config = self.configuration {
                config.baseForegroundColor = color
                config.image = config.image?.withRenderingMode(.alwaysTemplate)
                self.configuration = config
            }
        }
    }

    func setupView(theme: ExperienceTheme) {
        guard theme.isDismissButtonEnabled else { return }
        setXIconColor(
            theme.isDismissButtonColorManual
                ? theme.dismissButtonColor
                : theme.backgroundColorAsString
                    .invertColor()
                    .color.withAlphaComponent(ThemeHandler.DefaultValues.closeButtonAlpha))
    }

    func setupView(theme: SurveyTheme) {
        setXIconColor(
            theme.backgroundColorAsString
                .invertColor()
                .color
                .withAlphaComponent(ThemeHandler.DefaultValues.closeButtonAlpha))
    }
}
