//
//  UPCardMetrics.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The one definition of the padding between a card's edge and the content inside it.
//

import UIKit

/// Padding between a bottom sheet's or centre dialog's edge and its content.
///
/// This exists because the spacing had drifted into four places at once. Each content view
/// (`SlideOutContainerView`, `SurveyContainerView`, `NPSContainerView`) pinned its own stack
/// differently, and the two containers then took a per-call-site offset — `withoutMargin: true`
/// meaning "−20" on the sheet and `withMargin: -40` on the dialog — to cancel out whatever the
/// content view had done. The result was that the same card had four different top insets depending
/// on which experience filled it: 0 for a carousel, −20 for NPS, +5 for a survey sheet and −15 for a
/// survey dialog.
///
/// The rule now: **the container owns the padding, the content contributes none.** Content views pin
/// their stack flush to their own edges, the container applies these values, and no call site passes
/// an offset. Anything that needs different spacing changes it here, once, for every experience type.
internal enum UPCardMetrics {

    /// Space between a bottom sheet's top edge and its content.
    ///
    /// Small on purpose: it sits above the dismiss button, and a full margin left the sheet looking
    /// top-heavy once the iOS 26 corners became rounder. Large enough to keep that button clear of
    /// the corner curve, which is what Apple's guidance asks for.
    static let sheetContentTop = ThemeHandler.DefaultValues.contentTopMargin

    /// Space between a **solid** bottom sheet's content and the bottom safe area.
    ///
    /// An eighth of the standard bottom margin. A solid sheet is flush with the screen edge, so its
    /// content has to stop at the safe area or it would sit under the home indicator.
    static let sheetContentBottom = ThemeHandler.DefaultValues.contentBottomMargin / 8

    /// Space between a **glass** bottom sheet's content and the card's own bottom edge.
    ///
    /// A glass sheet floats 8 pt off the screen, so measuring from the safe area leaves the whole
    /// home-indicator band — around 26 pt on a modern iPhone — as empty card below the content. That
    /// is what made the gap under a survey's step indicator look so large: it was not a margin at
    /// all, it was the band between the safe area and the card's edge, and no margin value could
    /// shrink it.
    ///
    /// Measuring from the card's edge instead puts content the same distance from the sheet's
    /// boundary regardless of the device's indicator inset, which is how Apple's own floating sheets
    /// are laid out. 8 pt of card inset plus this leaves ~11 pt clear of the indicator itself.
    static let sheetGlassContentBottom: CGFloat = 16

    /// Space between a centre dialog's top edge and its content.
    static let dialogContentTop = ThemeHandler.DefaultValues.contentMargin / 2

    /// Space between a centre dialog's content and its bottom edge.
    ///
    /// The full margin, unlike the sheet: a centred dialog has no display edge below it to sit close
    /// to, so the tighter spacing would read as unbalanced rather than deliberate.
    static let dialogContentBottom = ThemeHandler.DefaultValues.contentBottomMargin

    /// Horizontal padding. The same for both, and for every experience type.
    static let contentHorizontal = ThemeHandler.DefaultValues.contentMargin
}
