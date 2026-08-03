//
//  LikertCollectionViewCell.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2024 Userpilot. All rights reserved.

//  This file contains the implementation of the `LikertCollectionViewCell` class,
//  which represents an individual cell in the Likert scale collection view.
//  Each cell can display either a label or an image, depending on the type of the rating item it represents,
//  and visually reflects whether it is selected using the provided survey theme.

import UIKit

// MARK: - LikertCollectionViewCell

/// A custom collection view cell used to display items in a Likert scale, either with a label or an image.
internal class LikertCollectionViewCell: UICollectionViewCell {
    private let contentLabel = UILabel()
    private let contentImageView = UIImageView()

    // MARK: - Initialization

    /// Initializes the collection view cell and sets up the UI.
    /// - Parameter frame: The frame for the collection view cell.
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    /// Required initializer that is not implemented, as the cell is created programmatically.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup

    /// Configures the user interface elements of the cell, including the label and image view.
    private func setupUI() {
        contentView.addSubview(contentLabel)
        contentView.addSubview(contentImageView)

        // Disable autoresizing mask and set content mode for image view
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentImageView.translatesAutoresizingMaskIntoConstraints = false
        contentImageView.contentMode = .scaleAspectFit

        // Set corner radius for the content view and enable clipping
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true

        // Auto Layout constraints for the label and image view
        NSLayoutConstraint.activate([
            contentImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            contentImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            contentImageView.widthAnchor.constraint(equalToConstant: 22),
            contentImageView.heightAnchor.constraint(equalToConstant: 22),

            contentLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            contentLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    // MARK: - Cell Binding

    /// Binds data from the provided `ratingItem` and `surveyTheme` to the cell's UI elements.
    /// - Parameter ratingItem: The item representing the individual rating choice in the Likert scale.
    /// - Parameter surveyTheme: The theme that defines the visual appearance of the cell.
    func bindCell(
        ratingItem: RatingItem,
        surveyTheme: SurveyTheme?,
        npsTheme: NPSTheme?,
        isRTL: Bool
    ) {
        if isRTL {
            self.contentView.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
        // Show/hide the content label based on the rating item type
        contentLabel.isHidden = ratingItem.type != .numbers
        contentLabel.text = ratingItem.title
        contentLabel.font = UIFont.matching(
            fontName: fontFamily(surveyTheme, npsTheme), fontWeight: [],
            fontSize: CGFloat(ThemeHandler.DefaultValues.surveyTitleTextSize))

        // Show/hide the content image based on the rating item type
        contentImageView.isHidden = ratingItem.type == .numbers
        contentImageView.image = ratingItem.image

        applySelectionAppearance(
            ratingItem: ratingItem, surveyTheme: surveyTheme, npsTheme: npsTheme)
    }

    /// The part of the binding that depends on selection, split out so a tap can cross-fade just
    /// this rather than rebuilding the whole cell.
    private func applySelectionAppearance(
        ratingItem: RatingItem,
        surveyTheme: SurveyTheme?,
        npsTheme: NPSTheme?
    ) {
        // Update background and text colors based on selection state
        contentView.backgroundColor = ratingItem.isSelected ?
            primaryColor(surveyTheme, npsTheme) : secondaryColor(surveyTheme, npsTheme)

        contentImageView.tintColor = ratingItem.isSelected ?
            contentSelectedColor(surveyTheme, npsTheme) :
            contentUnselectedColor(surveyTheme, npsTheme)

        contentLabel.textColor = ratingItem.isSelected ?
            contentSelectedColor(surveyTheme, npsTheme)  :
            contentUnselectedColor(surveyTheme, npsTheme)
    }

    // MARK: - Selection feedback

    /// How far the cell grows at the peak of a tap.
    ///
    /// Small on purpose: these cells sit a few points apart, and anything larger reads as the cell
    /// colliding with its neighbours rather than responding to a touch.
    private static let pulseScale: CGFloat = 1.18

    /// Springs the cell up and back down, as direct feedback for the tap that selected it.
    ///
    /// Only the cell that was actually tapped pulses. A Likert selection fills every cell up to the
    /// tapped one, and pulsing all of them at once reads as the whole row twitching; the fill itself
    /// is what communicates the range, and it cross-fades (see ``bindCell(ratingItem:…)``).
    ///
    /// The spring is `usingSpringWithDamping` rather than the iOS 17 `springDuration:bounce:` API so
    /// there is no availability branch on a deployment target of iOS 13 — the motion is the same
    /// shape either way.
    ///
    /// Growing past the collection view's edges is possible because that view is built with
    /// `clipsToBounds = false` — see `UPLikertView.collectionView`. Its height is pinned to exactly
    /// the rows it holds, so a clipping row would trim this scale flat.
    func pulse() {
        // Restarting from identity rather than from wherever a previous animation got to; a fast
        // double-tap would otherwise compound the scale.
        transform = .identity

        // Reduce Motion: the fill already communicates the selection, so the scale is the part that
        // can simply not happen. Nothing else about the cell changes.
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        UIView.animate(
            withDuration: 0.14,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.transform = CGAffineTransform(
                    scaleX: Self.pulseScale, y: Self.pulseScale)
            },
            completion: { _ in
                UIView.animate(
                    withDuration: 0.42,
                    delay: 0,
                    usingSpringWithDamping: 0.45,
                    initialSpringVelocity: 0.6,
                    options: [.allowUserInteraction, .beginFromCurrentState],
                    animations: { self.transform = .identity }
                )
            }
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // A cell recycled mid-pulse would otherwise arrive already scaled.
        transform = .identity
    }

    /// Re-applies the selection colours with a cross-fade.
    ///
    /// Used when a tap changes which cells are filled. Rebinding the visible cells is deliberate —
    /// `reloadData()` would replace the cell that is mid-pulse, cancelling the animation with it.
    func rebindWithCrossFade(
        ratingItem: RatingItem,
        surveyTheme: SurveyTheme?,
        npsTheme: NPSTheme?
    ) {
        UIView.transition(
            with: contentView,
            duration: 0.22,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: {
                self.applySelectionAppearance(
                    ratingItem: ratingItem, surveyTheme: surveyTheme, npsTheme: npsTheme)
            }
        )
    }

    private func fontFamily(
        _ surveyTheme: SurveyTheme?,
        _ npsTheme: NPSTheme?
    ) -> String? {
        surveyTheme?.fontFamily ?? npsTheme?.fontFamily
    }

    private func primaryColor(
        _ surveyTheme: SurveyTheme?,
        _ npsTheme: NPSTheme?
    ) -> UIColor? {
        surveyTheme?.primaryColor ?? npsTheme?.primaryColor ?? .black
    }

    private func secondaryColor(
        _ surveyTheme: SurveyTheme?,
        _ npsTheme: NPSTheme?
    ) -> UIColor? {
        surveyTheme?.secondaryColor ?? npsTheme?.secondaryColor ?? .black.withAlphaComponent(0.2)
    }

    private func contentSelectedColor(
        _ surveyTheme: SurveyTheme?,
        _ npsTheme: NPSTheme?
    ) -> UIColor? {
        surveyTheme?.primaryColorAsString.invertColor().color ??
        npsTheme?.primaryColorAsString.invertColor().color ?? .black
    }

    private func contentUnselectedColor(
        _ surveyTheme: SurveyTheme?,
        _ npsTheme: NPSTheme?
    ) -> UIColor? {
        surveyTheme?.textColor ?? npsTheme?.textColor ?? .black
    }
}
