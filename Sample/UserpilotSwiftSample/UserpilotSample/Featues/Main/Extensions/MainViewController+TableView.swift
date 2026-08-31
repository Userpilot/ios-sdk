//
//  MainViewController+TableView.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 16/09/2024.
//

import Foundation
import UIKit

// MARK: - UITableViewDelegate

extension MainViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellIdentifier", for: indexPath)
        cell.textLabel?.text = content[indexPath.row].title
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        switch content[indexPath.row] {
        case .identify:
            FlowRoutingManager.shared.openViewController(IdentifyViewController.newInstance())
        case .screens:
            FlowRoutingManager.shared.openViewController(ScreenOneViewController.newInstance())
        case .events:
            FlowRoutingManager.shared.openViewController(CustomEventViewController.newInstance())
        case .configurations:
            openConfigScreen()
        case .eventsLog:
            FlowRoutingManager.shared.openViewController(SDKEventsViewController.newInstance())
        case .autoCapture:
            FlowRoutingManager.shared.openViewController(AutoCaptureTestViewController())
        }
    }

}
