//
//  NetworkingError.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//

import Foundation

enum NetworkingError: Error {
    case invalidURL
    case noData
    case nonSuccessfulStatusCode(Int)
}
