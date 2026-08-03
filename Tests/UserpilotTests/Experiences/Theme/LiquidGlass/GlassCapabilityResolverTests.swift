//
//  GlassCapabilityResolverTests.swift
//  UserpilotTests
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Covers the Liquid Glass decision matrix: platform capability x host legacy-design
//  opt-out x master switch x per-kind opt-ins x theme material.
//
//  `GlassEnvironment` is injected rather than read from the running process, so the
//  "unsupported platform" rows are exercised on a machine that only has the iOS 26 SDK
//  and iOS 26 simulator runtimes installed. That gap is real — see
//  docs/liquid-glass/spike/RESULTS.md follow-up 4 — and this is how we cover it.
//

import XCTest
@testable import Userpilot

final class GlassCapabilityResolverTests: XCTestCase {

    // MARK: Helpers

    private let capable = GlassEnvironment(
        isPlatformCapable: true,
        hostRequiresLegacyDesign: false
    )

    private let incapable = GlassEnvironment(
        isPlatformCapable: false,
        hostRequiresLegacyDesign: false
    )

    private let legacyDesignHost = GlassEnvironment(
        isPlatformCapable: true,
        hostRequiresLegacyDesign: true
    )

    private func makeResolver(
        environment: GlassEnvironment,
        configure: (Userpilot.Config) -> Void = { _ in }
    ) -> GlassCapabilityResolver {
        let config = Userpilot.Config(token: "NX-00000")
        configure(config)
        return GlassCapabilityResolver(config: config, environment: environment)
    }

    // MARK: Defaults and global gates

    func testDefaultCapabilityMatrix() {
        let resolver = makeResolver(environment: capable)

        XCTAssertTrue(resolver.allowsGlass(for: .chrome))
        XCTAssertFalse(resolver.allowsGlass(for: .sheetOrDialog))
        XCTAssertFalse(resolver.allowsGlass(for: .fullScreen))
        XCTAssertTrue(Userpilot.Config(token: "NX-00000").liquidGlassEnabled)
    }

    func testEveryGlobalGateDisablesAllGlassKinds() {
        let blockedResolvers = [
            makeResolver(environment: incapable) { config in
                config.liquidGlassSheetsAndDialogs(true)
                config.liquidGlassFullScreen(true)
            },
            makeResolver(environment: legacyDesignHost) { config in
                config.liquidGlassSheetsAndDialogs(true)
                config.liquidGlassFullScreen(true)
            },
            makeResolver(environment: capable) { config in
                config.liquidGlass(false)
                config.liquidGlassSheetsAndDialogs(true)
                config.liquidGlassFullScreen(true)
            }
        ]
        let kinds: [GlassElementKind] = [.chrome, .sheetOrDialog, .fullScreen]

        for resolver in blockedResolvers {
            for kind in kinds {
                XCTAssertFalse(resolver.allowsGlass(for: kind, surfaceMaterial: .glass))
            }
        }
    }

    // MARK: Input 5/6 — surface precedence

    func testThemeMaterialControlsSurfaceWhenHostIsSilent() {
        let resolver = makeResolver(environment: capable)

        XCTAssertTrue(resolver.allowsGlass(for: .sheetOrDialog, surfaceMaterial: .glass))
        XCTAssertFalse(resolver.allowsGlass(for: .sheetOrDialog, surfaceMaterial: .solid))
    }

    func testExplicitHostSheetOptInWinsOverThemeSolid() {
        let resolver = makeResolver(environment: capable) { $0.liquidGlassSheetsAndDialogs(true) }
        XCTAssertTrue(resolver.allowsGlass(for: .sheetOrDialog, surfaceMaterial: .solid))
    }

    func testExplicitHostSheetOptOutWinsOverThemeGlass() {
        // The host developer must be able to override what the dashboard says.
        let resolver = makeResolver(environment: capable) { $0.liquidGlassSheetsAndDialogs(false) }
        XCTAssertFalse(resolver.allowsGlass(for: .sheetOrDialog, surfaceMaterial: .glass))
    }

    func testUnsetSheetFlagIsDistinguishableFromExplicitFalse() {
        // This is why the property is `Bool?`: "never called" must defer to the theme,
        // while "explicitly false" must beat the theme.
        let untouched = Userpilot.Config(token: "NX-00000")
        XCTAssertNil(untouched.liquidGlassSheetsAndDialogsEnabled)

        let optedOut = Userpilot.Config(token: "NX-00000")
        optedOut.liquidGlassSheetsAndDialogs(false)
        XCTAssertEqual(optedOut.liquidGlassSheetsAndDialogsEnabled, false)
    }

    // MARK: Input 7 — full-screen experiences

    func testFullScreenGlassRequiresItsOwnExplicitOptIn() {
        let optedIn = makeResolver(environment: capable) { $0.liquidGlassFullScreen(true) }
        let sheetOnly = makeResolver(environment: capable) {
            $0.liquidGlassSheetsAndDialogs(true)
        }
        let themeOnly = makeResolver(environment: capable)

        XCTAssertTrue(optedIn.allowsGlass(for: .fullScreen))
        XCTAssertFalse(sheetOnly.allowsGlass(for: .fullScreen))
        XCTAssertFalse(themeOnly.allowsGlass(for: .fullScreen, surfaceMaterial: .glass))
    }

    // MARK: Tint alpha

    func testTintAlphaDefaults() {
        let resolver = makeResolver(environment: capable)
        XCTAssertEqual(resolver.glassTintAlpha(for: .light), 0.28, accuracy: 0.0001)
        XCTAssertEqual(resolver.glassTintAlpha(for: .dark), 0.40, accuracy: 0.0001)
    }

    func testTintAlphaOverridesAndClamps() {
        let shared = makeResolver(environment: capable) { $0.liquidGlassTintAlpha(0.5) }
        let perStyle = makeResolver(environment: capable) {
            $0.liquidGlassTintAlpha(light: 0.1, dark: 0.9)
        }
        let clamped = makeResolver(environment: capable) {
            $0.liquidGlassTintAlpha(light: -3, dark: 42)
        }

        XCTAssertEqual(shared.glassTintAlpha(for: .light), 0.5, accuracy: 0.0001)
        XCTAssertEqual(shared.glassTintAlpha(for: .dark), 0.5, accuracy: 0.0001)
        XCTAssertEqual(perStyle.glassTintAlpha(for: .light), 0.1, accuracy: 0.0001)
        XCTAssertEqual(perStyle.glassTintAlpha(for: .dark), 0.9, accuracy: 0.0001)
        XCTAssertEqual(clamped.glassTintAlpha(for: .light), 0, accuracy: 0.0001)
        XCTAssertEqual(clamped.glassTintAlpha(for: .dark), 1, accuracy: 0.0001)
    }
}

// MARK: - SurfaceMaterial

final class SurfaceMaterialTests: XCTestCase {

    private func decode(_ json: String) throws -> SurfaceMaterial {
        try JSONDecoder().decode(SurfaceMaterial.self, from: Data(json.utf8))
    }

    func testDecodesKnownValuesCaseInsensitively() throws {
        XCTAssertEqual(try decode("\"solid\""), .solid)
        XCTAssertEqual(try decode("\"glass\""), .glass)
        XCTAssertEqual(try decode("\"GLASS\""), .glass)
        XCTAssertEqual(try decode("\"Solid\""), .solid)
    }

    func testUnknownValueFallsBackToSolid() throws {
        // A future backend value must never make an installed SDK render something
        // unintended — it degrades to the current appearance instead.
        XCTAssertEqual(try decode("\"frosted-neon\""), .solid)
    }

    func testDefaultIsSolid() {
        XCTAssertEqual(SurfaceMaterial.default, .solid)
    }
}
