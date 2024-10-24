//
//  UPStepsProgressView.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 29/09/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  A custom view that acts as a step progress indicator, displaying a series of circular steps.
//  This view visually indicates the progress of a user through a series of steps, allowing for
//  customization of colors and animations.
//

import Foundation
import UIKit

internal class UPStepsProgressView: UIView {

    // MARK: - Default Constants

    /// The default radius for each step circle.
    private let defaultStepRadius: CGFloat = 3.0

    /// The default spacing between the circles.
    private let defaultCircleSpacing: CGFloat = 6.0

    /// The default color for active steps.
    private let defaultActiveStepColor: UIColor = .black

    /// The default color for inactive steps.
    private let defaultInactiveStepColor: UIColor = .gray

    /// The duration of the animation when transitioning between steps.
    private let animationDuration: TimeInterval = 0.5

    /// The opacity level applied to inactive step colors.
    private let colorOpacity: CGFloat = 0.2

    // MARK: - Dynamic Properties

    /// The total number of steps to be displayed in the progress view.
    private var numberOfSteps: Int = 0 {
        didSet { setNeedsDisplay() }
    }

    /// The index of the currently active step.
    private var currentStep: Int = 0 {
        didSet { setNeedsDisplay() }
    }

    /// A value used for animating the transition between steps.
    private var animatedStep: CGFloat = 0.0

    // MARK: - Paint Colors

    /// The color used to fill active step circles.
    private var activeCircleColor: UIColor = .blue

    /// The color used to fill inactive step circles.
    private var inactiveCircleColor: UIColor = .gray

    // MARK: - Initialization

    /// Initializes a new UPStepsProgressView with the specified frame.
    /// - Parameter frame: The frame for the view.
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
    }

    /// Initializes a new UPStepsProgressView from a storyboard or XIB.
    /// - Parameter coder: The coder used to decode the view.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
    }

    // MARK: - Drawing

    /// Draws the step circles in the view.
    /// - Parameter rect: The area in which to draw the view's content.
    override func draw(_ rect: CGRect) {
        guard numberOfSteps > 0 else { return }

        let totalWidth = calculateTotalWidth()
        let startX = (bounds.width - totalWidth) / 2

        for step in 0..<numberOfSteps {
            let positionX = startX + CGFloat(step) * (defaultStepRadius * 2 + defaultCircleSpacing)
            let color = step <= Int(animatedStep) ? activeCircleColor : inactiveCircleColor
            drawCircle(at: CGPoint(x: positionX, y: bounds.height / 2), color: color)
        }
    }

    /// Calculates the total width required to display all step circles.
    /// - Returns: The total width of all steps combined, including spacing.
    private func calculateTotalWidth() -> CGFloat {
        return (defaultStepRadius * 2 * CGFloat(numberOfSteps)) +
        (defaultCircleSpacing * CGFloat(numberOfSteps - 1))
    }

    /**
     Draws a circle at the specified center point with the given color.
     
     - Parameters:
       - center: The center point of the circle.
       - color: The color to fill the circle.
     */
    private func drawCircle(at center: CGPoint, color: UIColor) {
        let path = UIBezierPath(arcCenter: center,
                                radius: defaultStepRadius,
                                startAngle: 0,
                                endAngle: 2 * .pi,
                                clockwise: true)
        color.setFill()
        path.fill()
    }

    // MARK: - Public Methods

    /**
     Sets up the view with the specified number of steps and styling data.

     - Parameters:
       - stepsCount: The total number of steps to display.
       - theme: The experience theme used for styling the circles.
     */
    func setupView(stepsCount: Int, theme: ExperienceTheme) {
        numberOfSteps = stepsCount
        updateColors(from: theme)
        setCurrentStep(0)
    }

    /// Updates the active and inactive circle colors based on the provided theme data.
    /// - Parameter style: The theme data used for color configuration.
    private func updateColors(from theme: ExperienceTheme) {
        activeCircleColor = theme.isStepsProgressColorManual ?
        theme.stepsProgressColor : theme.backgroundColorAsString.invertColor().color

        inactiveCircleColor = theme.isStepsProgressColorManual ?
        theme.stepsProgressColorAsString.hexToRgb().updateRgbaOpacity(opacity: "0.2")?.rgbaToColor() ?? .gray :
        theme.backgroundColorAsString.invertColor().hexToRgb().updateRgbaOpacity(opacity: "0.2")?.rgbaToColor() ?? .gray
    }

    /// Sets the current step, optionally animating the transition.
    /// - Parameters:
    ///   - newStep: The new step index to set as current.
    ///   - withAnimation: A Boolean value indicating whether to animate the transition.
    func setCurrentStep(_ newStep: Int, withAnimation: Bool = false) {
        guard (0..<numberOfSteps).contains(newStep) else { return }

        if withAnimation {
            animateStepTransition(to: newStep)
        } else {
            currentStep = newStep
            animatedStep = CGFloat(currentStep)
        }
    }

    /// Animates the transition to the specified new step.
    /// - Parameter newStep: The target step index for the animation.
    private func animateStepTransition(to newStep: Int) {
        let animation = CABasicAnimation(keyPath: "animatedStep")
        animation.fromValue = animatedStep
        animation.toValue = CGFloat(newStep)
        animation.duration = animationDuration
        layer.add(animation, forKey: "animatedStep")

        animatedStep = CGFloat(newStep)

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.currentStep = newStep
        }
    }
}
