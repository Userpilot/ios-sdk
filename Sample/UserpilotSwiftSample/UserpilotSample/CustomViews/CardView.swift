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
        layer.cornerRadius = SampleAppearance.contentCardCornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.shadowOpacity = 0
        layer.borderWidth = 0
        backgroundColor = SampleAppearance.elevatedBackground
    }
}
