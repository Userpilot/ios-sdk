//
//  AutoCaptureTabsTestViewController.swift
//  UserpilotSample
//
//  Created by Userpilot on 31/03/2026.
//

import UIKit

// swiftlint:disable all

final class AutoCaptureTabsTestViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tabs Test"
        view.backgroundColor = .systemBackground
        setupTabs()
    }

    private func setupTabs() {
        let firstVC = AutoCaptureTabContentViewController(
            tabTitle: "Home",
            message: "Tap controls in this tab, then switch tab."
        )
        firstVC.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            tag: 0
        )

        let secondVC = AutoCaptureTabContentViewController(
            tabTitle: "Profile",
            message: "This tab helps test tab_selected + tap events."
        )
        secondVC.tabBarItem = UITabBarItem(
            title: "Profile",
            image: UIImage(systemName: "person"),
            tag: 1
        )

        viewControllers = [firstVC, secondVC]
        selectedIndex = 0
    }
}

private final class AutoCaptureTabContentViewController: UIViewController {

    private let tabTitle: String
    private let message: String

    init(tabTitle: String, message: String) {
        self.tabTitle = tabTitle
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = "\(tabTitle) Tab"
        titleLabel.font = .boldSystemFont(ofSize: 26)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.textColor = .secondaryLabel
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        let actionButton = UIButton(type: .system)
        actionButton.setTitle("Tap in \(tabTitle)", for: .normal)
        actionButton.backgroundColor = .systemBlue
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 10
        actionButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        actionButton.addTarget(self, action: #selector(onTapButton), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, actionButton])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc
    private func onTapButton() {
        let alert = UIAlertController(
            title: tabTitle,
            message: "Tap captured in \(tabTitle) tab",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// swiftlint:enable all
