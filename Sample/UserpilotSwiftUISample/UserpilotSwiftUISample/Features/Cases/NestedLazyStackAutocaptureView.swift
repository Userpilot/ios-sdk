//
//  NestedLazyStackAutocaptureView.swift
//  UserpilotSwiftUISample
//
//  Exercises the SDK's accessibility-scan opt-out modifiers on the exact
//  pattern that triggers the SwiftUI accessibility hang (Apple bug
//  FB21851974): nested LazyVStack / LazyHStack whose rows mutate state in
//  `.onAppear`.
//
//  Two SDK opt-outs are available, switchable at runtime:
//    - .userpilotSkipAccessibilityScan() — skips the tap-time accessibility
//      read for this screen's lifetime (reflection + display-list capture
//      keep working, so titles are still captured).
//    - .userpilotScanOnce() — implies skip + runs a single reflection pass
//      when the view attaches; subsequent taps resolve from cache.
//

import SwiftUI
import Userpilot

struct NestedLazyStackAutocaptureView: View {

    enum OptOutStyle: String, CaseIterable, Identifiable {
        case skipScan = "Skip scan"
        case scanOnce = "Scan once"
        var id: String { rawValue }

        var api: String {
            switch self {
            case .skipScan: return ".userpilotSkipAccessibilityScan()"
            case .scanOnce: return ".userpilotScanOnce()"
            }
        }

        var explanation: String {
            switch self {
            case .skipScan:
                return "Skips the tap-time accessibility read for this screen. Titles are still captured via reflection + display-list — only the read that can trigger FB21851974 is suppressed."
            case .scanOnce:
                return "Implies skip-accessibility and runs one reflection pass on attach. Best for mostly-static screens: scan once, then taps resolve from cache at zero scan cost."
            }
        }
    }

    @State private var style: OptOutStyle = .skipScan
    @State private var sections: [Int] = Array(1...3)
    @State private var lastTapped = "—"

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                stylePicker
                activeModifierCard
                statusCard

                ForEach(sections, id: \.self) { section in
                    sectionCard(section)
                        .onAppear { loadMoreSectionsIfNeeded(section) }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Nested lazy stacks")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(OptOutModifier(style: style))
    }

    // MARK: - Controls

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Opt-out style")
                .font(.subheadline.weight(.semibold))

            // Two short labels fit a segmented control cleanly (the old
            // three-long-option control truncated on narrow screens).
            Picker("Opt-out style", selection: $style) {
                ForEach(OptOutStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var activeModifierCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(style.api)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(style.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last tapped")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(lastTapped)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - The FB21851974 repro pattern

    private func sectionCard(_ section: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Section #\(section)")
                .font(.headline)

            // Nested lazy container that mutates state on appear — the repro.
            LazyVStack(spacing: 8) {
                ForEach(1...4, id: \.self) { row in
                    Button("Confirm Section \(section) · Row \(row)") {
                        lastTapped = "Section \(section) · Row \(row)"
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func loadMoreSectionsIfNeeded(_ section: Int) {
        guard section == sections.last, sections.count < 8 else { return }
        sections.append((sections.last ?? 0) + 1)
    }
}

/// Applies the chosen SDK opt-out modifier.
private struct OptOutModifier: ViewModifier {
    let style: NestedLazyStackAutocaptureView.OptOutStyle

    func body(content: Content) -> some View {
        switch style {
        case .skipScan:
            content.userpilotSkipAccessibilityScan()
        case .scanOnce:
            content.userpilotScanOnce()
        }
    }
}

#Preview {
    NavigationStack {
        NestedLazyStackAutocaptureView()
    }
}
