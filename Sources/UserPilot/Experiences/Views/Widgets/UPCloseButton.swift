//
//  File.swift
//
//  UPCloseButton.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//
//  [Brief Description]
//  A custom close button that utilizes a system image for the close action.
//

import Foundation
import UIKit

internal class UPCloseButton: UIButton {

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

    /// Configures initial properties for the button, including image setup and alignment.
    private func initializeView() {
        applyConfiguration()
    }

    /// Applies the UIButton configuration available for iOS 15 and later.
    private func applyConfiguration() {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(named: "icon_close", in: Bundle.module, compatibleWith: nil)
            config.imagePlacement = .leading
            config.imagePadding = 0
            self.configuration = config
        } else {
            self.setImage(UIImage(named: "icon_close", in: Bundle.module, compatibleWith: nil), for: .normal)
            self.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
            self.contentHorizontalAlignment = .left
        }
        setTitle("", for: .normal)
    }

    // MARK: - Configuration Methods

    /**
     Configures the visibility and appearance of the close button based on the provided theme data.
     
     This function sets the button's visibility and color properties according to the values specified in the
     `ExperienceTheme` instance. If manual color is enabled, it uses the specified dismiss button color; otherwise,
     it uses an inverted color of the theme's background.
     
     - Parameter theme: The `ExperienceTheme` containing the configuration for the close
     button, such as color and visibility.
     */
    func setupView(theme: ExperienceTheme) {
        if !theme.isDismissButtonEnabled { return }
        tintColor = theme.isDismissButtonColorManual ?
        theme.dismissButtonColor : theme.backgroundColorAsString.invertColor().color.withAlphaComponent(
            ThemeHandler.DefaultValues.closeButtonAlpha)
    }
}
