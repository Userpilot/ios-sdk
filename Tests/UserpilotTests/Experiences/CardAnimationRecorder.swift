//
//  CardAnimationRecorder.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Records native presentation-layer geometry for rendering regression fixtures.
//

import UIKit

/// Samples rendered positions on display refreshes rather than using timing sleeps as animation evidence.
final class CardAnimationRecorder: NSObject {
    private weak var card: UIView?
    private var displayLink: CADisplayLink?
    private(set) var positions: [CGFloat] = []
    private(set) var centers: [CGPoint] = []
    private(set) var frames: [CGRect] = []
    private(set) var headerHeights: [CGFloat] = []
    private(set) var footerHeights: [CGFloat] = []
    var didSample: (() -> Void)?

    init(card: UIView) { self.card = card }

    func start() {
        positions.removeAll()
        centers.removeAll()
        frames.removeAll()
        headerHeights.removeAll()
        footerHeights.removeAll()
        let link = CADisplayLink(target: self, selector: #selector(sample))
        displayLink = link
        sample()
        link.add(to: .main, forMode: .common)
    }

    func stop() { displayLink?.invalidate(); displayLink = nil }

    @objc private func sample() {
        guard let card, card.window != nil, let presentation = card.layer.presentation() else { return }
        frames.append(presentation.frame)
        if let header = card.subviews.first?.layer.presentation() { headerHeights.append(header.bounds.height) }
        if let footer = card.subviews.last?.layer.presentation() { footerHeights.append(footer.bounds.height) }
        positions.append(presentation.frame.minY)
        centers.append(presentation.position)
        didSample?()
    }
}
