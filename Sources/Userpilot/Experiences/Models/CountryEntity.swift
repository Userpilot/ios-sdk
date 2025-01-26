//
//  CountryEntity.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 20/01/2025.
//  Copyright © 2021 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Represents the CountryEntity.
//

// Typealias for an array of CountryEntity objects
typealias CountriesEntity = [CountryEntity]

// Struct representing a country with properties for the flag, name, and dial code.
struct CountryEntity: Decodable {
    let flag: String
    let name: String
    let dialCode: String
}
