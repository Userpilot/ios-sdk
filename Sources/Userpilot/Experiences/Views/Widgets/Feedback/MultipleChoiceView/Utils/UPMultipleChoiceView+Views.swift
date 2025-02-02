//
//  UPMultipleChoiceView+Views.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 19/01/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Extension of `UPMultipleChoiceView` for setting up the view hierarchy and layout constraints.
//

import UIKit

internal extension UPMultipleChoiceView {

    /// Configures the view's subviews and applies layout constraints.
    ///
    /// This method adds and configures the `titleDescriptionView` and `tableView` as subviews. It sets up
    /// constraints for proper layout and appearance, registers the table view cell, and disables scrolling
    /// for the table view as its height is dynamically adjusted based on its content.
    func setupView() {
        // Add and configure the title description view.
        addSubview(titleDescriptionView)
        titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleDescriptionView.topAnchor.constraint(equalTo: topAnchor),
            titleDescriptionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleDescriptionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])

        // Configure the table view properties.
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ChoiceTableViewCell.self, forCellReuseIdentifier: ChoiceTableViewCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 55
        tableView.isScrollEnabled = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none

        // Add the table view to the view hierarchy.
        addSubview(tableView)

        // Apply layout constraints to the table view.
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: titleDescriptionView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110)
        ])
    }
}
