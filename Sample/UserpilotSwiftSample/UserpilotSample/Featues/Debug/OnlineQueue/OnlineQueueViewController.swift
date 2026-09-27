//
//  OnlineQueueViewController.swift
//  UserpilotSample
//
//  Manual harness for online analytics-queue / onSocketEventSent scenarios.
//  Stay ONLINE. Verify fake_reload / start_session via Logs + Xcode console.
//

// Each scenario is a self-contained QA script with its own expected-result text; keeping them
// in one harness is the point of the screen.
// swiftlint:disable file_length

import UIKit

final class OnlineQueueViewController: UIViewController {

    // MARK: - Constants

    private let screenTitle = "online queue"
    private let screenS1 = "queue_s1_home"
    private let screenS2 = "queue_s2_settings"
    private let screenS3 = "queue_s3_profile"
    private let settleMs: TimeInterval = 0.4
    private let switchGapMs: TimeInterval = 0.7
    private let contentGapMs: TimeInterval = 0.6

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let statusLabel = UILabel()
    private let reportScreenSwitch = UISwitch()
    private let userAField = UITextField()
    private let userBField = UITextField()

    private var skipNextAutoScreen = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Online queue"
        view.backgroundColor = SampleAppearance.screenBackground
        setupUI()
        statusLabel.text = "Ready. Stay online. Identify A + establish screen, then run a scenario."
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        if skipNextAutoScreen {
//            skipNextAutoScreen = false
//            return
//        }
        // if reportScreenSwitch.isOn {
        UserpilotManager.shared.screen(screenTitle)
        // }
    }

    // MARK: - Setup

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let logsButton = makeButton("Events log / Logs", action: #selector(openLogs))
        logsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logsButton)

        NSLayoutConstraint.activate([
            logsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: logsButton.topAnchor, constant: -8)
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

        addStatusHeader()
        addUserInputs()
        addScenarioButtons()
    }

    /// Status readout plus the usage hint at the top of the scroll view.
    private func addStatusHeader() {
        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .label
        statusLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        // padding via container
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

        let hint = makeLabel(
            """
            Stay ONLINE. Logging=true. Scenario buttons fire identify/screen/track \
            for onSocketEventSent fake_reload + start_session checks.
            """
        )
        hint.textColor = .secondaryLabel
        stackView.addArrangedSubview(hint)
    }

    /// The "report screen on appear" toggle and the two user-id fields.
    private func addUserInputs() {
        let switchRow = UIStackView()
        switchRow.axis = .horizontal
        switchRow.alignment = .center
        switchRow.spacing = 12
        switchRow.addArrangedSubview(makeLabel("Report screen(\"online queue\") on appear"))
        reportScreenSwitch.isOn = true
        switchRow.addArrangedSubview(reportScreenSwitch)
        stackView.addArrangedSubview(switchRow)

        userAField.placeholder = "User A id"
        userAField.text = "queue_user_a"
        userAField.borderStyle = .roundedRect
        userBField.placeholder = "User B id (new user)"
        userBField.text = "queue_user_b"
        userBField.borderStyle = .roundedRect
        stackView.addArrangedSubview(userAField)
        stackView.addArrangedSubview(userBField)
    }

    /// The scenario / manual-API button list. Titles double as the QA checklist.
    private func addScenarioButtons() {
        let sections: [(String, [(String, Selector)])] = [
            ("Setup", [
                ("1. Identify User A", #selector(setupIdentifyA)),
                ("2. Establish current screen", #selector(setupScreen)),
                ("Logout (clear session)", #selector(logoutTapped))
            ]),
            ("Scenarios (ONQ)", [
                ("S1 Identify only → fake_reload=true, start_session=false", #selector(runIdentifyOnly)),
                ("S2 Identify NEW user → fake_reload=false, start_session=true", #selector(runNewUser)),
                ("S3 Identify + screen in queue → NO fake screen", #selector(runIdentifyPlusScreen)),
                ("S4 Identify + track + screen → NO fake screen", #selector(runIdentifyTrackScreen)),
                ("S5 Identify A then Identify B", #selector(runIdentifyThenNewUser)),
                ("S6 Identify + 2 screens (content)", #selector(runTwoScreens)),
                ("S7 Identify + 3 screens (fake reload title)", #selector(runThreeScreens)),
                ("S8 Identify with NO current screen", #selector(runNoScreen)),
                ("S9 Failed ACK (manual network drop)", #selector(runFailedAck)),
                ("S10 Teo multi-app content check", #selector(runTeo))
            ]),
            ("Manual APIs", [
                ("screen(queue_s1_home)", #selector(manualS1)),
                ("screen(queue_s2_settings)", #selector(manualS2)),
                ("screen(queue_s3_profile)", #selector(manualS3)),
                ("track(unique)", #selector(manualTrack)),
                ("End experience (trigger fake reload)", #selector(endExperience))
            ])
        ]

        for (title, buttons) in sections {
            stackView.addArrangedSubview(makeSection(title))
            for (buttonTitle, action) in buttons {
                stackView.addArrangedSubview(makeButton(buttonTitle, action: action))
            }
        }
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
        return label
    }

    private func makeButton(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.applyLiquidGlassStyle(.regular, title: title, unifiedHeight: false)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

}

// MARK: - Actions

private extension OnlineQueueViewController {

    @objc func openLogs() {
        FlowRoutingManager.shared.openViewController(SDKEventsViewController.newInstance())
    }

    @objc private func setupIdentifyA() {
        identify(userA(), ["source": "online_queue_setup"])
        setStatus("Identified \(userA()). Wait for Identify in Logs, then run a scenario.")
    }

    @objc private func setupScreen() {
        UserpilotManager.shared.screen(screenTitle)
        setStatus("Manual screen('\(screenTitle)') sent.")
    }

    @objc private func logoutTapped() {
        UserpilotManager.shared.logout()
        setStatus("logout() called.")
    }

    @objc private func runIdentifyOnly() {
        UserpilotManager.shared.screen(screenTitle)
        DispatchQueue.main.asyncAfter(deadline: .now() + settleMs) { [weak self] in
            guard let self else { return }
            self.identify(self.userA(), [
                "scenario": "identify_only",
                "ts": Int(Date().timeIntervalSince1970 * 1000)
            ])
            self.setStatus(
                """
                S1 Identify-only (same user)
                Expected after Identify ACK: synthetic screen title='\(self.screenTitle)', \
                fake_reload=true, start_session=false.
                """
            )
        }
    }

    @objc private func runNewUser() {
        UserpilotManager.shared.screen(screenTitle)
        DispatchQueue.main.asyncAfter(deadline: .now() + settleMs) { [weak self] in
            guard let self else { return }
            self.identify(self.userB(), ["scenario": "new_user"])
            self.setStatus(
                """
                S2 Identify new user (\(self.userB()))
                Expected after B Identify ACK: synthetic screen, fake_reload=false, start_session=true.
                """
            )
        }
    }

    @objc private func runIdentifyPlusScreen() {
        identify(userA(), ["scenario": "identify_plus_screen"])
        UserpilotManager.shared.screen(screenS1)
        setStatus(
            """
            S3 Identify + screen in queue
            Fired identify then screen('\(screenS1)') immediately.
            Expected: NO synthetic post-identify screen. Order: Identify → Screen('\(screenS1)').
            """
        )
    }

    @objc private func runIdentifyTrackScreen() {
        let trackName = "queue_btn_\(Int(Date().timeIntervalSince1970 * 1000) % 100000)"
        identify(userA(), ["scenario": "identify_track_screen"])
        UserpilotManager.shared.track(eventName: trackName, properties: ["scenario": "identify_track_screen"])
        UserpilotManager.shared.screen(screenS1)
        setStatus(
            """
            S4 Identify + track + screen
            Expected: NO synthetic fake screen. Order: Identify → track('\(trackName)') → screen('\(screenS1)').
            """
        )
    }

    @objc private func runIdentifyThenNewUser() {
        UserpilotManager.shared.screen(screenTitle)
        DispatchQueue.main.asyncAfter(deadline: .now() + settleMs) { [weak self] in
            guard let self else { return }
            self.identify(self.userA(), ["scenario": "identify_then_switch_step1"])
            DispatchQueue.main.asyncAfter(deadline: .now() + self.switchGapMs) {
                self.identify(self.userB(), ["scenario": "identify_then_switch_step2"])
                self.setStatus(
                    """
                    S5 Identify A then Identify B
                    Expected after B ACK (empty queue + screen): fake_reload=false, \
                    start_session=true for \(self.userB()).
                    """
                )
            }
        }
    }

    @objc private func runTwoScreens() {
        identify(userA(), ["scenario": "two_screens"])
        UserpilotManager.shared.screen(screenS1)
        DispatchQueue.main.asyncAfter(deadline: .now() + contentGapMs) { [weak self] in
            guard let self else { return }
            UserpilotManager.shared.screen(self.screenS2)
            self.setStatus(
                """
                S6 Identify + screen + screen (content)
                Expected: content for each screen title; no extra fake reload between them.
                """
            )
        }
    }

    @objc private func runThreeScreens() {
        identify(userA(), ["scenario": "three_screens"])
        UserpilotManager.shared.screen(screenS1)
        DispatchQueue.main.asyncAfter(deadline: .now() + contentGapMs) { [weak self] in
            guard let self else { return }
            UserpilotManager.shared.screen(self.screenS2)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + contentGapMs * 2) { [weak self] in
            guard let self else { return }
            UserpilotManager.shared.screen(self.screenS3)
            self.setStatus(
                """
                S7 Identify + 3 screens
                Screens: \(self.screenS1) → \(self.screenS2) → \(self.screenS3).
                Show content, then End experience on the CURRENT screen.
                Expected fake_reload title = CURRENT screen title.
                """
            )
        }
    }

    @objc private func runNoScreen() {
        reportScreenSwitch.isOn = false
        skipNextAutoScreen = true
        UserpilotManager.shared.logout()
        DispatchQueue.main.asyncAfter(deadline: .now() + settleMs) { [weak self] in
            guard let self else { return }
            self.identify(self.userA(), ["scenario": "no_screen_yet"])
            self.setStatus(
                """
                S8 Identify with no current screen
                logout + identify without screen().
                Expected: NO synthetic screen until a real screen() happens.
                """
            )
        }
    }

    @objc private func runFailedAck() {
        UserpilotManager.shared.track(
            eventName: "queue_pre_fail_\(Int(Date().timeIntervalSince1970 * 1000) % 100000)",
            properties: ["scenario": "failed_ack_prep"]
        )
        setStatus(
            """
            S9 Failed ACK
            1. Start track/identify while ONLINE.
            2. Enable Airplane Mode before ACK.
            3. Restore network and fire another track.
            Expected: drop head, continue queue.
            """
        )
    }

    @objc private func runTeo() {
        UserpilotManager.shared.screen(screenS1)
        identify(userA(), ["scenario": "teo_app_screen", "screen": screenS1])
        setStatus(
            """
            S10 Teo multi-app
            Identify on every screen for THIS token/app and verify content.
            Switch token in Configurations, repeat on App2.
            Expected: no cross-app content bleed.
            """
        )
    }

    @objc private func manualS1() {
        UserpilotManager.shared.screen(screenS1)
        setStatus("screen('\(screenS1)')")
    }

    @objc private func manualS2() {
        UserpilotManager.shared.screen(screenS2)
        setStatus("screen('\(screenS2)')")
    }

    @objc private func manualS3() {
        UserpilotManager.shared.screen(screenS3)
        setStatus("screen('\(screenS3)')")
    }

    @objc private func manualTrack() {
        let name = "queue_track_\(Int(Date().timeIntervalSince1970 * 1000) % 100000)"
        UserpilotManager.shared.track(eventName: name, properties: ["harness": "online_queue"])
        setStatus("track('\(name)')")
    }

    @objc private func endExperience() {
        UserpilotManager.shared.endExperience()
        setStatus("endExperience() — fake_reload only when analytics queue is empty; title = current screen.")
    }

    // MARK: - Helpers

    private func identify(_ userId: String, _ properties: [String: Any]) {
        UserpilotManager.shared.identify(userId: userId, properties: properties)
    }

    private func userA() -> String {
        let value = userAField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "queue_user_a" : value
    }

    private func userB() -> String {
        let value = userBField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "queue_user_b" : value
    }

    private func setStatus(_ text: String) {
        statusLabel.text = text
    }
}
