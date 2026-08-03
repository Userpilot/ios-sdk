//
//  GlassCapabilityResolver.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The one place that decides whether Liquid Glass may be used. Keeping this decision
//  here — rather than as an `#available` ladder in every view — is what keeps the glass
//  adoption maintainable and unit-testable.
//

import UIKit

// MARK: - Environment

/// The parts of the glass decision that come from the build and the host app rather than
/// from `Userpilot.Config`.
///
/// Split out as a value type so tests can simulate an older OS or a legacy-design host on
/// a machine that only has the iOS 26 SDK installed. Production code always uses
/// ``current``.
internal struct GlassEnvironment: Equatable {

    /// Whether this build can emit Liquid Glass *and* the OS can render it.
    ///
    /// Combines both gates from the adoption plan: the compile-time gate (was the SDK built
    /// with an Xcode that has the iOS 26 SDK?) and the runtime gate (is the device on
    /// iOS 26?). Either one failing means no glass.
    let isPlatformCapable: Bool

    /// Whether the host app opted out of the iOS 26 design system via the
    /// `UIDesignRequiresCompatibility` Info.plist key.
    ///
    /// When the host renders its own UI in the pre-iOS 26 style, glass overlays from the
    /// SDK would look foreign, so we follow the host.
    let hostRequiresLegacyDesign: Bool

    /// The real environment.
    static var current: GlassEnvironment {
        GlassEnvironment(
            isPlatformCapable: Self.resolvePlatformCapability(),
            hostRequiresLegacyDesign: Self.resolveHostLegacyDesignPreference()
        )
    }

    /// Both gates from plan §6.2 in the one place they need to exist.
    ///
    /// The `#if compiler(>=6.2)` arm matters as much as the `#available` check: Swift does
    /// not name-resolve symbols inside an inactive `#if` branch, so this is what allows the
    /// SDK to keep compiling for customers still on Xcode 16.x, where `UIGlassEffect` and
    /// friends do not exist in the SDK at all.
    ///
    /// It must be `compiler(>=)` and not `swift(>=)` — the package builds in Swift 5
    /// language mode (`swift-tools-version:5.3`, `spec.swift_version = "5.0"`), so
    /// `#if swift(>=6.2)` would always be false and glass would never compile in.
    private static func resolvePlatformCapability() -> Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return true
        } else {
            return false
        }
        #else
        return false
        #endif
    }

    /// Reads `UIDesignRequiresCompatibility`, tolerating either a real boolean or the
    /// string forms Xcode's plist editor can produce.
    private static func resolveHostLegacyDesignPreference() -> Bool {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility")
        else { return false }

        if let flag = raw as? Bool { return flag }
        if let number = raw as? NSNumber { return number.boolValue }
        if let text = raw as? String {
            return ["true", "yes", "1"].contains(text.lowercased())
        }
        return false
    }
}

// MARK: - Resolver

/// Default ``GlassCapabilityResolving`` implementation.
///
/// Evaluates the inputs as a short-circuiting AND, in the order documented in the adoption
/// plan (§7): platform capability, host legacy-design opt-out, the master `Config` switch,
/// then the per-kind opt-ins. No UIKit rendering happens here, which is what makes the
/// whole decision matrix testable.
internal final class GlassCapabilityResolver: GlassCapabilityResolving {

    // MARK: Properties

    private let config: Userpilot.Config
    private let environment: GlassEnvironment

    /// How many Userpilot overlay windows are on screen right now.
    ///
    /// Evaluated per call rather than captured at construction, because it changes as
    /// experiences appear and disappear. Injectable so tests can simulate a multi-instance
    /// host without building real windows.
    private let visibleOverlayWindowCount: () -> Int

    /// The last surface decision written to the log, so an unchanged one is not written again.
    private var lastLoggedSurfaceDecision: String?

    // MARK: Initializers

    /// DI entry point. Registered in `Userpilot.initializeContainer()`.
    init(container: DIContainer) {
        self.config = container.resolve(Userpilot.Config.self)
        self.environment = .current
        self.visibleOverlayWindowCount = { ExperienceOverlayWindow.visibleWindowCount() }
    }

    /// Testing / QA seam. Lets a test pin the environment and the overlay-window count so the
    /// decision matrix can be exercised without an older OS or a real multi-instance host.
    init(
        config: Userpilot.Config,
        environment: GlassEnvironment,
        visibleOverlayWindowCount: @escaping () -> Int = { 1 }
    ) {
        self.config = config
        self.environment = environment
        self.visibleOverlayWindowCount = visibleOverlayWindowCount
    }

    // MARK: GlassCapabilityResolving

    func allowsGlass(for kind: GlassElementKind, surfaceMaterial: SurfaceMaterial?) -> Bool {
        // Inputs 1+2 — built without the iOS 26 SDK, or running below iOS 26.
        guard environment.isPlatformCapable else {
            if kind == .sheetOrDialog {
                logSurfaceDecision(false, reason: "built without the iOS 26 SDK, or running below iOS 26")
            }
            return false
        }

        // Input 3 — the host app asked the system for the pre-iOS 26 design.
        guard !environment.hostRequiresLegacyDesign else {
            if kind == .sheetOrDialog {
                logSurfaceDecision(false, reason: "host sets UIDesignRequiresCompatibility")
            }
            return false
        }

        // Input 4 — global kill switch. Absolute: nothing below can re-enable glass.
        guard config.liquidGlassEnabled else {
            if kind == .sheetOrDialog {
                logSurfaceDecision(false, reason: "Config.liquidGlass(false)")
            }
            return false
        }

        switch kind {
        case .chrome:
            // Chrome carries no theme colour contract and has no backend dependency, so
            // availability plus the global switch is the whole decision.
            return true

        case .sheetOrDialog:
            return allowsGlassSheetOrDialog(material: surfaceMaterial)

        case .fullScreen:
            return allowsGlassFullScreen()
        }
    }

    func glassTintAlpha(for style: UIUserInterfaceStyle) -> CGFloat {
        style == .dark
            ? config.liquidGlassTintAlphaDark
            : config.liquidGlassTintAlphaLight
    }

    var masksBackdropBehindGlassSurface: Bool {
        config.liquidGlassMaskedBackdropEnabled
    }

    var usesAppleDefaultBackdrop: Bool {
        config.liquidGlassDefaultBackdropEnabled
    }

    var usesAppleDefaultBackground: Bool {
        config.liquidGlassDefaultBackgroundEnabled
    }

    /// Read at animation time rather than cached, so toggling Reduce Motion in Settings takes effect
    /// on the next transition without the SDK observing anything.
    var reducesSDKMotion: Bool {
        config.liquidGlassAccessibilityAdaptationEnabled && UIAccessibility.isReduceMotionEnabled
    }

    var adaptsToAccessibilityChanges: Bool {
        config.liquidGlassAccessibilityAdaptationEnabled
    }

    // MARK: Private

    /// Independent opt-in. Deliberately NOT reachable through the sheet/dialog flag or the backend
    /// material field: a full-screen experience can hold dense, multi-section content and has no
    /// backdrop separating it from the host app, so it must be asked for by name.
    ///
    /// Overlay stacking applies here too, and more so than to a sheet: a full-screen surface covers
    /// everything behind it, so two of them is the worst case of the layering Apple warns about.
    /// That check used to be made for sheets and dialogs only.
    private func allowsGlassFullScreen() -> Bool {
        guard config.liquidGlassFullScreenEnabled else { return false }

        let overlayCount = visibleOverlayWindowCount()
        guard overlayCount <= 1 else {
            logSurfaceDecision(false, reason: "\(overlayCount) overlay windows visible")
            return false
        }
        return true
    }

    /// Surface precedence (plan §7.2): an explicit host call wins over the theme, and the
    /// default when neither speaks is `.solid` — so existing integrations are untouched.
    ///
    /// Additionally suppressed when more than one overlay window is on screen. Each Userpilot
    /// instance owns its own `ExperienceOverlayWindow`, so two instances showing an experience
    /// simultaneously would stack two glass surfaces — which is exactly the "crowding or
    /// layering Liquid Glass elements on top of each other" Apple warns against, arrived at by
    /// accident rather than by anyone's choice. Falling back to solid keeps both readable.
    private func allowsGlassSheetOrDialog(material: SurfaceMaterial?) -> Bool {
        let overlayCount = visibleOverlayWindowCount()
        guard overlayCount <= 1 else {
            logSurfaceDecision(false, reason: "\(overlayCount) overlay windows visible")
            return false
        }

        if let hostPreference = config.liquidGlassSheetsAndDialogsEnabled {
            logSurfaceDecision(
                hostPreference,
                reason: "Config.liquidGlassSheetsAndDialogs(\(hostPreference))"
            )
            return hostPreference
        }
        if let material {
            logSurfaceDecision(material == .glass, reason: "theme material '\(material.rawValue)'")
            return material == .glass
        }
        logSurfaceDecision(
            SurfaceMaterial.default == .glass,
            reason: "Config.liquidGlassSheetsAndDialogs not set and theme has no material — defaulting"
        )
        return SurfaceMaterial.default == .glass
    }

    /// Reports why a card surface did or did not render as glass, **once per distinct answer**.
    ///
    /// There are six independent reasons a surface can come out solid, and from the outside they all
    /// look identical — "the glass isn't working". Logging the deciding factor turns that into a
    /// one-line answer in the console.
    ///
    /// The de-duplication is the point: resolution runs per view and per reused cell, so a carousel
    /// used to emit the same line dozens of times while nothing about the decision changed. Only a
    /// *transition* is worth a host's attention, so an unchanged verdict is dropped.
    private func logSurfaceDecision(_ allowed: Bool, reason: String) {
        let decision = "\(allowed)|\(reason)"
        guard decision != lastLoggedSurfaceDecision else { return }
        lastLoggedSurfaceDecision = decision

        config.logger.info(
            "🌠 Userpilot Liquid Glass -> surface: %{public}@, reason: %{public}@",
            allowed ? "glass" : "solid",
            reason
        )
    }
}
