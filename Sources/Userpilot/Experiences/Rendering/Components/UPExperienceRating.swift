//
//  UPExperienceRating.swift
//  Userpilot SDK
//
//  Created by Userpilot on 09/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Renders rating scales declaratively with the established numeric and icon assets.
//

import SwiftUI

internal struct UPExperienceRating: View {
    let items: [RatingItem]
    let selected: Int?
    let primary: UIColor
    let textColor: UIColor
    let fontFamily: String?
    let width: CGFloat
    let onSelect: (Int) -> Void

    private var columns: Int { max(1, min(items.count, Int(width / 48))) }
    private var rowCount: Int { (items.count + columns - 1) / columns }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach((row * columns)..<min(items.count, (row + 1) * columns), id: \.self) { index in
                        ratingButton(index)
                    }
                }
            }
        }
    }

    private func ratingButton(_ index: Int) -> some View {
        let item = items[index]
        let chosen = selected == index + 1
        let filled = (selected ?? 0) > index
        return Button(
            action: { onSelect(index + 1) },
            label: {
                Group {
                    if item.type == .numbers {
                        Text(item.title)
                            .font(Font(UIFont.matching(fontName: fontFamily, fontWeight: [.traitBold], fontSize: 16)))
                    } else if let image = item.image {
                        Image(uiImage: image)
                            .renderingMode(item.type == .emojis ? .original : .template)
                            .resizable().scaledToFit().padding(8)
                    }
                }
                .frame(width: max(36, (width - CGFloat(columns - 1) * 8) / CGFloat(columns)), height: 44)
                .foregroundColor(Color(filled ? (primary.isLightColor() ? .black : .white) : textColor))
                .background(Color(primary).opacity(filled ? 1 : 0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(primary), lineWidth: chosen ? 1 : 0))
            }
        )
        .buttonStyle(PlainButtonStyle())
        .accessibility(label: Text(item.title))
        .accessibility(value: Text(chosen ? "Selected" : ""))
    }
}
