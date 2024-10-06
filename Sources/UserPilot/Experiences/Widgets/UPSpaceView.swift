//
//  File.swift
//  
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation
import UIKit

internal class UPSpaceView: UIView {

    // Default height
    private let defaultHeight: CGFloat = 0.0

    // Custom height for the spacer view
    private var spaceHeight: CGFloat = 0.0

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .systemPink
        // Additional setup can be done here if needed
    }

    // MARK: - Public Methods
    func setHeight(_ height: Int) {
        spaceHeight = CGFloat(height)
        setNeedsLayout()
        layoutIfNeeded()
        layoutSubviews()
    }
}
