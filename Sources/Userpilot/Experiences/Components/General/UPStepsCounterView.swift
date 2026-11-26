//
//  UPStepsCounterView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 24/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Displays a Flow step's place as text, `2 of 3`.
//

import UIKit

/// A Flow step's place as text, `2 of 3`, drawn where the dots go when the step's theme sets the progress style
/// to `counter`.
final class UPStepsCounterView: UILabel {

    /// The total number of steps in the Flow.
    private var numberOfSteps = 0

    // MARK: - Initializers

    /// Initializes the view with a given frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
        initView()
    }

    /// Initializes the view from a storyboard or nib file.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initView()
    }

    /// Generic init
    private func initView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        textAlignment = .center
        numberOfLines = 1
    }

    // MARK: - Public Methods

    /// Configures the view from a Flow step's theme. An automatic color inverts the background, like the dots.
    /// - Parameters:
    ///   - stepsCount: The whole Flow's `steps_count`.
    ///   - theme: The step's merged theme.
    ///   - isRTL: A boolean value indicating whether the layout should be right-to-left.
    func setupView(
        stepsCount: Int,
        theme: ExperienceTheme,
        isRTL: Bool
    ) {
        numberOfSteps = stepsCount
        textColor = theme.isStepsProgressColorManual
            ? theme.stepsProgressColor
            : theme.backgroundColorAsString.invertColor().color
        font = UIFont.matching(
            fontName: theme.fontFamily, fontWeight: [],
            fontSize: Constants.Theme.stepsCounterTextSize)
        semanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        setCurrentStep(0)
    }

    /// Shows the step's place in the Flow.
    /// - Parameter step: The step's 0-based place in the Flow.
    func setCurrentStep(_ step: Int) {
        text = "\(step + 1) of \(numberOfSteps)"
    }
}
