//
//  CapturePillView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Provides accessible native capture and exit controls.
//

import UIKit

// MARK: - CapturePillView

/// Pill-shaped container holding the capture and close controls.
internal final class CapturePillView: UIView {

    // MARK: Nested Types

    private enum Constants {
        static let height: CGFloat = 56
        /// Padding between the pill's edge and the controls it holds.
        static let padding: CGFloat = 4
        /// Gap between the capture control and the close control.
        static let spacing: CGFloat = 8
        static let captureSize: CGFloat = 48
        static let closeSize: CGFloat = 48
        static let closeSymbolPointSize: CGFloat = 14
        static let shadowRadius: CGFloat = 8
        static let shadowOpacity: Float = 0.35
        /// Radii of the concentric capture glyph, measured from its centre.
        /// Outer and inner bound the ring; the dot sits inside both.
        static let glyphOuterRadius: CGFloat = 11
        static let glyphInnerRadius: CGFloat = 9
        static let glyphDotRadius: CGFloat = 4
    }

    /// Builder capture colours, shared with the confirmation sheet and preview outlines (as on Android).
    enum Palette {
        /// Near-black pill — the border that separates the purple control from
        /// whatever host-app colour happens to sit underneath it.
        static let pill = UIColor(red: 16 / 255, green: 24 / 255, blue: 40 / 255, alpha: 1)
        /// Userpilot purple (#6765E8), the sample apps' primary colour and `DebuggerTheme.brand`.
        static let brand = UIColor(red: 103 / 255, green: 101 / 255, blue: 232 / 255, alpha: 1)
    }

    // MARK: Properties

    /// Fixed pill size used by the host controller to constrain docking.
    static let size = CGSize(
        width: Constants.padding * 2 + Constants.captureSize
            + Constants.spacing + Constants.closeSize,
        height: Constants.height
    )

    /// Called when the operator taps the capture control.
    private let onCapture: () -> Void

    /// Called when the operator taps the close control.
    private let onClose: () -> Void

    /// Accessible capture button with a concentric glyph.
    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .custom)
        button.frame = CGRect(
            x: 0, y: 0, width: Constants.captureSize, height: Constants.captureSize)
        button.backgroundColor = Palette.brand
        button.layer.cornerRadius = Constants.captureSize / 2
        button.layer.addSublayer(Self.makeGlyphLayer(in: button.bounds))
        button.accessibilityLabel = BuilderCaptureStrings.captureButtonAccessibilityLabel
        button.accessibilityHint = BuilderCaptureStrings.captureButtonAccessibilityHint
        button.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        return button
    }()

    /// The close control, which leaves capture mode.
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.frame = CGRect(
            x: 0, y: 0, width: Constants.closeSize, height: Constants.closeSize)
        button.tintColor = .white
        button.setImage(Self.closeSymbol, for: .normal)
        button.accessibilityLabel = BuilderCaptureStrings.exitAccessibilityLabel
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()

    // MARK: Initialization

    /// - Parameters:
    ///   - onCapture: invoked on a tap of the capture control, on the main thread.
    ///   - onClose: invoked on a tap of the close control, on the main thread.
    init(onCapture: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onClose = onClose
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Configuration

    /// Uses fixed frames because the host controller positions the pill by its centre.
    private func configure() {
        backgroundColor = Palette.pill
        layer.cornerRadius = Constants.height / 2
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = Constants.shadowOpacity
        layer.shadowOffset = .zero
        layer.shadowRadius = Constants.shadowRadius

        addSubview(captureButton)
        addSubview(closeButton)

        captureButton.center = CGPoint(
            x: Constants.padding + Constants.captureSize / 2,
            y: Constants.height / 2
        )
        closeButton.center = CGPoint(
            x: Self.size.width - Constants.padding - Constants.closeSize / 2,
            y: Constants.height / 2
        )
    }

    // MARK: Glyph

    /// Even-odd-filled ring and centre dot in one native shape layer.
    private static func makeGlyphLayer(in bounds: CGRect) -> CAShapeLayer {
        let centre = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = UIBezierPath()

        for radius in [
            Constants.glyphOuterRadius,
            Constants.glyphInnerRadius,
            Constants.glyphDotRadius
        ] {
            path.append(UIBezierPath(ovalIn: CGRect(
                x: centre.x - radius,
                y: centre.y - radius,
                width: radius * 2,
                height: radius * 2
            )))
        }

        let layer = CAShapeLayer()
        layer.frame = bounds
        layer.path = path.cgPath
        layer.fillRule = .evenOdd
        layer.fillColor = UIColor.white.cgColor
        return layer
    }

    /// The close glyph, weighted to stay legible at this size.
    private static var closeSymbol: UIImage? {
        let configuration = UIImage.SymbolConfiguration(
            pointSize: Constants.closeSymbolPointSize, weight: .medium)
        return UIImage(systemName: "xmark", withConfiguration: configuration)
    }

    // MARK: Actions

    @objc private func captureTapped() {
        onCapture()
    }

    @objc private func closeTapped() {
        onClose()
    }
}
