//
//  JsonCoder.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 05/11/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Shared JSON encoder/decoder utilities used by the SDK.
//

import Foundation

/// Shared encoder for event storage.
/// Uses standard encoding since EventStorage now stores milliseconds directly.
internal enum UserpilotEncoder {
    static let shared: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
}

// MARK: - Event Storage Decoder

/// Shared decoder for event storage.
/// Uses standard decoding since EventStorage stores milliseconds directly.
internal enum UserpilotDecoder {
    static let shared: JSONDecoder = {
        return JSONDecoder()
    }()
}
