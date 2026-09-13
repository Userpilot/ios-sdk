//
//  OfflineEventsViewController.swift
//  UserpilotSample
//
//  Stress-test screen for offline event storage and delivery.
//  Ported from the Android sample OfflineEventsActivity.
//

import UIKit

// swiftlint:disable all

final class OfflineEventsViewController: UIViewController {

    private enum BurstKind { case track, screen, auto, mixed }

    private final class BurstState {
        let kind: BurstKind
        let total: Int
        let batchId: String
        var nextIndex = 0
        var trackCount = 0
        var screenCount = 0
        var autoCount = 0

        init(kind: BurstKind, total: Int, batchId: String) {
            self.kind = kind
            self.total = total
            self.batchId = batchId
        }
    }

    private let screenTitle = "offline events"
    private let chipTargetCount = 20
    private let toggleTargetCount = 2
    private let checkboxTargetCount = 2
    private let trackSlice = 40
    private let mixedCycle = 3
    private let maxBurst = 10_000

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let statusLabel = UILabel()
    private let countField = UITextField()
    private var countButtons: [UIButton] = []
    private var paddingButtons: [UIButton] = []
    private var selectedCount = 500
    private var selectedPaddingBytes = 0
    private var paddingPayload = ""
    private var autoClickTargets: [UIControl] = []
    private var burst: BurstState?
    private var sessionTrack = 0
    private var sessionScreen = 0
    private var sessionAuto = 0

    private let fireTrackButton = UIButton(type: .system)
    private let fireScreenButton = UIButton(type: .system)
    private let fireAutoButton = UIButton(type: .system)
    private let fireMixedButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Offline events"
        view.backgroundColor = .systemBackground
        setupBackButton()
        setupUI()
        setupAutoTargets()
        renderStatus(idleMessage())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen(screenTitle)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopBurst()
    }

    private func setupBackButton() {
        let backButton = UIButton(type: .system)
        backButton.setTitle("< Back", for: .normal)
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
        navigationController?.popViewController(animated: true)
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stopButton.setTitle("Stop", for: .normal)
        stopButton.isEnabled = false
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        styleOutlined(stopButton, color: .systemRed)

        let logsButton = makeButton("Events log / Logs", action: #selector(openLogs))
        let bottomRow = UIStackView(arrangedSubviews: [stopButton, logsButton])
        bottomRow.axis = .horizontal
        bottomRow.spacing = 8
        bottomRow.distribution = .fillEqually
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomRow)

        NSLayoutConstraint.activate([
            bottomRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bottomRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottomRow.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            bottomRow.heightAnchor.constraint(equalToConstant: 44),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomRow.topAnchor, constant: -8)
        ])

        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        let statusContainer = UIView()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: statusContainer.topAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -10),
            statusLabel.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor, constant: -10)
        ])
        stackView.addArrangedSubview(statusContainer)

        stackView.addArrangedSubview(makeLabel(
            "Offline buffer: 5,000 events or 3 MB. Identify → Airplane Mode → fire burst → go online → verify Events log."
        ))

        stackView.addArrangedSubview(makeSection("Burst size"))
        let countRow = UIStackView()
        countRow.axis = .horizontal
        countRow.spacing = 6
        countRow.distribution = .fillEqually
        for value in [100, 500, 1000, 5000, 5500] {
            let button = UIButton(type: .system)
            button.setTitle("\(value)", for: .normal)
            button.tag = value
            button.addTarget(self, action: #selector(countChipTapped(_:)), for: .touchUpInside)
            styleChip(button, selected: value == selectedCount)
            countButtons.append(button)
            countRow.addArrangedSubview(button)
        }
        stackView.addArrangedSubview(countRow)

        countField.placeholder = "Custom count"
        countField.text = "\(selectedCount)"
        countField.keyboardType = .numberPad
        countField.borderStyle = .roundedRect
        stackView.addArrangedSubview(countField)

        stackView.addArrangedSubview(makeSection("Track payload padding"))
        let paddingRow = UIStackView()
        paddingRow.axis = .horizontal
        paddingRow.spacing = 6
        paddingRow.distribution = .fillEqually
        for (title, bytes) in [("None", 0), ("1 KB", 1024), ("4 KB", 4096), ("16 KB", 16384)] {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.tag = bytes
            button.addTarget(self, action: #selector(paddingChipTapped(_:)), for: .touchUpInside)
            styleChip(button, selected: bytes == selectedPaddingBytes)
            paddingButtons.append(button)
            paddingRow.addArrangedSubview(button)
        }
        stackView.addArrangedSubview(paddingRow)

        stackView.addArrangedSubview(makeSection("Manual events"))
        configureActionButton(fireTrackButton, title: "Fire track events", action: #selector(fireTrackTapped), filled: true)
        configureActionButton(fireScreenButton, title: "Fire screen events", action: #selector(fireScreenTapped), filled: false)
        stackView.addArrangedSubview(fireTrackButton)
        stackView.addArrangedSubview(fireScreenButton)

        stackView.addArrangedSubview(makeSection("Auto-capture events"))
        configureActionButton(fireAutoButton, title: "Fire auto-capture clicks", action: #selector(fireAutoTapped), filled: false)
        stackView.addArrangedSubview(fireAutoButton)

        let chipsContainer = UIStackView()
        chipsContainer.axis = .vertical
        chipsContainer.spacing = 6
        chipsContainer.tag = 9001
        stackView.addArrangedSubview(chipsContainer)

        let togglesContainer = UIStackView()
        togglesContainer.axis = .vertical
        togglesContainer.spacing = 6
        togglesContainer.tag = 9002
        stackView.addArrangedSubview(togglesContainer)

        stackView.addArrangedSubview(makeSection("Mixed burst"))
        configureActionButton(fireMixedButton, title: "Fire mixed (track + screen + auto)", action: #selector(fireMixedTapped), filled: true)
        stackView.addArrangedSubview(fireMixedButton)
    }

    private func setupAutoTargets() {
        guard
            let chipsContainer = stackView.arrangedSubviews.first(where: { $0.tag == 9001 }) as? UIStackView,
            let togglesContainer = stackView.arrangedSubviews.first(where: { $0.tag == 9002 }) as? UIStackView
        else { return }

        for index in 1...chipTargetCount {
            let button = UIButton(type: .system)
            button.setTitle("Tap \(index)", for: .normal)
            button.accessibilityLabel = "offline-auto-chip-\(index)"
            styleChip(button, selected: false)
            installAutoTarget(button)
            chipsContainer.addArrangedSubview(button)
        }

        for index in 1...toggleTargetCount {
            let toggle = UISwitch()
            toggle.accessibilityLabel = "offline-auto-switch-\(index)"
            let row = labeledControl(title: "Switch \(index)", control: toggle)
            installAutoTarget(toggle)
            togglesContainer.addArrangedSubview(row)
        }

        for index in 1...checkboxTargetCount {
            let checkbox = UIButton(type: .system)
            checkbox.setTitle("☐ Box \(index)", for: .normal)
            checkbox.setTitle("☑ Box \(index)", for: .selected)
            checkbox.contentHorizontalAlignment = .leading
            checkbox.accessibilityLabel = "offline-auto-checkbox-\(index)"
            checkbox.addTarget(self, action: #selector(checkboxTapped(_:)), for: .touchUpInside)
            installAutoTarget(checkbox)
            togglesContainer.addArrangedSubview(checkbox)
        }
    }

    private func installAutoTarget(_ target: UIControl) {
        target.addTarget(self, action: #selector(autoTargetTapped), for: .touchUpInside)
        if target is UISwitch {
            target.addTarget(self, action: #selector(autoTargetTapped), for: .valueChanged)
        }
        autoClickTargets.append(target)
    }

    @objc private func autoTargetTapped() {
        if burst == nil {
            sessionAuto += 1
            renderStatus(idleMessage())
        }
    }

    @objc private func checkboxTapped(_ sender: UIButton) {
        sender.isSelected.toggle()
    }

    @objc private func countChipTapped(_ sender: UIButton) {
        selectedCount = sender.tag
        countField.text = "\(selectedCount)"
        countButtons.forEach { styleChip($0, selected: $0.tag == selectedCount) }
    }

    @objc private func paddingChipTapped(_ sender: UIButton) {
        selectedPaddingBytes = sender.tag
        paddingButtons.forEach { styleChip($0, selected: $0.tag == selectedPaddingBytes) }
    }

    @objc private func fireTrackTapped() { startBurst(.track) }
    @objc private func fireScreenTapped() { startBurst(.screen) }
    @objc private func fireAutoTapped() { startBurst(.auto) }
    @objc private func fireMixedTapped() { startBurst(.mixed) }

    @objc private func stopTapped() {
        stopBurst(cancelled: true)
    }

    @objc private func openLogs() {
        FlowRoutingManager.shared.openViewController(SDKEventsViewController.newInstance())
    }

    private func startBurst(_ kind: BurstKind) {
        guard burst == nil else { return }
        guard let count = parseCount() else { return }
        let batchId = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        paddingPayload = String(repeating: "x", count: selectedPaddingBytes)
        burst = BurstState(kind: kind, total: count, batchId: batchId)
        setControlsEnabled(false)
        DispatchQueue.main.async { [weak self] in self?.runBurstSlice() }
    }

    private func runBurstSlice() {
        guard let state = burst else { return }
        if state.nextIndex >= state.total {
            finishBurst()
            return
        }
        switch state.kind {
        case .track: fireTrackSlice(state)
        case .screen: fireScreenSlice(state)
        case .auto: fireAutoSlice(state)
        case .mixed: fireMixedSlice(state)
        }
        renderStatus(runningMessage(state))
        if burst != nil, state.nextIndex < state.total {
            DispatchQueue.main.async { [weak self] in self?.runBurstSlice() }
        } else if burst != nil {
            finishBurst()
        }
    }

    private func fireTrackSlice(_ state: BurstState) {
        let end = min(state.nextIndex + trackSlice, state.total)
        while state.nextIndex < end { fireTrack(state) }
    }

    private func fireScreenSlice(_ state: BurstState) {
        let end = min(state.nextIndex + trackSlice, state.total)
        while state.nextIndex < end { fireScreen(state) }
    }

    private func fireAutoSlice(_ state: BurstState) {
        var used = Set<ObjectIdentifier>()
        while state.nextIndex < state.total {
            guard let target = nextUnusedTarget(used) else { break }
            fireAuto(state, target: target)
            used.insert(ObjectIdentifier(target))
        }
    }

    private func fireMixedSlice(_ state: BurstState) {
        var used = Set<ObjectIdentifier>()
        var processed = 0
        while state.nextIndex < state.total, processed < trackSlice {
            switch state.nextIndex % mixedCycle {
            case 0: fireTrack(state)
            case 1: fireScreen(state)
            default:
                guard let target = nextUnusedTarget(used) else { return }
                fireAuto(state, target: target)
                used.insert(ObjectIdentifier(target))
            }
            processed += 1
        }
    }

    private func fireTrack(_ state: BurstState) {
        let index = state.nextIndex
        var properties: [String: Any] = [
            "batch_id": state.batchId,
            "index": index,
            "kind": "track",
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if !paddingPayload.isEmpty {
            properties["padding"] = paddingPayload
        }
        UserpilotManager.shared.track(
            eventName: "offline_track_\(state.batchId)_\(index)",
            properties: properties
        )
        state.nextIndex += 1
        state.trackCount += 1
        sessionTrack += 1
    }

    private func fireScreen(_ state: BurstState) {
        let index = state.nextIndex
        UserpilotManager.shared.screen("offline_screen_\(state.batchId)_\(index)")
        state.nextIndex += 1
        state.screenCount += 1
        sessionScreen += 1
    }

    private func fireAuto(_ state: BurstState, target: UIControl) {
        let index = state.nextIndex
        let label = "auto_\(state.batchId)_\(index)"
        if let button = target as? UIButton {
            button.setTitle(label, for: .normal)
        }
        target.accessibilityLabel = label
        target.sendActions(for: .touchUpInside)
        if target is UISwitch {
            target.sendActions(for: .valueChanged)
        }
        state.nextIndex += 1
        state.autoCount += 1
        sessionAuto += 1
    }

    private func nextUnusedTarget(_ used: Set<ObjectIdentifier>) -> UIControl? {
        autoClickTargets.first { !used.contains(ObjectIdentifier($0)) }
    }

    private func finishBurst() {
        let state = burst
        stopBurst()
        if let state {
            renderStatus(completedMessage(state))
        }
    }

    private func stopBurst(cancelled: Bool = false) {
        let state = burst
        burst = nil
        setControlsEnabled(true)
        if cancelled, let state {
            renderStatus(cancelledMessage(state))
        }
    }

    private func parseCount() -> Int? {
        let raw = countField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let count = Int(raw), count > 0 else {
            renderStatus("Enter a count greater than 0")
            return nil
        }
        return min(count, maxBurst)
    }

    private func setControlsEnabled(_ enabled: Bool) {
        fireTrackButton.isEnabled = enabled
        fireScreenButton.isEnabled = enabled
        fireAutoButton.isEnabled = enabled
        fireMixedButton.isEnabled = enabled
        countField.isEnabled = enabled
        countButtons.forEach { $0.isEnabled = enabled }
        paddingButtons.forEach { $0.isEnabled = enabled }
        stopButton.isEnabled = !enabled
    }

    private func listenerCount() -> Int {
        UserpilotManager.shared.userpilotSDKEvents.count
    }

    private func idleMessage() -> String {
        "Idle. Session track=\(sessionTrack), screen=\(sessionScreen), auto=\(sessionAuto).\nSDK listener=\(listenerCount())"
    }

    private func runningMessage(_ state: BurstState) -> String {
        "Firing \(state.nextIndex) / \(state.total)\nThis burst track=\(state.trackCount), screen=\(state.screenCount), auto=\(state.autoCount)\nSDK listener=\(listenerCount())"
    }

    private func completedMessage(_ state: BurstState) -> String {
        "Done. Requested=\(state.total) (track=\(state.trackCount), screen=\(state.screenCount), auto=\(state.autoCount)).\nSession track=\(sessionTrack), screen=\(sessionScreen), auto=\(sessionAuto).\nSDK listener=\(listenerCount())"
    }

    private func cancelledMessage(_ state: BurstState) -> String {
        "Stopped \(state.nextIndex) / \(state.total) (track=\(state.trackCount), screen=\(state.screenCount), auto=\(state.autoCount)).\nSDK listener=\(listenerCount())"
    }

    private func renderStatus(_ text: String) {
        statusLabel.text = text
    }

    private func makeSection(_ title: String) -> UILabel {
        let label = makeLabel(title)
        label.font = .boldSystemFont(ofSize: 15)
        return label
    }

    private func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }

    private func makeButton(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        styleOutlined(button, color: .systemBlue)
        return button
    }

    private func configureActionButton(_ button: UIButton, title: String, action: Selector, filled: Bool) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.addTarget(self, action: action, for: .touchUpInside)
        if filled {
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 8
            button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        } else {
            styleOutlined(button, color: .systemBlue)
        }
    }

    private func styleOutlined(_ button: UIButton, color: UIColor) {
        button.setTitleColor(color, for: .normal)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = color.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
    }

    private func styleChip(_ button: UIButton, selected: Bool) {
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.backgroundColor = selected ? UIColor.systemBlue.withAlphaComponent(0.15) : .clear
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
    }

    private func labeledControl(title: String, control: UIView) -> UIStackView {
        let label = UILabel()
        label.text = title
        let row = UIStackView(arrangedSubviews: [label, control])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        return row
    }
}

// swiftlint:enable all
