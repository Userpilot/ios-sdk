//
//  File.swift
//
//
//  Created by Motasem Hamed on 29/09/2024.
//

import Foundation
import UIKit

internal class UPStepsProgressView: UIView {

    // Default constants
    private let defaultStepRadius: CGFloat = 3.0
    private let defaultCircleSpacing: CGFloat = 6.0
    private let defaultActiveStepColor: UIColor = .black
    private let defaultInactiveStepColor: UIColor = .gray
    private let animationDuration: TimeInterval = 0.5
    private let colorOpacity: CGFloat = 0.2

    // Number of total steps and the current step index
    private var numberOfSteps: Int = 0 {
        didSet { setNeedsDisplay() }
    }
    private var currentStep: Int = 0 {
        didSet { setNeedsDisplay() }
    }
    private var animatedStep: CGFloat = 0.0

    // Paint colors for drawing circles
    private var activeCircleColor: UIColor = .blue
    private var inactiveCircleColor: UIColor = .gray

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear

    }

    // MARK: - Drawing
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

    private func calculateTotalWidth() -> CGFloat {
        return (defaultStepRadius * 2 * CGFloat(numberOfSteps)) +
        (defaultCircleSpacing * CGFloat(numberOfSteps - 1))
    }

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
    func setupView(stepsCount: Int, style: ThemeData) {
        numberOfSteps = stepsCount
        updateColors(from: style)
        setCurrentStep(0)
    }

    private func updateColors(from style: ThemeData) {
        activeCircleColor = style.isStepsProgressColorManual ?
        style.stepsProgressColor : style.backgroundColorAsString.invertColor().color

        inactiveCircleColor = style.isStepsProgressColorManual ?
        style.stepsProgressColorAsString.hexToRgb().updateRgbaOpacity(opacity: "0.2")?.rgbaToColor() ?? .gray :
        style.backgroundColorAsString.invertColor().hexToRgb().updateRgbaOpacity(opacity: "0.2")?.rgbaToColor() ?? .gray
    }

    func setCurrentStep(_ newStep: Int, withAnimation: Bool = false) {
        guard (0..<numberOfSteps).contains(newStep) else { return }

        if withAnimation {
            animateStepTransition(to: newStep)
        } else {
            currentStep = newStep
            animatedStep = CGFloat(currentStep)
        }
    }

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
