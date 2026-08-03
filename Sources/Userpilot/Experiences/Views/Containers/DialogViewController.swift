//
//  DialogViewController.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A view controller that presents a modal dialog with a customizable content area.
//  The dialog features a dimmed background and smooth presentation and dismissal animations.
//  It allows dynamic content to be added and provides options for customizing the background color.
//

import Foundation
import UIKit

internal class DialogViewController: UIViewController {

    // MARK: - UI Elements

    /// Main container view for the dialog
    /// Not private: styled and masked from `DialogViewController+Glass.swift`.
    lazy var mainContainerView: UPCardView = {
        let view = UPCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.applyCorners(.fixed(ThemeHandler.DefaultValues.cardCornerRadius))
        return view
    }()

    /// View to hold dynamic content within the dialog
    lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Dimmed background view for the dialog
    /// Not private: masked from `DialogViewController+Glass.swift`.
    lazy var dimmedView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alpha = 0
        view.addTapGesture { [weak self] in
            self?.view.endEditing(true)
        }
        return view
    }()

    private var mainContainerWidthConstraint: NSLayoutConstraint?
    private var appSemanticContentAttribute: UIUserInterfaceLayoutDirection?

    // MARK: - Liquid Glass

    /// Decides whether this dialog's surface renders as Liquid Glass. Set by the subclass from
    /// its view model, before the theme is applied.
    var glassResolver: GlassCapabilityResolving?

    /// How this dialog animates in and out, from `Config.dialogAnimation(_:)`. Set by the
    /// subclass from its view model. Applies to centred dialogs only — the bottom sheet always
    /// slides, because that is the gesture its shape implies.
    var dialogAnimation: Userpilot.DialogAnimation = .fade

    /// The glass background installed behind the dialog's content, when glass is in use.
    /// Not private: `DialogViewController+Glass.swift` hosts the content inside its content view.
    var glassBackground: UPGlassEffectView?

    /// Corner radius currently applied, needed to cut a matching hole in the backdrop.
    var appliedCornerRadius = ThemeHandler.DefaultValues.cardCornerRadius

    /// Whether the backdrop should have the dialog's shape cut out of it.
    var masksBackdrop = false

    /// The inputs the current surface was resolved from, so it can be resolved again.
    var lastSurfaceInputs: UPSurfaceInputs?

    /// The content's constraints, held because the content is re-parented into the glass effect's
    /// content view when the surface renders as glass. See `hostContent(usesGlass:)`.
    var contentHostConstraints: [NSLayoutConstraint] = []

    /// The card-shaped hole cut out of the backdrop, owned so repeated layout reuses it.
    let backdropMask = UPBackdropMask()

    /// Suppresses the backdrop mask while the dialog is animating.
    ///
    /// The mask is a static path cut at the dialog's resting frame, so leaving it in place while
    /// the dialog moves or fades exposes an undimmed, card-shaped rectangle sitting where the
    /// dialog is going to be — and, on dismissal, where it used to be. That rectangle is the
    /// ghost reported during development, reproduced in the fade spike. It is not the glass
    /// material: fading the container removes the material cleanly.
    var suspendsBackdropMask = true

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        observeSurfaceInvalidations()
        // This flag tells automatic screen tracking to ignore screens that the SDK is presenting
        objc_setAssociatedObject(
            self,
            &ScreenNameTracker.untrackedScreenKey,
            true,
            .OBJC_ASSOCIATION_RETAIN
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appSemanticContentAttribute = UIView.userInterfaceLayoutDirection(
           for: self.view.semanticContentAttribute)
        animatePresent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The mask is cut from the dialog's resolved frame, which changes on rotation and when
        // the width constraint is recomputed.
        updateBackdropMask()
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        guard flag else {
            super.dismiss(animated: false, completion: completion)
            return
        }
        dismissDialog(completion: completion)
    }

    /// Re-resolves the surface when the interface style changes under a presented dialog. See the
    /// sheet's equivalent; gated on `Config.liquidGlassAccessibilityAdaptation(_:)`.
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        guard glassResolver?.adaptsToAccessibilityChanges == true,
              traitCollection.userInterfaceStyle != previous?.userInterfaceStyle
        else { return }
        reapplySurfaceStyle()
    }

    deinit {
        UIView.appearance().semanticContentAttribute = appSemanticContentAttribute == .leftToRight
        ? .forceLeftToRight : .forceRightToLeft
    }

    /// Calculates the dialog width ratio based on the given size.
    /// - Parameter size: The size parameter from the transition method.
    /// - Returns: A CGFloat representing the width ratio.
    private func calculateDialogWidthRatio() -> CGFloat {
        var size = 0.9
        if isLandscape {
            size = 0.7
        }
        return size
    }

    // MARK: - Setup Views
    /// Sets up the view hierarchy and constraints for the dialog.
    private func setupViews() {
        view.backgroundColor = .clear
        view.addSubview(dimmedView)

        // Constraints for the dimmed background view
        NSLayoutConstraint.activate([
            dimmedView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimmedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Add the main container view to the dialog
        view.addSubview(mainContainerView)

        // Set up the main container width constraint
        let widthRatio = self.calculateDialogWidthRatio()
        let widthConstraint = mainContainerView.widthAnchor.constraint(
            equalToConstant: screenWidth * widthRatio)
        mainContainerWidthConstraint = widthConstraint

        // Center the main container view and set its width
        NSLayoutConstraint.activate([
            mainContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            widthConstraint
        ])

        // Set up the content view within the main container
        contentView.translatesAutoresizingMaskIntoConstraints = false
        hostContent(in: mainContainerView)

        dimmedView.alpha = 0
        mainContainerView.alpha = 0
    }
}

// MARK: - Public APIs

extension DialogViewController {

    /// Sets the content of the dialog.
    /// - Parameter content: A UIView to be displayed in the dialog.
    /// Fills the dialog with a content view.
    ///
    /// Pinned flush, for the reason given on `BottomSheetViewController.setContent(content:)`: the
    /// padding belongs to the container and comes from ``UPCardMetrics``. The offset this used to
    /// take (`withMargin`, passed as −40 by the survey dialog) was compensating for padding inside
    /// the content view.
    func setContent(content: UIView) {
        contentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            content.topAnchor.constraint(equalTo: contentView.topAnchor),
            content.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        view.layoutIfNeeded()
    }

    /// Sets the background color of the main container view.
    /// - Parameter color: The UIColor to set as the background color.
    /// `ExperienceTheme` has no card radius field, so the SDK default stands — the pre-iOS 26 value,
    /// since this argument is read only when the surface resolves solid. A glass dialog replaces it
    /// with the measured alert radius.
    func setBackgroundColor(_ theme: ExperienceTheme) {
        applySurfaceStyle(
            backgroundColor: theme.backgroundColor,
            cornerRadius: ThemeHandler.DefaultValues.slideOutCornerRadius,
            backdropEnabled: theme.backdropEnabled,
            backdropColor: theme.backdropBackground,
            surfaceMaterial: theme.surfaceMaterial
        )
    }

    /// Customize the background color of the dialog for `SurveyTheme`
    func setBackgroundColor(_ theme: SurveyTheme) {
        applySurfaceStyle(
            backgroundColor: theme.backgroundColor,
            cornerRadius: theme.borderRadius,
            backdropEnabled: theme.backdropEnabled,
            backdropColor: theme.backdropBackground,
            surfaceMaterial: theme.surfaceMaterial
        )
    }
}

// MARK: - Surface styling

extension DialogViewController {

    /// Paints the dialog's surface and its backdrop, from the appearance the resolver produced.
    ///
    /// Identical in structure to `BottomSheetViewController.applySurfaceStyle` — both apply the
    /// same ``UPSurfaceStyle`` and neither decides anything itself. The one difference is the
    /// radius: a centred dialog is nowhere near the display's corners, so there is nothing to be
    /// concentric with, and Apple's own alert radius is the right default instead.
    func applySurfaceStyle(
        backgroundColor: UIColor,
        cornerRadius: CGFloat,
        backdropEnabled: Bool,
        backdropColor: UIColor,
        surfaceMaterial: SurfaceMaterial? = nil
    ) {
        let style = glassResolver?.surfaceStyle(
            surfaceMaterial: surfaceMaterial,
            themeBackground: backgroundColor,
            themeBackdrop: backdropColor,
            themeBackdropEnabled: backdropEnabled,
            appearance: traitCollection.userInterfaceStyle
        ) ?? UPSurfaceStyle(
            fill: .solid(backgroundColor),
            backdrop: backdropEnabled ? backdropColor : nil,
            masksBackdrop: false,
            usesConcentricCorners: false
        )

        lastSurfaceInputs = UPSurfaceInputs(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            backdropEnabled: backdropEnabled,
            backdropColor: backdropColor,
            surfaceMaterial: surfaceMaterial
        )

        // Apple's alert radius when glass is in use — measured at 26.7 pt, uniform on all four
        // corners — otherwise the theme's. Either way it is a value the SDK can state, which is
        // what lets the backdrop hole be cut to the same shape.
        appliedCornerRadius = style.usesConcentricCorners
            ? UPGlassMeasuredMetrics.alertCornerRadius
            : cornerRadius
        mainContainerView.applyCorners(.fixed(appliedCornerRadius))

        // Published only when glass is in use: a control matches the card's shape as part of the
        // glass treatment, and otherwise the theme's own button radius stands untouched.
        mainContainerView.upCardCornerRadius = style.usesConcentricCorners ? appliedCornerRadius : nil

        if style.fill.isGlass {
            installGlassBackground(style.fill)
        } else {
            removeGlassBackground()
            UPGlassEffectView.install(style.fill, in: mainContainerView)
        }

        dimmedView.isHidden = style.backdrop == nil
        dimmedView.backgroundColor = style.backdrop

        masksBackdrop = style.masksBackdrop
        updateBackdropMask()

        // Same contract as the bottom sheet: a glass card tells its content where its border is, so
        // a full-bleed element can sit on it instead of inside the padding.
        let edge = style.fill.isGlass
            ? UPCardEdge(
                contentTopInset: UPCardMetrics.dialogContentTop,
                contentHorizontalInset: UPCardMetrics.contentHorizontal)
            : nil
        contentView.subviews
            .compactMap { $0 as? UPCardEdgeAware }
            .forEach { $0.applyCardEdge(edge) }
    }

    func installGlassBackground(_ fill: UPSurfaceFill) {
        removeGlassBackground()
        glassBackground = UPGlassEffectView.install(fill, in: mainContainerView)
        // The material takes the card's own shape — uniform here, since a centre dialog is nowhere
        // near the display's corners. Without it the effect is only clipped by the card, and UIKit
        // cannot draw its edge treatment along a curve it was never told about.
        glassBackground?.applyMaterialCorners(
            top: appliedCornerRadius,
            bottom: appliedCornerRadius
        )
    }

    func removeGlassBackground() {
        glassBackground?.removeFromSuperview()
        glassBackground = nil
    }

}

// The backdrop mask lives in `DialogViewController+Glass.swift`.

// MARK: - Update constraints on screen rotation

extension DialogViewController {
    func resetWidth(_ size: CGSize) {
        let widthRatio = self.calculateDialogWidthRatio()
        self.mainContainerWidthConstraint?.constant = size.width * widthRatio
        self.view.layoutIfNeeded()
    }
}

// MARK: - Show Dialog view controller

internal extension UIViewController {
    /// Presents a dialog view controller modally.
    /// - Parameter viewController: The DialogViewController to present.
    func presentDialog(viewController: UIViewController) {
        viewController.modalPresentationStyle = .overFullScreen
        present(viewController, animated: false, completion: nil)
    }
}
