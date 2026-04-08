//
//  ScreenAPIContainerChildViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 29/03/2026.
//

import UIKit
import Userpilot

class ScreenAPIContainerChildViewController: UIViewController {

    override var userpilotScreenName: String? {
        "Container Child Screen"
    }

    override var userpilotScreenTitle: String? {
        "Embedded Child Title"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.28)
        setupBody()
    }

    // swiftlint:disable:next function_body_length
    private func setupBody() {
        let titleLabel = UILabel()
        titleLabel.text = "Embedded Child Screen"
        titleLabel.font = .boldSystemFont(ofSize: 20)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = UILabel()
        bodyLabel.text = """
        This child overrides userpilotScreenName and userpilotScreenTitle inside a custom container.
        """
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        let normalScenarioLabel = UILabel()
        normalScenarioLabel.text = """
        Normal scenario:
        - Taps on this button create interaction events.
        - Screen name is resolved from child screen APIs first.
        """
        normalScenarioLabel.textColor = .label
        normalScenarioLabel.numberOfLines = 0
        normalScenarioLabel.font = .systemFont(ofSize: 14)
        normalScenarioLabel.translatesAutoresizingMaskIntoConstraints = false

        let expectedWithConfigsLabel = UILabel()
        expectedWithConfigsLabel.text = """
        Expected with configs:
        - userpilotIgnoreInteractions = true: no interaction events from this subtree.
        - userpilotIgnoreInnerHierarchy = true on parent: child tap is attributed to parent container.
        - userpilotIgnoreInteractionsDefault / userpilotIgnoreInnerHierarchyDefault:
          same behavior as class-level defaults.
        """
        expectedWithConfigsLabel.textColor = .secondaryLabel
        expectedWithConfigsLabel.numberOfLines = 0
        expectedWithConfigsLabel.font = .systemFont(ofSize: 13)
        expectedWithConfigsLabel.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setTitle("Tap Embedded Child Button", for: .normal)
        button.applyDemoStyle(backgroundColor: .systemBrown)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(showEmbeddedChildAlert), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(bodyLabel)
        view.addSubview(normalScenarioLabel)
        view.addSubview(expectedWithConfigsLabel)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            normalScenarioLabel.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 14),
            normalScenarioLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            normalScenarioLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            expectedWithConfigsLabel.topAnchor.constraint(
                equalTo: normalScenarioLabel.bottomAnchor,
                constant: 10
            ),
            expectedWithConfigsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            expectedWithConfigsLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            button.topAnchor.constraint(equalTo: expectedWithConfigsLabel.bottomAnchor, constant: 20),
            button.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])
    }

    @objc private func showEmbeddedChildAlert() {
        let alert = UIAlertController(
            title: "Embedded Child",
            message: "This child screen sits inside a controller marked as a custom container.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
