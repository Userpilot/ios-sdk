//
//  WebElementSnapshot.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Maps DOM viewport geometry to the admitted WebView without retaining it.
//

import UIKit

internal struct WebElementSnapshot: Codable {
    let width: CGFloat
    let height: CGFloat
    let elements: [Element]

    /// CSS pixels are scaled from the visual viewport; ownership stays on the hosting WebView.
    func nodes(in source: UIView, viewport: CGRect, clip: CGRect) -> [ElementNode] {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return [] }
        let scale = viewport.width / width
        return elements.compactMap { element in
            let values = [element.left, element.top, element.width, element.height]
            guard values.allSatisfy({ $0.isFinite }), element.width > 0, element.height > 0 else { return nil }
            let bounds = CGRect(x: viewport.minX + element.left * scale, y: viewport.minY + element.top * scale,
                                width: element.width * scale, height: element.height * scale)
            let visible = bounds.intersection(clip).intersection(viewport)
            guard !visible.isEmpty, visible.contains(CGPoint(x: bounds.midX, y: bounds.midY)) else { return nil }
            let selector = SelectorProperties(userpilotID: element.userpilotId, tag: element.tag)
            guard !selector.isEmpty else { return nil }
            let node = ElementNode(nodeID: UUID().uuidString, nativeType: "HTMLNode",
                                   displayName: element.text, bounds: bounds,
                                   visibleBounds: visible, selector: selector, children: [], view: nil,
                                   ownershipView: source)
            node.isTransparent = element.transparent == true
            return node
        }
    }

    /// Explicit identifiers, rectangles and displayed text; never input values, editable content or URLs.
    /// `transparent` marks an element drawn with an effective opacity of 0.01 or less.
    internal struct Element {
        let left: CGFloat
        let top: CGFloat
        let width: CGFloat
        let height: CGFloat
        let userpilotId: String?
        let tag: String?
        let text: String?
        let transparent: Bool?

    }

}

// MARK: - Codable

extension WebElementSnapshot.Element: Codable {
    enum CodingKeys: String, CodingKey {
        case left = "x", top = "y", width, height, userpilotId, tag, text, transparent
    }
}
