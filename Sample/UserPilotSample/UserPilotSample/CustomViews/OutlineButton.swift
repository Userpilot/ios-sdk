//
//  OutlineButton.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 11/09/2024.
//

import Foundation
import UIKit

class OutlineButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        // Set the corner radius to half the height for fully rounded corners
        self.layer.cornerRadius = 10 // self.frame.size.height / 2

        // Enable masking to make the corners visible
        self.layer.masksToBounds = true

        // Set background color
        self.backgroundColor = UIColor.white

        // Set title color
        // self.setTitleColor(UIColor.white, for: .normal)

        // Optionally add a border
        self.layer.borderWidth = 1.0
        self.layer.borderColor = UIColor(named: "AccentColor")?.cgColor
    }
}
