//
//  ProfileViewController.swift
//  UserpilotSample
//
//  Profile tab with options including Settings.
//

import UIKit

final class ProfileViewController: BaseViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let sections: [[ProfileOption]] = [
        [.editProfile, .notifications],
        [.settings, .privacy, .help],
        [.signOut]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        view.accessibilityIdentifier = "demo-profile-screen"
        setupTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("demo profile")
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = SampleAppearance.screenBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.tableHeaderView = makeHeader()
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func makeHeader() -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 180))

        let avatar = UIImageView(image: UIImage(systemName: "person.crop.circle.fill"))
        avatar.tintColor = SampleAppearance.accentColor
        avatar.contentMode = .scaleAspectFit
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.accessibilityIdentifier = "demo-profile-avatar"

        let nameLabel = UILabel()
        nameLabel.text = "Alex Rivera"
        nameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        nameLabel.textAlignment = .center
        nameLabel.accessibilityIdentifier = "demo-profile-name"

        let handleLabel = UILabel()
        handleLabel.text = "@alex.rivera · Product"
        handleLabel.font = .systemFont(ofSize: 14)
        handleLabel.textColor = .secondaryLabel
        handleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [avatar, nameLabel, handleLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 72),
            avatar.heightAnchor.constraint(equalToConstant: 72),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }
}

extension ProfileViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let option = sections[indexPath.section][indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = option.title
        config.image = UIImage(systemName: option.symbolName)
        if option == .signOut {
            config.textProperties.color = .systemRed
            config.imageProperties.tintColor = .systemRed
            cell.accessoryType = .none
        } else {
            config.textProperties.color = .label
            config.imageProperties.tintColor = SampleAppearance.accentColor
            cell.accessoryType = .disclosureIndicator
        }
        cell.contentConfiguration = config
        cell.accessibilityIdentifier = "demo-profile-\(option.rawValue)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = sections[indexPath.section][indexPath.row]
        switch option {
        case .settings:
            FlowRoutingManager.shared.openViewController(DemoSettingsViewController())
        case .signOut:
            let alert = UIAlertController(
                title: "Sign out",
                message: "This is a demo action only.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        default:
            let alert = UIAlertController(
                title: option.title,
                message: "Demo placeholder for \(option.title.lowercased()).",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

private enum ProfileOption: String {
    case editProfile
    case notifications
    case settings
    case privacy
    case help
    case signOut

    var title: String {
        switch self {
        case .editProfile: return "Edit Profile"
        case .notifications: return "Notifications"
        case .settings: return "Settings"
        case .privacy: return "Privacy"
        case .help: return "Help & Support"
        case .signOut: return "Sign Out"
        }
    }

    var symbolName: String {
        switch self {
        case .editProfile: return "pencil"
        case .notifications: return "bell"
        case .settings: return "gearshape"
        case .privacy: return "lock.shield"
        case .help: return "questionmark.circle"
        case .signOut: return "rectangle.portrait.and.arrow.right"
        }
    }
}
