//
//  ConnectionType.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Network interface classification and its existing diagnostic labels.
//

internal enum ConnectionType {
    case wifi
    case cellular
    case wiredEthernet
    case unknown
}

extension ConnectionType {
    /// Stable log labels consumed by network diagnostics.
    var logDescription: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .unknown: return "Unknown"
        }
    }
}
