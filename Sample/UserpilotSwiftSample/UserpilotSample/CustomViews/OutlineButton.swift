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
        applyLiquidGlassStyle(.regular)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        applyLiquidGlassStyle(.regular)
    }
}
