//
//  CountryPickerPopupMenu.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 20/01/2025.
//
//  [Brief Description]
//  A custom popup menu for selecting a country from a list.
//

import UIKit

/// A custom popup menu for selecting a country from a list.
internal class CountryPickerPopupMenu: UIView {

    // MARK: - Properties

    /// A transparent background view to dim or detect taps outside the menu.
    private let transparentView = UIView()

    /// A table view to display the list of countries.
    private let tableView = UITableView()

    /// The list of countries to display in the popup menu.
    private var countriesList: [CountryEntity] = []

    /// The parent view in which this popup will be presented.
    private var parentView: UIView?

    /// Closure called when a country is selected, passing the selected country's dial code.
    var onSelectCountry: ((String) -> Void)?

    /// Closure called when the popup menu is dismissed.
    var onDismissMenu: (() -> Void)?

    /// Whether this menu resolved to a Liquid Glass background. Read by the table view data
    /// source so cells stay transparent and let the material through.
    private var isRenderingGlass = false

    /// The survey card's background colour, which this menu floats above.
    ///
    /// The menu takes its cue from the card rather than from the system: a survey themed dark has a
    /// dark card whatever the device's appearance is, and a white popup over it reads as a hole.
    /// `nil` keeps the pre-existing white treatment, for callers with no theme to offer.
    private var themeBackground: UIColor?

    /// Whether the menu is dark enough to need light text.
    private var prefersLightContent: Bool {
        guard let themeBackground else { return false }
        return !themeBackground.isLightColor()
    }

    // MARK: - Initializers

    /// Initializes the popup menu with a frame and parent view.
    /// - Parameters:
    ///   - frame: The frame for the popup menu.
    ///   - view: The parent view in which the popup menu will be displayed.
    ///   - glassResolver: Decides whether the menu renders as Liquid Glass. Passed at
    ///     construction because styling happens in `setupView()`, which runs here.
    ///   - themeBackground: The survey card's background colour, so the menu can sit on a dark
    ///     theme without punching a white hole in it. `nil` keeps the previous white treatment.
    init(
        frame: CGRect,
        view: UIView,
        glassResolver: GlassCapabilityResolving? = nil,
        themeBackground: UIColor? = nil
    ) {
        super.init(frame: frame)
        self.parentView = view
        self.isRenderingGlass = glassResolver?.allowsGlass(for: .chrome) ?? false
        self.themeBackground = themeBackground
        setupView()
    }

    /// Required initializer for decoding, not implemented as this view is not designed for storyboards.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup Methods

    /// Configures the popup menu view and loads data.
    private func setupView() {
        // Load countries from a JSON file
        guard
            let countries: [CountryEntity] = loadJSONFile(named: "countries", as: [CountryEntity].self),
            let parentView = parentView
        else { return }
        self.countriesList = countries

        // Configure the transparent background view
        transparentView.frame = parentView.bounds
        transparentView.backgroundColor = .clear
        parentView.addSubview(transparentView)

        // Add a tap gesture to dismiss the menu when tapping outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(hideMenu))
        transparentView.addGestureRecognizer(tapGesture)

        // Configure the table view
        tableView.frame = bounds
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(CountryTableViewCell.self, forCellReuseIdentifier: CountryTableViewCell.identifier)
        addSubview(tableView)

        applyBackgroundStyle()
    }

    /// Styles the popup's background.
    ///
    /// This menu is a popover, which Apple's guidance says should adopt Liquid Glass. When it
    /// does, the hand-rolled shadow is deliberately **not** applied: glass renders its own
    /// depth and edge treatment, and layering a manual shadow underneath it reads as a
    /// double border. The corner radius also grows to match iOS 26 popover metrics.
    ///
    /// This file lays out with frames rather than Auto Layout, so the glass view is sized the
    /// same way instead of being pinned with constraints.
    private func applyBackgroundStyle() {
        guard isRenderingGlass else {
            applyLegacyBackgroundStyle()
            return
        }

        // The material renders from the trait environment, not from the card's colour, so a menu
        // over a dark survey would draw light glass unless the appearance is pinned to match — the
        // same reasoning, and the same helper, that a glass card uses for the chrome inside it.
        if let themeBackground {
            overrideUserInterfaceStyle = UPGlassMeasuredMetrics.interfaceStyle(matching: themeBackground)
        }

        let glassBackground = UPGlassEffectView(
            style: .regular,
            allowsGlass: true,
            fallbackBackgroundColor: themeBackground ?? .white
        )
        glassBackground.translatesAutoresizingMaskIntoConstraints = true
        glassBackground.frame = bounds
        glassBackground.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(glassBackground, at: 0)

        backgroundColor = .clear
        applyCorners(.fixed(CountryPickerPopupMenu.glassCornerRadius))
        glassBackground.applyGlassCorners(.fixed(CountryPickerPopupMenu.glassCornerRadius))

        // The table must be transparent or it paints over the material.
        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
    }

    /// The pre-iOS 26 treatment: an opaque card with a shadow.
    ///
    /// Only a **dark** survey changes anything here. White over a dark card reads as a hole punched
    /// in it, and the shadow cannot separate the two surfaces because a black shadow is invisible
    /// against dark — so the fill becomes the card's own colour lifted one step, see
    /// ``UIColor/elevatedAsPopup(by:)``.
    ///
    /// A light survey keeps the white popup the SDK has always shipped. There is nothing wrong with
    /// white over a light card — the shadow does separate them — and leaving it alone means the
    /// majority of themes render exactly as they did before.
    private func applyLegacyBackgroundStyle() {
        let isDarkTheme = themeBackground.map { !$0.isLightColor() } ?? false
        backgroundColor = isDarkTheme ? themeBackground?.elevatedAsPopup() : .white
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
    }

    /// iOS 26 popovers use a noticeably larger radius than the 10 pt this menu used before.
    private static let glassCornerRadius: CGFloat = 22

    // MARK: - Actions

    /// Hides the popup menu and notifies the `onDismissMenu` closure.
    @objc func hideMenu() {
        removeChildViewsFromParentView()
        onDismissMenu?()
    }

    /// Removes the child views (transparent view and table view) from the parent view.
    private func removeChildViewsFromParentView() {
        transparentView.removeFromSuperview()
        tableView.removeFromSuperview()
    }
}

// MARK: - UITableViewDelegate and UITableViewDataSource

extension CountryPickerPopupMenu: UITableViewDelegate, UITableViewDataSource {

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        return countriesList.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: CountryTableViewCell.identifier, for: indexPath) as? CountryTableViewCell
        else { return UITableViewCell() }
        cell.bindCell(with: countriesList[indexPath.row], prefersLightContent: prefersLightContent)
        // Transparent either way: over glass an opaque cell paints over the material, and over the
        // legacy fill the menu's own background is what should show.
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        return cell
    }

    func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        return 40
    }

    /// Handles the selection of a row in the table view.
    /// - Removes the popup menu and passes the selected country's dial code to the `onSelectCountry` closure.
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        removeChildViewsFromParentView()
        onSelectCountry?(countriesList[indexPath.row].dialCode)
    }
}
