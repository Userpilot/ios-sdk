//
//  Decoder+PreviewContent.swift
//  Userpilot SDK
//
//  Created by Userpilot on 24/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Marks a decode as a preview response, so content models can skip their screen-reply rules.
//

import Foundation

internal extension CodingUserInfoKey {
    /// `true` while a preview response is decoded.
    static let decodesPreviewContent = CodingUserInfoKey(rawValue: "userpilot.decodesPreviewContent")!
}

internal extension Decoder {
    /// Read by `FlowContent` and `Step`, which skip their screen-reply rules for a preview.
    var decodesPreviewContent: Bool {
        userInfo[.decodesPreviewContent] as? Bool == true
    }
}
