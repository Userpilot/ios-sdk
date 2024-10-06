//
//  File.swift
//  
//
//  Created by Motasem Hamed on 01/10/2024.
//

import Foundation

// MARK: - Protocol to handle content-related actions such as opening links.
protocol ExperienceContentProtocol: AnyObject {
    /**
     Called when a link needs to be opened.
     - Parameter link: The URL link that should be opened.
     This method can be implemented to provide specific behavior for link
     handling, such as launching a web browser or navigating within the app.
     */
    func onOpenLink(_ link: String)
}

// Provide a default implementation for the protocol, if needed.
internal extension ExperienceContentProtocol {
    func onOpenLink(_ link: String) {
        // Default implementation does nothing. Override this in conforming classes.
    }
}
