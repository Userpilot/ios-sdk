//
//  CALayer+LayoutSignature.swift
//  Userpilot SDK
//
//  Created by Userpilot on 24/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Hashes a layer tree's visible geometry, so a waiting tooltip can tell when its host window's layout changed.
//

import QuartzCore

internal extension CALayer {

    /// A hash of this layer tree's visible geometry: each layer's identity, position, bounds and opacity,
    /// breadth first from at most `visitLimit` layers. A hidden or fully transparent subtree counts as absent.
    func userpilotLayoutSignature(visitLimit: Int = 2_000) -> Int {
        var hasher = Hasher()
        var queue: [CALayer] = [self]
        var index = 0
        while index < queue.count {
            let layer = queue[index]
            index += 1
            guard !layer.isHidden, layer.opacity > 0.01 else { continue }
            hasher.combine(ObjectIdentifier(layer))
            hasher.combine(layer.position.x)
            hasher.combine(layer.position.y)
            hasher.combine(layer.bounds.origin.x)
            hasher.combine(layer.bounds.origin.y)
            hasher.combine(layer.bounds.width)
            hasher.combine(layer.bounds.height)
            hasher.combine(layer.opacity)
            queue.append(contentsOf: (layer.sublayers ?? []).prefix(max(visitLimit - queue.count, 0)))
        }
        return hasher.finalize()
    }
}
