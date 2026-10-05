//
//  NWPath+Extensions.swift
//  Userpilot SDK
//
//  Created by Userpilot on 05/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Maps Network.framework paths to the monitor's interface state.
//

import Network

extension NWPath {
    /// A satisfied path still requires an interface before reachability can be probed.
    var hasInterfaceConnection: Bool {
        status == .satisfied && !availableInterfaces.isEmpty
    }

    /// Preserves the monitor's WiFi, cellular, then Ethernet classification order.
    var connectionType: ConnectionType {
        if usesInterfaceType(.wifi) {
            return .wifi
        } else if usesInterfaceType(.cellular) {
            return .cellular
        } else if usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return .unknown
        }
    }
}
