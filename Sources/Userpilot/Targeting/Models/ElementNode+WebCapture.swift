//
//  ElementNode+WebCapture.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Enriches a native snapshot with DOM children while preserving native geometry and identities.
//

import WebKit

internal extension ElementNode {
    /// Pure native captures complete inline. Only WebViews yield to their web process.
    func captureWebElements(completion: @escaping (ElementNode) -> Void) {
        let sources = webNodes.compactMap { node -> (ElementNode, WKWebView)? in
            guard let webView = node.view as? WKWebView else { return nil }
            return (node, webView)
        }
        guard !sources.isEmpty else { completion(self); return }
        let root = self
        var remaining = sources.count
        var replacements: [String: [ElementNode]] = [:]
        for (node, webView) in sources {
            webView.captureUserpilotElements(clip: node.visibleBounds ?? .zero) { nodes in
                replacements[node.nodeID] = nodes
                remaining -= 1
                if remaining == 0 { completion(root.replacingWebChildren(replacements)) }
            }
        }
    }

    private var webNodes: [ElementNode] {
        if view is WKWebView { return [self] }
        return children.flatMap { $0.webNodes }
    }

    private func replacingWebChildren(_ replacements: [String: [ElementNode]]) -> ElementNode {
        ElementNode(nodeID: nodeID, nativeType: nativeType, displayName: displayName, bounds: bounds,
                    visibleBounds: visibleBounds, selector: selector,
                    children: replacements[nodeID] ?? children.map { $0.replacingWebChildren(replacements) },
                    view: view, ownershipView: ownershipView)
    }
}
