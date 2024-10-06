//
//  AnalyticsDecorating.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  The `AnalyticsDecorating` protocol defines a mechanism for modifying and enriching analytic events
//  before they are tracked.
//
//  It allows events to be mutated or updated to add additional context or information as needed by conforming classes.
//

import Foundation

/**
 The `AnalyticsDecorating` protocol provides a method for decorating, or modifying,
 an `Event` object before it is sent for tracking.

 Implementers of this protocol can apply various transformations to the event, 
 such as adding new properties, filtering out irrelevant data, or performing other processing tasks.

 - Method:
   - `decorate(_:)`: Takes an `Event` object and returns a modified (or unmodified) `Event`.
 */
internal protocol AnalyticsDecorating: AnyObject {

    /**
     Mutates or updates the given `Event` object based on specific requirements or business logic.
     
     This method allows for modifications or enhancements to the event before it is
     published to the analytics system, such as adding additional metadata or adjusting event properties.

     - Parameter tracking: The original `Event` object to be decorated.
     - Returns: A new or modified `Event` object that has been updated with any additional information.
     */
    func decorate(_ tracking: Event) -> Event

}
