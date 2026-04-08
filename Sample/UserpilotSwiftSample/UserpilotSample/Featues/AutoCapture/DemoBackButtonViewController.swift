//
//  DemoBackButtonViewController.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 29/03/2026.
//

import UIKit

class DemoBackButtonViewController: UIViewController {

    let demoBackButtonTopInset: CGFloat = 44

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackButton()
    }

    private func setupBackButton() {
        let backButton = UIButton(type: .system)
        backButton.setTitle("< Back", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 17)
        backButton.contentHorizontalAlignment = .leading
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.userpilotRedactText = true
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    @objc private func backTapped() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
