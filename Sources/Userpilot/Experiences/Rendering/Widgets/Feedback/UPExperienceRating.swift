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

/// A rating cell's icon asset: stars and hearts repeat, faces spread over the scale, numbers have none. Android
/// keeps the same table under the same name (`ratingIcon`).
extension LikertViewType {
    func ratingIcon(index: Int, range: Int) -> String? {
        switch self {
        case .numbers: return nil
        case .stars: return "userpilot_icon_star"
        case .hearts: return "userpilot_icon_heart"
        // Scales past ten get no face rather than a wrong one.
        case .emojis: return Self.smileIconNames(range: range)[safe: index]
        }
    }

    /// The native asset mapping; the ten-point scale runs one to ten, as on Android.
    private static func smileIconNames(range: Int) -> [String] {
        // Shorter scales use a spread of the ten faces, from sad to happy.
        switch range {
        case 3:
            return ["userpilot_icon_smile_three", "userpilot_icon_smile_five", "userpilot_icon_smile_nine"]
        case 5:
            return [
                "userpilot_icon_smile_three", "userpilot_icon_smile_five", "userpilot_icon_smile_six",
                "userpilot_icon_smile_nine", "userpilot_icon_smile_ten"
            ]
        case 7:
            return [
                "userpilot_icon_smile_one", "userpilot_icon_smile_three", "userpilot_icon_smile_five",
                "userpilot_icon_smile_six", "userpilot_icon_smile_seven", "userpilot_icon_smile_nine",
                "userpilot_icon_smile_ten"
            ]
        default:
            return ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
                .map { "userpilot_icon_smile_\($0)" }
        }
    }
}

/// A rating scale of numbers, stars, hearts or faces: one row up to five cells, otherwise two rows. Every cell up
/// to the chosen one fills.
internal struct UPExperienceRating: View {
    @SwiftUI.Environment(\.sizeCategory) private var sizeCategory
    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwiftUI.Environment(\.experienceStyle) private var style
    let count: Int
    /// The chosen cell, counted from one.
    let selected: Int?
    let type: LikertViewType
    /// NPS labels its cells from zero.
    var zeroBasedLabels = false
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

    private var layout: (columns: Int, cellWidth: CGFloat) { Self.grid(count: count, width: width) }
    private var columns: Int { layout.columns }
    private var rowCount: Int { (count + columns - 1) / columns }

    var body: some View {
        VStack(spacing: Self.spacing) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: Self.spacing) {
                    ForEach((row * columns)..<min(count, (row + 1) * columns), id: \.self) { index in
                        ratingButton(index)
                    }
                }
            }
        }
    }

    private func ratingButton(_ index: Int) -> some View {
        let title = "\(zeroBasedLabels ? index : index + 1)"
        let icon = type.ratingIcon(index: index, range: count)
        // Ratings are 1-based; every cell up to the chosen one is filled.
        let chosen = selected == index + 1
        let filled = (selected ?? 0) > index
        // Unfilled cells use the theme's secondary color, primary at 20%, as before and as on Android.
        // Numbers and icons on a filled cell take the button text color, the primary's black or white opposite.
        let content = filled ? style.buttonText : style.text
        let fill = filled ? style.primary : style.primary.withAlphaComponent(UPExperienceLayout.ratingUnfilledOpacity)
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
                    if type == .numbers {
                        // Regular body size, as the previous release drew the numbers.
                        Text(verbatim: title)
                            .experienceFont(style.fontName, size: UPExperienceLayout.bodySize)
                    } else if let name = icon {
                        // Emojis keep their colors; stars and hearts are tinted like the text.
                        Image(name, bundle: Userpilot.resourceBundle)
                            .renderingMode(type == .emojis ? .original : .template)
                            .resizable().scaledToFit().padding(8)
                    }
                }
                // Cells share the row width evenly.
                .frame(width: layout.cellWidth, height: ExperienceFonts.scaledSize(44, for: sizeCategory))
                .foregroundColor(Color(content))
                .background(Color(fill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        )
        .buttonStyle(UPRatingButtonStyle(reduceMotion: reduceMotion))
        .scaleEffect(pulsing == index ? 1.12 : 1)
        // Only the pulse (and the fill change it comes with) springs; layout changes such as rotation don't.
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.5), value: pulsing)
        .accessibility(label: Text(verbatim: title))
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
