//
//  File.swift
//  
//
//  Created by Motasem Hamed on 27/08/2024.
//

import Foundation
import UIKit

extension Optional where Wrapped == String {

    var isNotEmpty: Bool {
        return !(self?.isEmpty ?? true)
    }

}

extension String {

    var isNotEmpty: Bool {
        return !isEmpty
    }

}
