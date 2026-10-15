//
//  ThemeKey.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Identifies the theme an experience must resolve before presentation.
//

/// The theme an experience waits for: its own theme ID, or the title of the host app's theme.
internal enum ThemeKey: Equatable {
    case id(Int)
    case title(String)
}
