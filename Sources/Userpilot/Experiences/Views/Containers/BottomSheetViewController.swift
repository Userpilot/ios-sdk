//
//  BottomSheetViewController.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 21/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  A customizable bottom sheet view controller that provides a smooth, dimmed, draggable
//  bottom sheet experience. It allows adding dynamic content, background customization,
//  and integrates gesture recognition for dismissing the sheet via a drag or tap action.
//

import Foundation
import UIKit

internal class BottomSheetViewController: UIViewController {

    // MARK: - UI Components

    /// Main bottom sheet container view with a rounded top and clipped corners.
    /// Not private: styled from `BottomSheetViewController+Glass.swift`.
    lazy var mainContainerView: UPCardView = {
        let view = UPCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.applyCorners(.fixed(ThemeHandler.DefaultValues.cardCornerRadius))
        return view
    }()

    /// View to hold dynamic content for the bottom sheet.
    ///
    /// This is where the card's padding is applied — see ``UPCardMetrics``. Content added through
    /// `setContent(content:)` is pinned flush inside it.
    lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Top bar view for dragging the bottom sheet to dismiss
    private lazy var topBarView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Dimmed background view that appears behind the bottom sheet.
    /// Not private: masked from `BottomSheetViewController+Glass.swift`.
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

    // MARK: - Properties

    /// Minimum vertical drag height required to dismiss the bottom sheet
    private let minDismissiblePanHeight: CGFloat = 20
    /// Minimum spacing between the top edge of the view and the bottom sheet
    private var minTopSpacing: CGFloat = 100
    private var appSemanticContentAttribute: UIUserInterfaceLayoutDirection?

    // MARK: - Liquid Glass

    /// Decides whether this sheet's surface renders as Liquid Glass. Set by the subclass from
    /// its view model, before the theme is applied.
    var glassResolver: GlassCapabilityResolving?

    /// The glass background installed behind the sheet's content, when glass is in use.
    /// Read by `BottomSheetViewController+Glass.swift`.
    var glassBackground: UPGlassEffectView?

    /// Radius currently applied to the sheet's **bottom** corners, needed to cut a matching hole in
    /// the backdrop. This is the display-concentric value when the sheet renders as glass.
    var appliedCornerRadius = ThemeHandler.DefaultValues.cardCornerRadius

    /// Radius currently applied to the sheet's **top** corners.
    ///
    /// Separate from the bottom pair because a sheet sits against the display at the bottom and
    /// against nothing at the top, so one radius cannot be right for both — which is why UIKit's own
    /// sheet uses ~36 pt on top against ~53 pt below.
    var appliedTopCornerRadius = ThemeHandler.DefaultValues.cardCornerRadius

    /// The radius the theme asked for, kept as the floor when the display-concentric radius is
    /// measured. See `glassCornerRadius()`.
    var themeCornerRadius = ThemeHandler.DefaultValues.cardCornerRadius

    /// The appearance resolved for this sheet, held so a later layout pass can re-apply it without
    /// re-deciding anything. See `GlassCapabilityResolving.surfaceStyle(...)`.
    var surfaceStyle: UPSurfaceStyle?

    /// Whether the backdrop should have the sheet's shape cut out of it.
    var masksBackdrop = false

    /// The inputs the current surface was resolved from, so it can be resolved again.
    var lastSurfaceInputs: UPSurfaceInputs?

    /// The card-shaped hole cut out of the backdrop, owned so repeated layout reuses it.
    let backdropMask = UPBackdropMask()

    /// Suppresses the backdrop mask while the sheet is moving.
    ///
    /// The mask is a static path cut at the sheet's frame, but the sheet animates in and out
    /// under a transform. An un-suppressed mask would sit at the sheet's *resting* position
    /// while the sheet is still travelling — showing an undimmed, card-shaped ghost during
    /// presentation, and leaving one behind after dismissal.
    ///
    /// Starts `true` so nothing is cut until the sheet has settled.
    var suspendsBackdropMask = true

    /// Edge constraints, held so the sheet can be inset from the display edges when it renders
    /// as glass. See `applyGlassInset(_:)`.
    /// Top inset of the content inside the sheet.
    ///
    /// The content was previously pinned flush to the container's top. That was fine at a 12 pt
    /// radius but clipped the dismiss button against the much rounder iOS 26 corners — the case
    /// Apple's guidance covers when it says to check for "content and controls that might appear
    /// too close to rounder sheet corners".
    var contentTopConstraint: NSLayoutConstraint?

    /// Horizontal content constraints, held because the content is re-parented into the glass
    /// effect's content view when the surface renders as glass. See `hostContent(usesGlass:)`.
    var contentLeadingConstraint: NSLayoutConstraint?
    var contentTrailingConstraint: NSLayoutConstraint?

    var leadingInsetConstraint: NSLayoutConstraint?
    var trailingInsetConstraint: NSLayoutConstraint?
    var bottomInsetConstraint: NSLayoutConstraint?

    /// The content's bottom measured from the safe area — used while the sheet is solid, and so
    /// flush with the screen edge.
    var contentBottomSafeAreaConstraint: NSLayoutConstraint?

    /// The content's bottom measured from the card's own edge — used while the sheet is glass, and
    /// so floating above the safe area. Exactly one of these two is ever active.
    var contentBottomCardConstraint: NSLayoutConstraint?

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        appSemanticContentAttribute = UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute)
        setupViews()
        observeSurfaceInvalidations()
        // setupGestures()
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
        animatePresent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The display's curvature can only be measured once the sheet is in a window, which it is
        // by now but was not when the theme was applied. Must run before the mask, which is cut
        // from the radius this may change.
        refreshGlassCornerRadiusIfNeeded()
        // The backdrop mask is cut from the sheet's resolved frame, so it has to be recomputed
        // whenever that frame changes — rotation, keyboard, or content-driven height changes.
        updateBackdropMask()
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        guard flag else {
            super.dismiss(animated: false, completion: completion)
            return
        }
        dismissBottomSheet(completion: completion)
    }

    /// Re-resolves the surface when the interface style changes under a presented experience: the
    /// theme's colours, the glass tint and the backdrop are all resolved for one appearance, so a
    /// light card left on screen through a switch to dark would keep light values. Gated on
    /// `Config.liquidGlassAccessibilityAdaptation(_:)`.
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

}

// MARK: - Setup Views

private extension BottomSheetViewController {

    /// Set up the views for the bottom sheet and dimmed background
    func setupViews() {
        view.backgroundColor = .clear

        // Add dimmed background view
        view.addSubview(dimmedView)
        NSLayoutConstraint.activate([
            dimmedView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimmedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Add bottom sheet container view
        view.addSubview(mainContainerView)
        leadingInsetConstraint = mainContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        trailingInsetConstraint = mainContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        bottomInsetConstraint = mainContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            leadingInsetConstraint,
            trailingInsetConstraint,
            bottomInsetConstraint,
            mainContainerView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: minTopSpacing)
        ].compactMap { $0 })

        // Add top draggable bar view
//        mainContainerView.addSubview(topBarView)
//        NSLayoutConstraint.activate([
//            topBarView.topAnchor.constraint(equalTo: mainContainerView.topAnchor),
//            topBarView.leadingAnchor.constraint(equalTo: mainContainerView.leadingAnchor),
//            topBarView.trailingAnchor.constraint(equalTo: mainContainerView.trailingAnchor),
//            topBarView.heightAnchor.constraint(equalToConstant: 20)
//        ])

        // Add content view. Every one of these is held by reference because the content is
        // re-parented into the glass effect's content view when the surface resolves glass, which
        // means the same equations are rebuilt against a coincident host — see
        // `hostContent(usesGlass:)`. Two references for the bottom, one active at a time: a solid
        // sheet is flush with the screen so it measures from the safe area, a glass sheet floats
        // above it so it measures from its own edge.
        mainContainerView.addSubview(contentView)
        contentTopConstraint = contentView.topAnchor.constraint(equalTo: mainContainerView.topAnchor)
        contentLeadingConstraint = contentView.leadingAnchor.constraint(
            equalTo: mainContainerView.leadingAnchor,
            constant: UPCardMetrics.contentHorizontal)
        contentTrailingConstraint = contentView.trailingAnchor.constraint(
            equalTo: mainContainerView.trailingAnchor,
            constant: UPCardMetrics.contentHorizontal.negative)
        contentBottomSafeAreaConstraint = contentView.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: UPCardMetrics.sheetContentBottom.negative)
        contentBottomCardConstraint = contentView.bottomAnchor.constraint(
            equalTo: mainContainerView.bottomAnchor,
            constant: UPCardMetrics.sheetGlassContentBottom.negative)
        NSLayoutConstraint.activate(
            [contentTopConstraint, contentLeadingConstraint, contentTrailingConstraint,
             contentBottomSafeAreaConstraint].compactMap { $0 }
        )

        /// prepare the view for slide in animation
        dimmedView.alpha = 0
        mainContainerView.transform = CGAffineTransform(translationX: 0, y: view.frame.height)
    }
}

// MARK: - Setup Gestures

private extension BottomSheetViewController {

    /// Set up tap and pan gestures for dismissing the bottom sheet
    func setupGestures() {
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapDimmedView))
//        dimmedView.addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false
        topBarView.addGestureRecognizer(panGesture)
    }

    /// Handle tap gesture on the dimmed view to dismiss the bottom sheet
    @objc func handleTapDimmedView() {
        dismissBottomSheet()
    }

    /// Handle pan gesture to track dragging and dismiss the bottom sheet when necessary
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let isDraggingDown = translation.y > 0
        guard isDraggingDown else { return }

        let pannedHeight = translation.y
        let currentY = view.frame.height - mainContainerView.frame.height

        switch gesture.state {
        case .changed:
            mainContainerView.frame.origin.y = currentY + pannedHeight
        case .ended:
            if pannedHeight >= minDismissiblePanHeight {
                dismissBottomSheet()
            } else {
                mainContainerView.frame.origin.y = currentY
            }
        default:
            break
        }
    }
}

// MARK: - Animations

extension BottomSheetViewController {

    /// Animate the presentation of the bottom sheet
    func animatePresent() {
        // Reduce Motion: arrive in place rather than travelling. The sheet is already positioned
        // under a transform, so dropping it with no animation is the whole substitution.
        if glassResolver?.reducesSDKMotion == true {
            mainContainerView.transform = .identity
            mainContainerView.alpha = 0
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                self?.mainContainerView.alpha = 1
                self?.dimmedView.alpha = 1
            }, completion: { [weak self] _ in
                self?.suspendsBackdropMask = false
                self?.updateBackdropMask()
            })
            return
        }

        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.mainContainerView.transform = .identity
        }, completion: { [weak self] _ in
            // The sheet slides in under a transform, so its frame is only final once the
            // animation settles. Cutting the mask earlier would show an undimmed card-shaped
            // hole at the resting position while the sheet is still travelling.
            self?.suspendsBackdropMask = false
            self?.updateBackdropMask()
        })
        UIView.animate(withDuration: 0.4) { [weak self] in
            self?.dimmedView.alpha = 1
        }
    }

    /// Dismiss the bottom sheet with an animation
    func dismissBottomSheet(completion: (() -> Void)? = nil) {
        // The sheet leaves by *sliding*, which glass handles correctly — the material travels with
        // the container. Nothing about the surface is touched here: swapping it to an opaque fill
        // would flash the themed colour for the whole animation.
        suspendsBackdropMask = true
        updateBackdropMask()

        let reducesMotion = glassResolver?.reducesSDKMotion ?? false
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            guard let self else { return }
            self.dimmedView.alpha = 0
            if reducesMotion {
                self.mainContainerView.alpha = 0
            } else {
                self.mainContainerView.transform = CGAffineTransform(
                    translationX: 0, y: self.mainContainerView.frame.height)
            }
        }, completion: { [weak self] _ in
            self?.dismiss(animated: false, completion: completion)
        })
    }
}

// MARK: - Public APIs

extension BottomSheetViewController {

    /// Set the dynamic content for the bottom sheet
    /// Fills the sheet with a content view.
    ///
    /// The content is pinned flush — the sheet's padding is applied once, to `contentView`, and comes
    /// from ``UPCardMetrics``. There is deliberately no per-call-site offset: the parameter that used
    /// to exist (`withoutMargin`, meaning −20) was cancelling out padding that survey and NPS content
    /// views added themselves, which is how four experience types ended up with four different top
    /// insets in the same card.
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
}
