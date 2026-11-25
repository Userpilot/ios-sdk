//
//  DynamicCodingKeys.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  The `DynamicCodingKeys` responsible for encoding dic.
//

import Foundation

internal struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        // No int keys supported
        return nil
    }

    // Non-failable init for encoding
    init(key: String) {
        stringValue = key
    }
}
