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

/// One rating cell: its label, its bundled icon (none for numbers) and the scale type that tints it.
internal struct UPRatingItem: Equatable {
    let title: String
    let imageName: String?
    let type: LikertViewType

    /// NPS: eleven numeric cells, zero to ten.
    static let npsScale = (0..<ThemeHandler.DefaultValues.npsDefaultLikertViewCount).map {
        UPRatingItem(title: "\($0)", imageName: nil, type: .numbers)
    }
}

internal struct UPExperienceRating: View {
    @SwiftUI.Environment(\.sizeCategory) private var sizeCategory
    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion
    let items: [UPRatingItem]
    let selected: Int?
    let primary: UIColor
    /// Numbers and icons on a filled cell: the primary color's black or white inverse, as on buttons.
    let filledContent: UIColor
    let textColor: UIColor
    let fontFamily: String?
    let width: CGFloat
    let onSelect: (Int) -> Void
    /// The cell that was just chosen; it pulses once.
    @State private var pulsing: Int?

    static let spacing = UPExperienceLayout.ratingSpacing

    /// Cells per row and their width, as on Android: one row up to five cells, otherwise two rows with the
    /// fuller one on top. The cells share `width` evenly, so the scale lines up with the text on both sides;
    /// a shorter second row is centred under the first.
    static func grid(count: Int, width: CGFloat) -> (columns: Int, cellWidth: CGFloat) {
        let columns = count <= UPExperienceLayout.ratingSingleRowMax ? max(1, count) : (count + 1) / 2
        return (columns, max(1, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)))
    }

    private var layout: (columns: Int, cellWidth: CGFloat) { Self.grid(count: items.count, width: width) }
    private var columns: Int { layout.columns }
    private var rowCount: Int { (items.count + columns - 1) / columns }

    var body: some View {
        VStack(spacing: Self.spacing) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: Self.spacing) {
                    ForEach((row * columns)..<min(items.count, (row + 1) * columns), id: \.self) { index in
                        ratingButton(index)
                    }
                }
            }
        }
    }

    private func ratingButton(_ index: Int) -> some View {
        let item = items[index]
        // Ratings are 1-based; every cell up to the chosen one is filled.
        let chosen = selected == index + 1
        let filled = (selected ?? 0) > index
        // Unfilled cells use the theme's secondary color, primary at 20%, as before and as on Android.
        let content = filled ? filledContent : textColor
        let fill = filled ? primary : primary.withAlphaComponent(UPExperienceLayout.ratingUnfilledOpacity)
        return Button(
            action: {
                onSelect(index + 1)
                guard !reduceMotion else { return }
                // Grow briefly, then spring back.
                pulsing = index
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { pulsing = nil }
            },
            label: {
                Group {
                    if item.type == .numbers {
                        // Regular body size, as the previous release drew the numbers.
                        Text(verbatim: item.title)
                            .experienceFont(fontFamily, size: UPExperienceLayout.bodySize)
                    } else if let name = item.imageName {
                        // Emojis keep their colors; stars and hearts are tinted like the text.
                        Image(name, bundle: Userpilot.resourceBundle)
                            .renderingMode(item.type == .emojis ? .original : .template)
                            .resizable().scaledToFit().padding(8)
                    }
                }
                // Cells share the row width evenly.
                .frame(width: layout.cellWidth, height: UPExperienceStyle.scaledSize(44, for: sizeCategory))
                .foregroundColor(Color(content))
                .background(Color(fill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        )
        .buttonStyle(UPRatingButtonStyle(reduceMotion: reduceMotion))
        .scaleEffect(pulsing == index ? 1.12 : 1)
        // Only the pulse (and the fill change it comes with) springs; layout changes such as rotation don't.
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.5), value: pulsing)
        .accessibility(label: Text(verbatim: item.title))
        .accessibility(addTraits: chosen ? .isSelected : [])
    }
}

/// A press shrinks the cell slightly; with Reduce Motion it only dims.
private struct UPRatingButtonStyle: SwiftUI.ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
