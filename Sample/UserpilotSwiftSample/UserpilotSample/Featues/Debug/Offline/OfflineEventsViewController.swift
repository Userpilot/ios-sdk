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

    private enum BurstKind { case track, screen, auto, mixed, paced }

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
    private var scenarioUserId: String?
    private var scenarioButtons: [UIButton] = []
    private var pendingBurstWork: DispatchWorkItem?

    private let fireTrackButton = UIButton(type: .system)
    private let fireScreenButton = UIButton(type: .system)
    private let fireAutoButton = UIButton(type: .system)
    private let fireMixedButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Offline events"
        view.backgroundColor = SampleAppearance.screenBackground
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

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stopButton.setTitle("Stop", for: .normal)
        stopButton.isEnabled = false
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        stopButton.applyLiquidGlassStyle(.regular, title: "Stop", tintColor: .systemRed)

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

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
            "Setup: enable SDK logs, disable screen auto-capture, and use a screen without targeted content. " +
            "Start with O1 online and wait for the screen ACK. Enable Airplane Mode, disable Wi-Fi, " +
            "and wait for the SDK offline log before running an offline case. " +
            "For auto-capture bursts, enable interaction auto-capture."
        ))
        stackView.addArrangedSubview(makeLabel(
            "Offline checks cover persistence, replay order, and user cleanup. Batch flags are outside these checks. " +
            "Inspect live screen requests after reconnect for session flags. Counters show API calls, not ACKs. " +
            "The buffer holds up to 5,000 events or 3 MB; excess events can be dropped."
        ))
        setupIdentityScenarios()

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
        stackView.addArrangedSubview(makeLabel(
            "O8 · Stored tracks\nScenario: while offline after O1, submit the selected count of unique tracks. " +
            "Expected: admitted rows replay on reconnect; padding exercises the byte limit. Use O7 to drive replay."
        ))
        stackView.addArrangedSubview(fireTrackButton)
        stackView.addArrangedSubview(makeLabel(
            "O9 · Stored screens\nScenario: while offline, submit unique screen titles. " +
            "Expected: admitted screens replay with their titles and stored order. " +
            "Check live flags separately after reconnect with O7."
        ))
        stackView.addArrangedSubview(fireScreenButton)

        stackView.addArrangedSubview(makeSection("Auto-capture events"))
        configureActionButton(fireAutoButton, title: "Fire auto-capture clicks", action: #selector(fireAutoTapped), filled: false)
        stackView.addArrangedSubview(makeLabel(
            "O10 · Stored interactions\nScenario: with interaction auto-capture enabled, generate clicks offline. " +
            "Expected: eligible captured interactions replay after reconnect. Submitted clicks are not a delivery count; " +
            "native instrumentation and capture throttles still apply."
        ))
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
        stackView.addArrangedSubview(makeLabel(
            "O11 · Mixed replay\nScenario: cycle tracks, screens, and captured clicks while offline. " +
            "Expected: admitted rows replay in stored order within buffer limits; check event names and indices. " +
            "Native capture may add or throttle interactions."
        ))
        stackView.addArrangedSubview(fireMixedButton)
        stackView.addArrangedSubview(makeLabel(
            "Stop cancels future submissions only. Events log shows SDK callbacks; use socket JSON logs for " +
            "batch payloads and ACKs. Opening logs or leaving this screen stops a running burst. " +
            "Returning to this screen also reports the normal offline events screen."
        ))
    }

    private func setupIdentityScenarios() {
        stackView.addArrangedSubview(makeSection("Identity and replay checks"))
        addScenario("O1 · Establish user A online", scenario:
            "While online, logout, identify a fresh user A, then report a baseline screen.", expected:
            "The first live screen is true/false (is_session_start/fake_reload). Wait for its ACK before going offline.",
            action: #selector(establishUserTapped))
        addScenario("O2 · Identify the same user offline", scenario:
            "After O1, go offline, add tracks, then identify the same user again.", expected:
            "Existing rows remain and replay for the same user. Reidentify preserves session-start; " +
            "reconnect and use O7 to drive replay and inspect the live screen.", action: #selector(reidentifyTapped))
        addScenario("O3 · Switch user offline", scenario:
            "After storing events offline, identify a different user and report a new screen.", expected:
            "Old-user rows clear. Only the new user replays. Its first live screen after reconnect is true/false.",
            action: #selector(switchUserTapped))
        addScenario("O4 · Logout and identify the same user", scenario:
            "While offline with stored events, logout, identify the same user, then report a screen.", expected:
            "Pre-logout rows clear. The next identity starts a new session; its first live screen is true/false.",
            action: #selector(logoutAndIdentifyTapped))
        addScenario("O5 · Events without an identity", scenario:
            "While offline, logout, submit a screen and track before identify, then identify a fresh user and report a new screen.", expected:
            "The pre-identify requests must not replay. The identify and screen submitted afterward can replay. " +
            "The rejected screen may still update navigation context before the new screen replaces it.", action: #selector(unidentifiedTapped))
        addScenario("O6 · 50 alternating calls, 50 ms apart", scenario:
            "While offline with an identity, submit screen/track pairs: 50 calls with 50 ms between calls.", expected:
            "After reconnect, admitted rows replay in order. " +
            "The delay paces submission; it does not wait for ACKs.", action: #selector(pacedBurstTapped))
        addScenario("O7 · Reconnect and request a live screen", scenario:
            "Restore network and wait for its SDK log, then tap this button to drive replay and a new live screen.", expected:
            "Offline replay resolves before the live screen. The live request uses fake_reload=false. " +
            "Session-start is true only if the identity still awaits its initial live screen; after that screen ACK, " +
            "another tap gives false/false. Same-user and dismissal fake_reload=true checks are in Online queue.",
            action: #selector(liveScreenTapped))
    }

    private func addScenario(_ title: String, scenario: String, expected: String, action: Selector) {
        stackView.addArrangedSubview(makeLabel("Scenario: \(scenario)\nExpected: \(expected)"))
        let button = makeButton(title, action: action)
        button.titleLabel?.numberOfLines = 0
        scenarioButtons.append(button)
        stackView.addArrangedSubview(button)
        stackView.setCustomSpacing(18, after: button)
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
    @objc private func pacedBurstTapped() { startBurst(.paced) }

    @objc private func establishUserTapped() {
        UserpilotManager.shared.logout()
        identifyScenarioUser("offline_user_a_\(batchIdentifier())")
        reportScenarioScreen("baseline")
        renderStatus("O1 submitted. Wait for the baseline screen ACK before going offline.")
    }

    @objc private func reidentifyTapped() {
        guard let scenarioUserId else {
            renderStatus("Run O1 first so the scenario knows which user to reidentify.")
            return
        }
        identifyScenarioUser(scenarioUserId)
        renderStatus("O2 submitted for \(scenarioUserId). Restore network, then use O7 to drive replay.")
    }

    @objc private func switchUserTapped() {
        guard scenarioUserId != nil else {
            renderStatus("Run O1 first, go offline, then add events before switching users.")
            return
        }
        identifyScenarioUser("offline_user_b_\(batchIdentifier())")
        reportScenarioScreen("switched")
        renderStatus("O3 submitted. Prior-user rows must be absent from the next replay.")
    }

    @objc private func logoutAndIdentifyTapped() {
        guard let scenarioUserId else {
            renderStatus("Run O1 first, go offline, then add events before logout.")
            return
        }
        UserpilotManager.shared.logout()
        identifyScenarioUser(scenarioUserId)
        reportScenarioScreen("after_logout")
        renderStatus("O4 submitted. Pre-logout rows must be absent from the next replay.")
    }

    @objc private func unidentifiedTapped() {
        UserpilotManager.shared.logout()
        reportScenarioScreen("unidentified")
        UserpilotManager.shared.track(eventName: "offline_unidentified_track_\(batchIdentifier())")
        identifyScenarioUser("offline_user_a_\(batchIdentifier())")
        reportScenarioScreen("after_identify")
        renderStatus("O5 submitted. Pre-identify requests must be absent from replay; later requests may replay.")
    }

    @objc private func liveScreenTapped() {
        reportScenarioScreen("live_probe")
        renderStatus("O7 submitted. Inspect batch_events resolution, then the live screen JSON and its ACK.")
    }

    private func identifyScenarioUser(_ userId: String) {
        scenarioUserId = userId
        UserpilotManager.shared.identify(userId: userId, properties: ["source": "offline_queue_setup"])
    }

    private func reportScenarioScreen(_ phase: String) {
        UserpilotManager.shared.screen("offline_\(phase)_\(batchIdentifier())")
    }

    private func batchIdentifier() -> String {
        String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
    }

    @objc private func stopTapped() {
        stopBurst(cancelled: true)
    }

    @objc private func openLogs() {
        FlowRoutingManager.shared.openViewController(SDKEventsViewController.newInstance())
    }

    private func startBurst(_ kind: BurstKind) {
        guard burst == nil else { return }
        guard let count = kind == .paced ? 50 : parseCount() else { return }
        let batchId = batchIdentifier()
        paddingPayload = String(repeating: "x", count: selectedPaddingBytes)
        burst = BurstState(kind: kind, total: count, batchId: batchId)
        setControlsEnabled(false)
        scheduleBurstSlice(after: 0)
    }

    private func scheduleBurstSlice(after delay: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in self?.runBurstSlice() }
        pendingBurstWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
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
        case .paced:
            if state.nextIndex.isMultiple(of: 2) { fireScreen(state) } else { fireTrack(state) }
        }
        renderStatus(runningMessage(state))
        if burst != nil, state.nextIndex < state.total {
            scheduleBurstSlice(after: state.kind == .paced ? 0.05 : 0)
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
        pendingBurstWork?.cancel()
        pendingBurstWork = nil
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
        scenarioButtons.forEach { $0.isEnabled = enabled }
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
        button.applyLiquidGlassStyle(.regular, title: title, unifiedHeight: false)
        return button
    }

    private func configureActionButton(_ button: UIButton, title: String, action: Selector, filled: Bool) {
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.applyLiquidGlassStyle(filled ? .prominent : .regular, title: title)
    }

    private func styleChip(_ button: UIButton, selected: Bool) {
        button.applyLiquidGlassStyle(
            selected ? .prominent : .regular,
            title: button.title(for: .normal),
            unifiedHeight: false
        )
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
