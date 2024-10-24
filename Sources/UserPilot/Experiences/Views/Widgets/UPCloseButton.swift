//
//  File.swift
//
//  UPCloseButton.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//
//  [Brief Description]
//  A custom close button that utilizes a system image for the close action.
//

import Foundation
import UIKit

internal class UPCloseButton: UIButton {

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
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")
        config.imagePlacement = .leading
        config.imagePadding = 0
        self.configuration = config
    }

    // MARK: - Configuration Methods

    /**
     Configures the visibility and appearance of the close button based on the provided theme data.
     
     This function sets the button's visibility and color properties according to the values specified in the
     `ThemeData` instance. If manual color is enabled, it uses the specified dismiss button color; otherwise,
     it uses an inverted color of the theme's background.
     
     - Parameter style: The `ThemeData` containing the configuration for the close button, such as color and visibility.
     */
    func setupView(style: ThemeData) {
        if !style.isDismissButtonEnabled { return }
        tintColor = style.isDismissButtonColorManual ?
                    style.dismissButtonColor : style.backgroundColorAsString.invertColor().color
    }
}
