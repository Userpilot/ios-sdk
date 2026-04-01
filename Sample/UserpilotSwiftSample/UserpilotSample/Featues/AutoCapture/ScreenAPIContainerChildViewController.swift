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

        let button = UIButton(type: .system)
        button.setTitle("Tap Embedded Child Button", for: .normal)
        button.applyDemoStyle(backgroundColor: .systemBrown)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(showEmbeddedChildAlert), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(bodyLabel)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            button.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 20),
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
