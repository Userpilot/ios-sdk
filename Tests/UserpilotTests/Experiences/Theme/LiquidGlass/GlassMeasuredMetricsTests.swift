//
//  GlassMeasuredMetricsTests.swift
//  UserpilotTests
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Covers the behavior of `surfaceStyle(...)`: legacy fallback, appearance selection,
//  configured material, backdrop masking, and the public configuration flags that feed it.
//

import XCTest
@testable import Userpilot

final class GlassMeasuredMetricsTests: XCTestCase {

    // MARK: Helpers

    /// Answers only the primitives; the composition under test comes from the protocol extension.
    private final class StubResolver: GlassCapabilityResolving {
        var allowsSurface = true
        var masks = true
        var appleBackdrop = true
        var appleBackground = true

        func allowsGlass(for kind: GlassElementKind, surfaceMaterial: SurfaceMaterial?) -> Bool {
            kind == .sheetOrDialog ? allowsSurface : true
        }
        func glassTintAlpha(for style: UIUserInterfaceStyle) -> CGFloat { 0.28 }
        var masksBackdropBehindGlassSurface: Bool { masks }
        var usesAppleDefaultBackdrop: Bool { appleBackdrop }
        var usesAppleDefaultBackground: Bool { appleBackground }
    }

    private let themeBackground = UIColor(red: 0.98, green: 0.85, blue: 0.68, alpha: 1) // cream
    private let themeBackdrop = UIColor.black.withAlphaComponent(0.4)

    private func resolve(
        _ configure: (StubResolver) -> Void = { _ in },
        appearance: UIUserInterfaceStyle = .light,
        background: UIColor? = nil,
        backdropEnabled: Bool = true
    ) -> UPSurfaceStyle {
        let stub = StubResolver()
        configure(stub)
        return stub.surfaceStyle(
            themeBackground: background ?? themeBackground,
            themeBackdrop: themeBackdrop,
            themeBackdropEnabled: backdropEnabled,
            appearance: appearance
        )
    }

    private func alpha(of color: UIColor?) -> CGFloat {
        var value: CGFloat = 0
        color?.getRed(nil, green: nil, blue: nil, alpha: &value)
        return value
    }

    // MARK: - Appearance from a themed colour

    func testLuminanceSelectsTheAppearanceAThemeColourIsAskingFor() {
        XCTAssertEqual(UPGlassMeasuredMetrics.interfaceStyle(matching: .white), .light)
        XCTAssertEqual(UPGlassMeasuredMetrics.interfaceStyle(matching: .black), .dark)
        XCTAssertEqual(UPGlassMeasuredMetrics.interfaceStyle(matching: themeBackground), .light)
        XCTAssertEqual(
            UPGlassMeasuredMetrics.interfaceStyle(matching: UIColor(white: 0.15, alpha: 1)), .dark)
        XCTAssertEqual(UPGlassMeasuredMetrics.interfaceStyle(matching: .blue), .dark)
        XCTAssertEqual(UPGlassMeasuredMetrics.interfaceStyle(matching: .green), .light)
    }

    // MARK: - Composition: not glass

    func testSolidSurfaceHonoursTheThemeCompletely() {
        let style = resolve { $0.allowsSurface = false }

        XCTAssertEqual(style.fill, .solid(themeBackground))
        XCTAssertEqual(style.backdrop, themeBackdrop)
        XCTAssertFalse(style.masksBackdrop)
        XCTAssertFalse(style.usesConcentricCorners, "The theme's radius stands when not glass")
        XCTAssertNil(resolve({ $0.allowsSurface = false }, backdropEnabled: false).backdrop)
    }

    // MARK: - Composition: glass

    func testAppleDefaultsUseUntintedGlassAndAppleDim() {
        let style = resolve()

        XCTAssertEqual(style.fill, .appleGlass(.light))
        XCTAssertEqual(alpha(of: style.backdrop), UPGlassMeasuredMetrics.backdropAlphaLight, accuracy: 0.001)
        XCTAssertTrue(style.masksBackdrop)
        XCTAssertTrue(style.usesConcentricCorners)
        let darkTheme = resolve(background: UIColor(white: 0.1, alpha: 1))
        XCTAssertEqual(
            darkTheme.fill, .appleGlass(.dark),
            "The colour is replaced, but a card configured dark must stay dark."
        )
        XCTAssertEqual(
            alpha(of: resolve(appearance: .dark).backdrop),
            UPGlassMeasuredMetrics.backdropAlphaDark,
            accuracy: 0.001
        )
    }

    func testCustomGlassOptionsPreserveTheConfiguredThemeValues() {
        let customFill = resolve { $0.appleBackground = false }
        let customBackdrop = resolve { $0.appleBackdrop = false }

        XCTAssertEqual(customFill.fill, .tintedGlass(themeBackground, alpha: 0.28))
        XCTAssertEqual(customBackdrop.backdrop, themeBackdrop)
        XCTAssertTrue(customFill.usesConcentricCorners)
        XCTAssertTrue(customBackdrop.usesConcentricCorners)
    }

    func testMaskingRequiresBothABackdropAndResolverPermission() {
        let noBackdrop = resolve(backdropEnabled: false)
        let refused = resolve { $0.masks = false }

        XCTAssertNil(noBackdrop.backdrop)
        XCTAssertFalse(noBackdrop.masksBackdrop)
        XCTAssertNotNil(refused.backdrop)
        XCTAssertFalse(refused.masksBackdrop)
    }

    // MARK: - Config wiring

    func testConfigFlagsReachSurfaceResolution() {
        let config = Userpilot.Config(token: "TOKEN")
            .liquidGlassDefaultBackdrop(false)
            .liquidGlassDefaultBackground(false)
        let resolver = GlassCapabilityResolver(
            config: config,
            environment: GlassEnvironment(isPlatformCapable: true, hostRequiresLegacyDesign: false)
        )

        XCTAssertFalse(resolver.usesAppleDefaultBackdrop)
        XCTAssertFalse(resolver.usesAppleDefaultBackground)
    }
}
