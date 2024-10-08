//
//  Font+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
// [Brief Description]
// Font+Data contains extensions helper methods
//

import Foundation
import UIKit

internal extension UIFontDescriptor.SystemDesign {
    static var allCases: [UIFontDescriptor.SystemDesign] {
        [.default, .monospaced, .rounded, .serif]
    }

    var description: String {
        switch self {
        case .serif: return "Serif"
        case .rounded: return "Rounded"
        case .monospaced: return "Monospaced"
        default: return "Default"
        }
    }
}

internal extension UIFont.Weight {
    static var allCases: [UIFont.Weight] {
        [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
    }

    var description: String {
        switch self {
        case .ultraLight: return "Ultralight"
        case .thin: return "Thin"
        case .light: return "Light"
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "Semibold"
        case .bold: return "Bold"
        case .heavy: return "Heavy"
        case .black: return "Black"
        default: return "?"
        }
    }
}

/*
// These extensions follow the interfaces of
// CaseIterable and CustomStringConvertible, but do not conform to those protocols
// so that the extension methods aren't required to be public.

 @available(iOS 13.0, *)
 extension Font.Design {
    static var allCases: [Font.Design] {
        [.default, monospaced, .rounded, .serif]
    }
    var description: String {
        switch self {
        case .serif: return "Serif"
        case .rounded: return "Rounded"
        case .monospaced: return "Monospaced"
        case .default: fallthrough
        @unknown default: return "Default"
        }
    }
 }
 @available(iOS 13.0, *)
 extension Font.Weight {
    static var allCases: [Font.Weight] {
        [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
    }
    var description: String {
        switch self {
        case .ultraLight: return "Ultralight"
        case .thin: return "Thin"
        case .light: return "Light"
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "Semibold"
        case .bold: return "Bold"
        case .heavy: return "Heavy"
        case .black: return "Black"
        default: return "?"
        }
    }
 }
*/
