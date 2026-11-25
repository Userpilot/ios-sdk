//
//  SimpleBarChartView.swift
//  UserpilotSample
//
//  Lightweight bar chart for the Tooltips demo dashboard.
//

import UIKit

final class SimpleBarChartView: UIView {

    var values: [CGFloat] = [] {
        didSet { setNeedsDisplay() }
    }

    var barColor: UIColor = SampleAppearance.accentColor {
        didSet { setNeedsDisplay() }
    }

    var labels: [String] = [] {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard !values.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }

        let maxValue = max(values.max() ?? 1, 1)
        let labelHeight: CGFloat = labels.isEmpty ? 0 : 18
        let chartRect = CGRect(
            x: 0,
            y: 8,
            width: rect.width,
            height: rect.height - labelHeight - 8
        )
        let spacing: CGFloat = 10
        let barWidth = max(
            (chartRect.width - spacing * CGFloat(values.count + 1)) / CGFloat(values.count),
            8
        )

        for (index, value) in values.enumerated() {
            let normalized = value / maxValue
            let barHeight = max(chartRect.height * normalized, 4)
            let barX = spacing + CGFloat(index) * (barWidth + spacing)
            let barY = chartRect.maxY - barHeight
            let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)

            let path = UIBezierPath(roundedRect: barRect, cornerRadius: 6)
            context.setFillColor(barColor.withAlphaComponent(0.85).cgColor)
            context.addPath(path.cgPath)
            context.fillPath()

            if index < labels.count {
                let label = labels[index] as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let size = label.size(withAttributes: attrs)
                let labelPoint = CGPoint(
                    x: barRect.midX - size.width / 2,
                    y: chartRect.maxY + 2
                )
                label.draw(at: labelPoint, withAttributes: attrs)
            }
        }
    }
}
