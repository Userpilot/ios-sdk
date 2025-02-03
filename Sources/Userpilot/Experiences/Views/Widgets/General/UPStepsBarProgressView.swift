//
//  UPStepsBarProgressView.swift
//  Userpilot
//
//  Created by Motasem Hamed on 30/01/2025.
//

import UIKit

class UPStepsBarProgressView: UIView {

    var numberOfSteps: Int = 2 {
        didSet { setNeedsLayout() }
    }

    var currentStep: Int = 0 {
        didSet { setCurrentStep(withAnimation: true) }
    }

    var fillColor: UIColor = UIColor.lightGray.withAlphaComponent(0.3) {
        didSet { backgroundLayer.backgroundColor = fillColor.cgColor }
    }

    var activeColor: UIColor = .black {
        didSet { progressLayer.backgroundColor = activeColor.cgColor }
    }

    private let backgroundLayer = CALayer()
    private let progressLayer = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        backgroundLayer.backgroundColor = fillColor.cgColor
        layer.addSublayer(backgroundLayer)

        progressLayer.backgroundColor = activeColor.cgColor
        layer.addSublayer(progressLayer)

        layer.cornerRadius = 2
        clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let height = bounds.height
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = height / 2

        progressLayer.frame = CGRect(x: 0, y: 0, width: 0, height: height)
        progressLayer.cornerRadius = height / 2

        setCurrentStep(withAnimation: false)
    }

    private func setCurrentStep(withAnimation: Bool = false) {
        guard numberOfSteps > 1 else { return }

        let stepWidth = bounds.width / CGFloat(numberOfSteps - 1)
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

    func setupView(stepsCount: Int, theme: SurveyTheme, isRTL: Bool = false) {
        numberOfSteps = stepsCount
        fillColor = theme.stepsProgressColorAsString.hexToRgb().updateRgbaOpacity(
            opacity: "0.2")?.rgbaToColor() ?? .gray
        activeColor = theme.stepsProgressColor
        currentStep = 1
        if isRTL {
            transform = CGAffineTransform(scaleX: -1, y: 1)
        }
    }

    func setCurrentStep(_ newStep: Int) {
        currentStep = newStep
    }
}
