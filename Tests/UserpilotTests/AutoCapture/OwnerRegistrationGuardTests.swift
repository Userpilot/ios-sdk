//
//  OwnerRegistrationGuardTests.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Hooks that receive an already-resolved owner publish only while that owner is still the
//  registered instance for its token. Real controls and cells, observed at the publisher.
//

import XCTest
@testable import Userpilot

final class OwnerRegistrationGuardTests: XCTestCase {

    private var owner: MockUserpilot!
    private var window: UIWindow!
    private var events: [Event] = []

    override func setUp() {
        super.setUp()
        owner = makeOwner(token: "GUARD-\(UUID().uuidString)")
        owner.analyticsPublisher.onPublish = { [weak self] in self?.events.append($0) }
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.isHidden = false
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        owner = nil
        events = []
        super.tearDown()
    }

    // MARK: - UIControl

    func testControlInteraction_publishesOnlyWhileItsOwnerIsRegistered() {
        let button = UIButton(type: .system)
        button.setTitle("Pay", for: .normal)
        button.frame = CGRect(x: 0, y: 0, width: 120, height: 44)
        window.addSubview(button)

        tap(button, owner: owner)
        XCTAssertEqual(rawInteractionTypes, ["tap"])

        UserpilotRuntime.shared.removeInstance(owner)
        tap(button, owner: owner)

        XCTAssertEqual(rawInteractionTypes, ["tap"], "An owner resolved before removal must not publish")
    }

    func testControlInteraction_forAReplacedOwnerReachesNeitherInstance() {
        let token = owner.config.token
        UserpilotRuntime.shared.removeInstance(owner)
        let replacement = makeOwner(token: token)
        XCTAssertFalse(replacement === owner, "Precondition: a replacement is a different object")
        var replacementEvents: [Event] = []
        replacement.analyticsPublisher.onPublish = { replacementEvents.append($0) }
        let toggle = UISwitch()
        window.addSubview(toggle)

        tap(toggle, owner: owner)
        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(replacementEvents.isEmpty, "A stale owner's event must not be attributed to its replacement")

        tap(toggle, owner: replacement)
        XCTAssertEqual(replacementEvents.count, 1)
    }

    // MARK: - Lists

    func testTableViewCellSelection_publishesOnlyWhileItsOwnerIsRegistered() throws {
        let rows = RowsDataSource()
        let tableView = UITableView(frame: window.bounds)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: RowsDataSource.reuseIdentifier)
        tableView.dataSource = rows
        window.addSubview(tableView)
        tableView.layoutIfNeeded()
        let cell = try XCTUnwrap(tableView.cellForRow(at: IndexPath(row: 1, section: 0)))

        cell.captureTableViewCellSelection(touchedView: cell.contentView, owner: owner)
        XCTAssertEqual(rawInteractionTypes, ["table_view_cell_selected"])
        XCTAssertEqual(events.first?.properties?[Constants.AutoCapture.targetText] as? String, "Row 1")

        UserpilotRuntime.shared.removeInstance(owner)
        cell.captureTableViewCellSelection(touchedView: cell.contentView, owner: owner)

        XCTAssertEqual(events.count, 1, "An owner resolved before removal must not publish")
    }

    func testCollectionViewItemSelection_publishesOnlyWhileItsOwnerIsRegistered() throws {
        let items = ItemsDataSource()
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 40)
        let collectionView = UICollectionView(frame: window.bounds, collectionViewLayout: layout)
        collectionView.register(ItemCell.self, forCellWithReuseIdentifier: ItemsDataSource.reuseIdentifier)
        collectionView.dataSource = items
        window.addSubview(collectionView)
        collectionView.layoutIfNeeded()
        let cell = try XCTUnwrap(collectionView.cellForItem(at: IndexPath(item: 0, section: 0)))

        cell.captureCollectionViewItemSelection(touchedView: cell.contentView, owner: owner)
        XCTAssertEqual(rawInteractionTypes, ["collection_view_item_selected"])
        XCTAssertEqual(events.first?.properties?[Constants.AutoCapture.targetText] as? String, "Item 0")

        UserpilotRuntime.shared.removeInstance(owner)
        cell.captureCollectionViewItemSelection(touchedView: cell.contentView, owner: owner)

        XCTAssertEqual(events.count, 1, "An owner resolved before removal must not publish")
    }

    // MARK: - Helpers

    private var rawInteractionTypes: [String] {
        events.compactMap { $0.properties?[Constants.AutoCapture.rawInteractionType] as? String }
    }

    private func makeOwner(token: String) -> MockUserpilot {
        MockUserpilot.make(
            config: Userpilot.Config(token: token)
                .enableInteractionAutoCapture()
                .appFramework(.UIKit)
                .defaultInstance(false)
        )
    }

    /// The control hook's capture step, with the owner resolved at the native boundary.
    private func tap(_ control: UIControl, owner: Userpilot) {
        control.captureControlInteraction(action: #selector(didTap), target: self, event: nil, owner: owner)
    }

    @objc private func didTap() {}
}

private final class RowsDataSource: NSObject, UITableViewDataSource {
    static let reuseIdentifier = "row"

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 3 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.reuseIdentifier, for: indexPath)
        cell.textLabel?.text = "Row \(indexPath.row)"
        return cell
    }
}

private final class ItemCell: UICollectionViewCell {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.frame = contentView.bounds
        contentView.addSubview(label)
    }

    required init?(coder: NSCoder) { nil }
}

private final class ItemsDataSource: NSObject, UICollectionViewDataSource {
    static let reuseIdentifier = "item"

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 2 }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.reuseIdentifier, for: indexPath)
        (cell as? ItemCell)?.label.text = "Item \(indexPath.item)"
        return cell
    }
}
