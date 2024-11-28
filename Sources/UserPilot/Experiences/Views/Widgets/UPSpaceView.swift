//
//  UPSpaceView.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  A custom UIView subclass that acts as a spacer within a layout.
//

import Foundation
import UIKit

internal class UPSpaceView: UIView {

    // Default height of the spacer view
    private let defaultHeight: CGFloat = 0.0

    // Custom height for the spacer view
    private var spaceHeight: CGFloat = 0.0

    // MARK: - Initialization

    /// Initializes the view with a specified frame.
    /// - Parameter frame: The frame rectangle for the view, measured in points.
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    /// Initializes the view from a storyboard or XIB.
    /// - Parameter coder: An unarchiver object.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// Sets up the initial properties of the view.
    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
    }

    // MARK: - Layout

    /// Override the layoutSubviews method to adjust the view's frame based on the height.
    override func layoutSubviews() {
        super.layoutSubviews()
        frame.size.height = spaceHeight
    }

    // MARK: - Public Methods

    /// Sets the height of the spacer view.
    /// - Parameter height: The height to be set for the spacer, in points.
    func setHeight(_ height: Int) {
        spaceHeight = CGFloat(height)
        setNeedsLayout()
        layoutIfNeeded()
        layoutSubviews()
    }
}
