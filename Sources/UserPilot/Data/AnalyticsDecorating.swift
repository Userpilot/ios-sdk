//
//  AnalyticsDecorating.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// AnalyticsDecorating protocol to apply and inject any process to events
//

import Foundation

protocol AnalyticsDecorating: AnyObject {

    /// mutate and update TrackingUpdate event depending on confirming protocol
    func decorate(_ tracking: Event) -> Event

}
