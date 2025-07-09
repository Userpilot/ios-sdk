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

    // MARK: - Initializers

    /// Initializes the popup menu with a frame and parent view.
    /// - Parameters:
    ///   - frame: The frame for the popup menu.
    ///   - view: The parent view in which the popup menu will be displayed.
    init(frame: CGRect, view: UIView) {
        super.init(frame: frame)
        self.parentView = view
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

        // Style the popup menu
        backgroundColor = .white
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
    }

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
        cell.bindCell(with: countriesList[indexPath.row])
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
