//
//  ConfigViewController.swift
//  UserpilotSample
//
//  Created by Userpilot on 21/07/2026.
//
//  Screen that lets the developer configure the Userpilot SDK at runtime:
//  the app token plus every boolean flag of `Userpilot.Config`.
//
//  Values are persisted to `StorageManager` and read back by
//  `UserpilotManager` the next time the SDK is initialised, so the app must be
//  restarted for changes to take effect.
//

import UIKit

final class ConfigViewController: BaseViewController {

    // MARK: - Sections

    private enum Section: Int, CaseIterable {
        case token
        case flags
    }

    // MARK: - Properties

    private let flags = ConfigFlag.allCases

    /// In-memory copy of the current toggle state, seeded from persisted values.
    private lazy var values: [ConfigFlag: Bool] = {
        var map = [ConfigFlag: Bool]()
        flags.forEach { map[$0] = $0.value }
        return map
    }()

    // MARK: - UI Components

    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .label
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Configuration"
        label.font = .boldSystemFont(ofSize: 16)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let tokenTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter your app token"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let restartNoteLabel: UILabel = {
        let label = UILabel()
        label.text = "Changes are applied on the next launch. The app will restart after saving."
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Save & Restart", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupViews()
        setupTableView()
        setupActions()
        tokenTextField.text = StorageManager.shared.get(forKey: StorageManager.Keys.appToken) ?? ""
    }

    // MARK: - Setup

    private func setupViews() {
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(tableView)
        view.addSubview(restartNoteLabel)
        view.addSubview(saveButton)

        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            backButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalToConstant: 30),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: restartNoteLabel.topAnchor, constant: -8),

            restartNoteLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            restartNoteLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            restartNoteLabel.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -8),

            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 45)
        ])
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            ConfigFlagTableViewCell.self,
            forCellReuseIdentifier: ConfigFlagTableViewCell.reuseIdentifier
        )
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
    }

    private func setupActions() {
        backButton.addTarget(self, action: #selector(onBackTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(onSaveAndRestartTapped), for: .touchUpInside)
        tokenTextField.delegate = self
    }

    // MARK: - Actions

    @objc private func onBackTapped() {
        close()
    }

    @objc private func onSaveAndRestartTapped() {
        let token = tokenTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            presentMessage(title: "Missing app token", message: "Please enter your app token.")
            return
        }

        StorageManager.shared.set(value: token, forKey: StorageManager.Keys.appToken)
        flags.forEach { flag in
            StorageManager.shared.set(value: values[flag] ?? flag.defaultValue, forKey: flag.key)
        }

        let alert = UIAlertController(
            title: nil,
            message: "Configuration saved. Restarting…",
            preferredStyle: .alert
        )
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            exit(0)
        }
    }

    private func presentMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ConfigViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .token:
            return 1
        case .flags:
            return flags.count
        case .none:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .token:
            return "App Token"
        case .flags:
            return "SDK Config Flags"
        case .none:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .token:
            return tokenCell(for: tableView)
        case .flags:
            let flag = flags[indexPath.row]
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ConfigFlagTableViewCell.reuseIdentifier,
                for: indexPath
            )
            (cell as? ConfigFlagTableViewCell)?.configure(
                with: flag,
                isOn: values[flag] ?? flag.defaultValue
            ) { [weak self] isOn in
                self?.values[flag] = isOn
            }
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    private func tokenCell(for tableView: UITableView) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        if tokenTextField.superview !== cell.contentView {
            tokenTextField.removeFromSuperview()
            cell.contentView.addSubview(tokenTextField)
            NSLayoutConstraint.activate([
                tokenTextField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 6),
                tokenTextField.leadingAnchor.constraint(
                    equalTo: cell.contentView.leadingAnchor, constant: 16),
                tokenTextField.trailingAnchor.constraint(
                    equalTo: cell.contentView.trailingAnchor, constant: -16),
                tokenTextField.bottomAnchor.constraint(
                    equalTo: cell.contentView.bottomAnchor, constant: -6),
                tokenTextField.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ConfigViewController: UITableViewDelegate {}

// MARK: - UITextFieldDelegate

extension ConfigViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
