//
//  UPExperienceCountrySelector.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/11/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  The dial-code control inside the start of a survey phone field.
//

import SwiftUI

/// The dial-code control inside the start of a phone field: a dropdown of countries on iOS 14+ (`Menu` with a
/// checkmarked `Picker`); on iOS 13, a button that shows the country wheel (`wheel`) under the field.
internal struct UPExperienceCountrySelector: View {
    let code: String
    let color: UIColor
    let fontFamily: String?
    let onSelect: (String) -> Void
    /// iOS 13 only: shows or hides the wheel under the field.
    let onToggleWheel: () -> Void

    var body: some View {
        let label = Text(code + " ▾")
            .experienceFont(fontFamily, size: UPExperienceLayout.bodySize)
            .foregroundColor(Color(color))
        if #available(iOS 14.0, *) {
            Menu(content: { UPCountryList(code: code, onSelect: onSelect) }, label: { label })
                .accentColor(Color(color))
                .accessibility(label: Text("Country code"))
        } else {
            Button(action: onToggleWheel, label: { label })
                .accessibility(label: Text("Country code"))
        }
    }

    /// The country wheel shown under the phone field on iOS 13.
    static func wheel(code: String, onSelect: @escaping (String) -> Void) -> some View {
        UPCountryList(code: code, onSelect: onSelect)
    }
}

/// Every country with its flag and dial code; the chosen one is checkmarked in the menu and centred in the wheel.
private struct UPCountryList: View {
    let code: String
    let onSelect: (String) -> Void
    /// Several countries share a dial code, so the exact row the user picked is remembered.
    @State private var picked: Int?

    private static let countries = loadJSONFile(named: "countries", as: [CountryEntity].self) ?? []

    var body: some View {
        SwiftUI.Picker(selection: selection, label: Text("Country")) {
            ForEach(Self.countries.indices, id: \.self) { index in
                let country = Self.countries[index]
                Text(country.flag + " " + country.name + " " + country.dialCode).tag(index)
            }
        }
        .labelsHidden()
    }

    private var selection: SwiftUI.Binding<Int> {
        SwiftUI.Binding(
            get: { picked ?? Self.countries.firstIndex { $0.dialCode == code } ?? 0 },
            set: { index in
                guard let country = Self.countries[safe: index] else { return }
                picked = index
                onSelect(country.dialCode)
            })
    }
}
