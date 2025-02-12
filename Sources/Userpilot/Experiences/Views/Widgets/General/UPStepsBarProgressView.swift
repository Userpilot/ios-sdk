//
//  UPStepsBarProgressView.swift
//  Userpilot
//
//  Created by Motasem Hamed on 30/01/2025.
//
//
//  UPStepsBarProgressView.swift
//  Userpilot
//
//  Created by Motasem Hamed on 30/01/2025.
//

import UIKit

/// A custom UIView that displays a progress bar for a multi-step process. It shows the progress as a visual bar
/// that fills according to the current step, with configurable colors and support for Right-To-Left layout.
class UPStepsBarProgressView: UIView {

    /// The total number of steps in the progress bar.
    /// When set, triggers a layout update.
    var numberOfSteps: Int = 2 {
        didSet { setNeedsLayout() }
    }

    /// The current step in the progress bar.
    /// When set, updates the progress bar with optional animation.
    var currentStep: Int = 0 {
        didSet { setCurrentStep(withAnimation: true) }
    }

    /// The fill color of the progress bar (background color for inactive steps).
    /// When set, updates the background layer color.
    var fillColor: UIColor = UIColor.lightGray.withAlphaComponent(0.3) {
        didSet { backgroundLayer.backgroundColor = fillColor.cgColor }
    }

    /// The color of the active progress bar (current step).
    /// When set, updates the progress layer color.
    var activeColor: UIColor = .black {
        didSet { progressLayer.backgroundColor = activeColor.cgColor }
    }

    private let backgroundLayer = CALayer()
    private let progressLayer = CALayer()

    // MARK: - Initializers

    /// Initializes the view with a given frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    /// Initializes the view from a storyboard or nib file.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    // MARK: - Private Methods

    /// Sets up the background and progress layers with initial properties.
    private func setupLayers() {
        backgroundLayer.backgroundColor = fillColor.cgColor
        layer.addSublayer(backgroundLayer)

        progressLayer.backgroundColor = activeColor.cgColor
        layer.addSublayer(progressLayer)

        layer.cornerRadius = 2
        clipsToBounds = true
    }

    /// Layout the subviews to update the background and progress layers' frames.
    override func layoutSubviews() {
        super.layoutSubviews()

        let height = bounds.height
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = height / 2

        progressLayer.frame = CGRect(x: 0, y: 0, width: 0, height: height)
        progressLayer.cornerRadius = height / 2

        setCurrentStep(withAnimation: false)
    }

    /// Sets the width of the progress layer based on the current step.
    /// Optionally animates the transition.
    private func setCurrentStep(withAnimation: Bool = false) {
        guard numberOfSteps > 1 else { return }

        let stepWidth = bounds.width / CGFloat(numberOfSteps)
        let targetWidth = stepWidth * CGFloat(currentStep)

        if withAnimation {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.3)
            let animation = CABasicAnimation(keyPath: "bounds.size.width")
            animation.fromValue = progressLayer.bounds.width
            animation.toValue = targetWidth
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            progressLayer.bounds.size.width = targetWidth
            progressLayer.add(animation, forKey: "progressAnimation")
            CATransaction.commit()
        } else {
            progressLayer.frame.size.width = targetWidth
        }
    }

    // MARK: - Public Methods

    /// Configures the view based on the provided theme, number of steps, and layout direction (RTL or LTR).
    /// - Parameters:
    ///   - stepsCount: The total number of steps in the progress view.
    ///   - theme: The theme (either `SurveyTheme` or `NPSTheme`) that defines the colors for the steps.
    ///   - isRTL: A boolean value indicating whether the layout should be mirrored for Right-To-Left languages.
    func setupView(stepsCount: Int, theme: Any, isRTL: Bool) {
        numberOfSteps = stepsCount
        activeColor = getActiveColor(from: theme)

        // Apply the color with reduced opacity (20%) to the fill color
        fillColor = getFillColor(from: theme).hexToRgb().updateRgbaOpacity(opacity: "0.2")?.rgbaToColor() ?? .gray

        currentStep = 1

        // Adjust for RTL layout if needed
        if isRTL {
            transform = CGAffineTransform(scaleX: -1, y: 1)
        }
    }

    /// Returns the active color from the provided theme.
    /// - Parameter theme: The theme that contains the color configuration.
    /// - Returns: The active color from the theme.
    private func getActiveColor(from theme: Any) -> UIColor {
        switch theme {
        case let theme as SurveyTheme:
            return theme.stepsProgressColor
        case let theme as NPSTheme:
            return theme.stepsProgressColor
        default:
            return .black
        }
    }

    /// Returns the base fill color for the theme, used for the background or inactive steps.
    /// - Parameter theme: The theme that contains the color configuration.
    /// - Returns: The base color for the fill (inactive steps).
    private func getFillColor(from theme: Any) -> String {
        switch theme {
        case let theme as SurveyTheme:
            return theme.stepsProgressColorAsString
        case let theme as NPSTheme:
            return theme.stepsProgressColorAsString
        default:
            return "#cccccc"
        }
    }

    /// Sets the current step without animation.
    /// - Parameter newStep: The step to set as the current step.
    func setCurrentStep(_ newStep: Int) {
        currentStep = newStep + 1
    }
}
