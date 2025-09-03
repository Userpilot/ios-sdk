//
//  OutlineButton.swift
//  UserpilotSample
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
        self.layer.cornerRadius = 10
        self.layer.masksToBounds = true
        self.layer.borderWidth = 1.0
        self.layer.borderColor = UIColor(named: "AccentColor")?.cgColor
    }
}
