//
//  PickerViewTestViewController.swift
//  UserpilotSample
//
//  Created by Userpilot on 30/03/2026.
//
//  [Brief Description]
//  Test screen for UIPickerView row selection auto-capture (delegate didSelectRow swizzle).
//

import UIKit

class PickerViewTestViewController: UIViewController {

    private let pickerView = UIPickerView()
    private let selectionLabel = UILabel()

    private let options = ["Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape"]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIPickerView Test"
        view.backgroundColor = .systemBackground
        setupBackButton()
        setupPicker()
    }

    private func setupBackButton() {
        let backButton = UIButton(type: .system)
        backButton.setTitle("< Back", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 17)
        backButton.contentHorizontalAlignment = .leading
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
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

    private func setupPicker() {
        selectionLabel.translatesAutoresizingMaskIntoConstraints = false
        selectionLabel.font = .systemFont(ofSize: 15)
        selectionLabel.textColor = .secondaryLabel
        selectionLabel.textAlignment = .center
        selectionLabel.numberOfLines = 0
        updateSelectionLabel(for: 0)

        pickerView.translatesAutoresizingMaskIntoConstraints = false
        pickerView.dataSource = self
        pickerView.delegate = self

        view.addSubview(selectionLabel)
        view.addSubview(pickerView)

        NSLayoutConstraint.activate([
            selectionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            selectionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            selectionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            pickerView.topAnchor.constraint(equalTo: selectionLabel.bottomAnchor, constant: 16),
            pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pickerView.heightAnchor.constraint(equalToConstant: 216)
        ])
    }

    private func updateSelectionLabel(for row: Int) {
        let name = options[row]
        selectionLabel.text = "Selected: \(name) — spin the wheel to fire picker_view_changed"
    }
}

// MARK: - UIPickerViewDataSource & UIPickerViewDelegate

extension PickerViewTestViewController: UIPickerViewDataSource, UIPickerViewDelegate {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        options.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        options[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        updateSelectionLabel(for: row)
    }
}
