//
//  AutoCaptureHubViewController.swift
//  UserpilotSample
//
//  Hub listing all Auto Capture test screens.
//

import UIKit

final class AutoCaptureHubViewController: BaseViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let items: [AutoCaptureContent] = [
        .controls,
        .pickerView,
        .tableView,
        .collectionView,
        .textConfig,
        .tabs,
        .ignoredScreen
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Auto Capture"
        setupTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("auto capture")
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = SampleAppearance.screenBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    static func newInstance() -> AutoCaptureHubViewController {
        AutoCaptureHubViewController()
    }
}

extension AutoCaptureHubViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = items[indexPath.row].title
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch items[indexPath.row] {
        case .controls:
            FlowRoutingManager.shared.openViewController(AutoCaptureTestViewController())
        case .pickerView:
            FlowRoutingManager.shared.openViewController(PickerViewTestViewController())
        case .tableView:
            FlowRoutingManager.shared.openViewController(TableViewTestViewController())
        case .collectionView:
            FlowRoutingManager.shared.openViewController(CollectionViewTestViewController())
        case .textConfig:
            FlowRoutingManager.shared.openViewController(TextConfigDemoViewController())
        case .tabs:
            FlowRoutingManager.shared.openViewController(AutoCaptureTabsTestViewController())
        case .ignoredScreen:
            FlowRoutingManager.shared.openViewController(IgnoredScreenDemoViewController())
        }
    }
}

enum AutoCaptureContent {
    case controls
    case pickerView
    case tableView
    case collectionView
    case textConfig
    case tabs
    case ignoredScreen

    var title: String {
        switch self {
        case .controls:
            return "Controls test"
        case .pickerView:
            return "UIPickerView test"
        case .tableView:
            return "TableView test"
        case .collectionView:
            return "CollectionView test"
        case .textConfig:
            return "Text config demo"
        case .tabs:
            return "Tabs test"
        case .ignoredScreen:
            return "Ignored screen demo"
        }
    }
}
