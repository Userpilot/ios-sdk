//
//  CountryTableViewCell.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//
//  [Brief Description]
//  A custom table view cell that displays a country's flag, name, and dial code.
//

import UIKit

/// A custom table view cell that displays a country's flag, name, and dial code.
internal class CountryTableViewCell: UITableViewCell {

    // MARK: - Properties
    static let identifier = "CountryTableViewCell"

    private let flagLabel = UILabel()
    private let countryNameLabel = UILabel()
    private let countryCodeLabel = UILabel()

    // MARK: - Initializers

    /// Initializes the cell with the specified style and reuse identifier.
    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    /// Initializes the cell from a storyboard or nib.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Private Methods

    /// Sets up the user interface for the cell, including labels and layout constraints.
    private func setupUI() {
        // Flag label setup
        flagLabel.font = .systemFont(ofSize: 24)
        flagLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(flagLabel)

        // Country name label setup
        countryNameLabel.font = .systemFont(ofSize: 16)
        countryNameLabel.translatesAutoresizingMaskIntoConstraints = false
        countryNameLabel.textColor = .gray43
        contentView.addSubview(countryNameLabel)

        // Country code label setup
        countryCodeLabel.font = .boldSystemFont(ofSize: 16)
        countryCodeLabel.textAlignment = .right
        countryCodeLabel.textColor = .black
        countryCodeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countryCodeLabel)

        // Layout constraints for labels
        NSLayoutConstraint.activate([
            // Flag label constraints
            flagLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            flagLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // Country name label constraints
            countryNameLabel.leadingAnchor.constraint(equalTo: flagLabel.trailingAnchor, constant: 16),
            countryNameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: countryCodeLabel.leadingAnchor, constant: -8),
            countryNameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // Country code label constraints
            countryCodeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            countryCodeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            countryCodeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 60)
        ])
    }

    // MARK: - Public Methods

    /// Binds the cell with the country data to display the flag, country name, and dial code.
    /// - Parameter country: The `CountryEntity` containing the country's flag, name, and dial code.
    /// - Parameters:
    ///   - country: The row's country.
    ///   - prefersLightContent: Whether the menu behind this cell is dark, in which case the text
    ///     has to invert. The defaults are the colours this cell always used, so a caller that does
    ///     not care about theming gets exactly the previous appearance.
    func bindCell(with country: CountryEntity, prefersLightContent: Bool = false) {
        flagLabel.text = country.flag
        countryNameLabel.text = country.name
        countryCodeLabel.text = country.dialCode

        countryCodeLabel.textColor = prefersLightContent ? .white : .black
        countryNameLabel.textColor = prefersLightContent ? UIColor.white.withOpacity(0.7) : .gray43
    }
}
