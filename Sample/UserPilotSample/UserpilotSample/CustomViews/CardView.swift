//
//  CardView.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 11/09/2024.
//

import Foundation
import UIKit

class CardView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCardView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCardView()
    }

    private func setupCardView() {
        // Set corner radius
        self.layer.cornerRadius = 10.0
        self.layer.masksToBounds = false

        // Set shadow properties
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowOpacity = 0.2
        self.layer.shadowRadius = 4.0

        // Optionally, add a border
        self.layer.borderColor = UIColor.systemGray6.cgColor
        self.layer.borderWidth = 0.5

        // Set the background color of the card
        self.backgroundColor = UIColor.white
    }
}
