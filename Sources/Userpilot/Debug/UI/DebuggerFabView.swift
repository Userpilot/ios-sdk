//
//  DebuggerFabView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

/// Floating debugger controls. The pan recognizer cancels either button's click when dragging begins.
internal final class DebuggerFabView: UIView {

    weak var host: DebuggerOverlayView?

    private let logoButton = UIButton(type: .custom)
    private let exitButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DebuggerTheme.fabBackground
        layer.cornerRadius = DebuggerTheme.fabSize.height / 2
        clipsToBounds = true

        logoButton.setImage(.userpilotImage(named: "userpilot_debugger_logo"), for: .normal)
        logoButton.imageView?.contentMode = .scaleAspectFit
        logoButton.backgroundColor = DebuggerTheme.brand
        logoButton.layer.cornerRadius = DebuggerTheme.fabButtonSize / 2
        logoButton.clipsToBounds = true
        logoButton.accessibilityLabel = DebuggerStrings.fabAccessibility
        logoButton.addTarget(self, action: #selector(logoTapped), for: .touchUpInside)

        let symbol = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        exitButton.setImage(UIImage(systemName: "xmark", withConfiguration: symbol), for: .normal)
        exitButton.tintColor = .white
        exitButton.accessibilityLabel = DebuggerStrings.exitAccessibility
        exitButton.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        addSubview(logoButton)
        addSubview(exitButton)
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let padding = DebuggerTheme.fabPadding
        let size = DebuggerTheme.fabButtonSize
        logoButton.frame = CGRect(x: padding, y: padding, width: size, height: size)
        exitButton.frame = CGRect(x: bounds.width - padding - size, y: padding, width: size, height: size)
    }

    @objc private func logoTapped() {
        host?.onFabTapped()
    }

    @objc private func exitTapped() {
        host?.onFabExitRequested()
    }

    @objc private func dragged(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            let delta = gesture.translation(in: superview)
            gesture.setTranslation(.zero, in: superview)
            host?.onFabDragged(deltaX: delta.x, deltaY: delta.y)
        case .ended, .cancelled:
            host?.onFabDragEnded()
        default:
            break
        }
    }
}
