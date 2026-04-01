//
//  IgnoredScreenDemoViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 29/03/2026.
//

import UIKit
import Userpilot

class IgnoredScreenDemoViewController: DemoBackButtonViewController {

    override var userpilotIgnoreScreen: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ignored Screen Demo"
        view.backgroundColor = .systemBackground
        setupBody()
    }

    private func setupBody() {
        let titleLabel = UILabel()
        titleLabel.text = "Ignored Screen"
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = UILabel()
        bodyLabel.text = """
        This controller overrides userpilotIgnoreScreen = true.
        Opening it should not emit a screen event, while interactions can still be tested normally.
        """
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setTitle("Tap Inside Ignored Screen", for: .normal)
        button.applyDemoStyle(backgroundColor: .systemMint)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(showIgnoredScreenAlert), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(bodyLabel)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: demoBackButtonTopInset + 20
            ),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            button.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 24),
            button.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])
    }

    @objc private func showIgnoredScreenAlert() {
        let alert = UIAlertController(
            title: "Ignored Screen",
            message: "This screen is opt-out for screen capture via userpilotIgnoreScreen.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
