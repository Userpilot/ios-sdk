//
//  OnlineQueueViewController.swift
//  Userpilot SDK
//
//  Created by Userpilot on 07/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Guided online queue scenarios mirror Android and explain each action’s expected screen flags.
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
    private let burstEventCount = 50
    private let burstInterval: TimeInterval = 0.05
    private let userSwitchCallCount = 33

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let statusLabel = UILabel()
    private let reportScreenSwitch = UISwitch()
    private let userAField = UITextField()
    private let userBField = UITextField()

    private var burstWorkItem: DispatchWorkItem?
    private weak var burstButton: UIButton?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Online queue"
        view.backgroundColor = SampleAppearance.screenBackground
        setupUI()
        statusLabel.text =
            "Ready. Choose a scenario and read its prerequisites before tapping. Verify results in socket logs."
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if reportScreenSwitch.isOn {
            UserpilotManager.shared.screen(screenTitle)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard burstWorkItem != nil else { return }
        burstWorkItem?.cancel()
        burstWorkItem = nil
        burstButton?.isEnabled = true
        setStatus("Burst stopped. Already submitted calls remain in the SDK queue.")
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
            Stay ONLINE with SDK logging enabled. Flags below are (is_session_start, fake_reload). Read actual \
            socket payloads and successful ACKs; a delay or submission status is not an ACK. Disable SDK screen \
            autocapture and automatic identify for isolated manual runs. The report-on-appear switch starts OFF. \
            Fresh-install cases require a clean SDK identity and the stated screen preconditions.
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
        reportScreenSwitch.isOn = false
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

}

// MARK: - Scenario instructions

private extension OnlineQueueViewController {

    /// Keep scenario instructions above their action so prerequisites are visible before tapping.
    private func addScenarioButtons() {
        addSetupScenarios()
        addIdentityScenarios()
        addRemainingIdentityScenarios()
        addQueueScenarios()
        addGuidedQueueScenarios()
        addExperienceScenarios()
        addStressScenarios()
        addManualScenarios()
    }

    private func addSetupScenarios() {
        stackView.addArrangedSubview(makeSection("Set up and inspect"))
        addScenario(
            "Identify User A",
            """
            Scenario: Use A and B with different IDs. Submit identify(A); inspect the actual reply before \
            continuing.
            Expected: Identify alone does not consume session-start. A known screen may follow its ACK.
            """,
            action: #selector(setupIdentifyA)
        )
        addScenario(
            "Report current screen",
            """
            Scenario: After identify, report online queue and wait for its successful screen ACK.
            Expected: The first screen sends (true, false); live navigation sends (false, false). An unchanged title \
            and its ACK preserve session-start.
            """,
            action: #selector(setupScreen)
        )
        addScenario(
            "Logout",
            """
            Scenario: Clear the current identity and all unsent events.
            Expected: The next identified session starts with (true, false). Logout does not erase the app \
            navigation context.
            """,
            action: #selector(logoutTapped)
        )
    }

    private func addIdentityScenarios() {
        stackView.addArrangedSubview(makeSection("Identity and initial screens"))
        addScenario(
            "S13 First identify with a known screen",
            """
            Scenario: Fresh SDK data, no prior identify: submit screen(queue_s1_home), then identify(A). Disable \
            automatic identification first.
            Expected: The unidentified screen is not delivered. When its navigation title is available, identify ACK \
            generates (true, false). Otherwise report the screen explicitly.
            """,
            action: #selector(runFirstIdentifyKnown)
        )
        addScenario(
            "S8 First identify with no known screen",
            """
            Scenario: Fresh SDK data and no screen/autocapture reports anywhere: identify(A). This screen cannot \
            clear an existing navigation title.
            Expected: If no screen is known, identify ACK sends no generated screen. The first later real screen \
            sends (true, false).
            """,
            action: #selector(runNoScreen)
        )
        addScenario(
            "S14 Repeat identify before first screen",
            """
            Scenario: Logout, identify(A), identify(A) again, then queue queue_s1_home in one button action.
            Expected: Repeated identify preserves the pending initial session. The first screen sends (true, false), \
            with no extra generated screen while one is queued.
            """,
            action: #selector(runRepeatBeforeScreen)
        )
        addScenario(
            "S1 Repeat identify after screen ACK",
            """
            Scenario: A is already identified. First observe a successful screen ACK and an empty queue, then \
            identify(A) again.
            Expected: Generated refresh: (true, true) on the first screen, (false, true) after navigation. Same-user \
            identify and screen ACKs preserve session-start; this action does not report another real screen.
            """,
            action: #selector(runIdentifyOnly)
        )
    }

    private func addRemainingIdentityScenarios() {
        addScenario(
            "S2 Switch from A to B",
            """
            Scenario: Start with A and an established screen. Identify B without logout. A and B must differ.
            Expected: Clear old-user pending events. B’s first screen sends (true, false); use a manual screen if no \
            title is available.
            """,
            action: #selector(runNewUser)
        )
        addScenario(
            "S15 Logout then identify the same user",
            """
            Scenario: Start with A. Logout, identify(A), then queue queue_s1_home.
            Expected: The first screen after logout sends (true, false), even though the ID matches the logged-out \
            user.
            """,
            action: #selector(runLogoutSameUser)
        )
        addScenario(
            "S16 Logout then identify another user",
            """
            Scenario: Start with A. Logout, identify(B), then queue queue_s1_home.
            Expected: The first screen for B sends (true, false). Unsent events from A are cleared.
            """,
            action: #selector(runLogoutDifferentUser)
        )
        addScenario(
            "S5 Identify A then B immediately",
            """
            Scenario: Submit identify(A), identify(B), and queue queue_s1_home without waiting for ACKs.
            Expected: B owns the remaining queue. Its first screen sends (true, false); an old A reply must not \
            advance B’s queue.
            """,
            action: #selector(runIdentifyThenNewUser)
        )
    }

    private func addQueueScenarios() {
        stackView.addArrangedSubview(makeSection("Queue ordering and navigation"))
        addScenario(
            "S3 Identify then queue a screen",
            """
            Scenario: Identify(A), then immediately queue queue_s1_home.
            Expected: No generated post-identify refresh while that screen is queued. Initial boundary: (true, \
            false); normal changed screen: (false, false).
            """,
            action: #selector(runIdentifyPlusScreen)
        )
        addScenario(
            "S4 Identify, track, then screen",
            """
            Scenario: Identify(A), track a unique event, then queue queue_s1_home.
            Expected: FIFO: identify → track → screen, advancing on replies. No extra generated screen while a \
            screen is queued.
            """,
            action: #selector(runIdentifyTrackScreen)
        )
        addScenario(
            "S6 Change screen twice",
            """
            Scenario: With an identified user and joined socket, submit queue_s1_home then queue_s2_settings.
            Expected: A changed existing screen clears session-start: (false, false). A pending identity boundary \
            still gives its first screen (true, false).
            """,
            action: #selector(runTwoScreens)
        )
        addScenario(
            "S7 Visit three screen titles",
            """
            Scenario: With an identified user, submit home → settings → profile. After delivery settles, finish \
            content on the current screen.
            Expected: Real screens use fake_reload=false. Dismissal refresh uses the current title and \
            fake_reload=true, preserving current session-start.
            """,
            action: #selector(runThreeScreens)
        )
        addScenario(
            "S9 Failed screen ACK — guided",
            """
            Scenario: From a pending initial session, send a screen and interrupt its ACK using a controlled \
            network/proxy. Inspect the failed request before continuing.
            Expected: Both failed and successful screen replies preserve session-start. Only live navigation ends \
            it during an uninterrupted session.
            """,
            action: #selector(runFailedAck)
        )
    }

    private func addGuidedQueueScenarios() {
        addScenario(
            "S19 Preserved true / true — guided",
            """
            Scenario: Let the same-user session expire in background. Wait for the resumed screen ACK, then identify \
            the same user again without navigating. Ensure no screen is queued.
            Expected: The generated refresh is (true, true). The resumed screen ACK preserves session-start.
            """,
            action: #selector(runPreservedStartHint)
        )
        addScenario(
            "S10 Multi-app content check",
            """
            Scenario: On this app/token, identify A and request home. Repeat with a second configured app/token.
            Expected: Each app requests its own content. Screen refreshes keep that app’s current screen title.
            """,
            action: #selector(runTeo)
        )
    }

    private func addExperienceScenarios() {
        stackView.addArrangedSubview(makeSection("Experience dismissal"))
        addScenario(
            "S17 Dismiss content with no queued screen",
            """
            Scenario: Display real backend content and let its screen ACK complete. Ensure no screen remains queued, \
            then close/complete the actual content. This button shows the checklist.
            Expected: After UI removal, enqueue one refresh: (true, true) on the first screen, (false, true) after \
            navigation. Repeat dismissal: its ACK preserves the flag. Tracks stay ahead; throttle blocks host repeats.
            """,
            action: #selector(runDismissalHint)
        )
        addScenario(
            "S18 Dismiss content with a queued screen",
            """
            Scenario: With slow real replies, submit a screen burst, then close actual content while a later screen \
            is still queued. Confirm this precondition in the trace; this button submits three different screens.
            Expected: Skip the generated dismissal refresh when any screen is queued. The queued real screen keeps \
            fake_reload=false and normal session-start rules.
            """,
            action: #selector(runQueuedDismissal)
        )
    }

    private func addStressScenarios() {
        stackView.addArrangedSubview(makeSection("Stress — submissions every 50 ms"))
        addScenario(
            "S11 Send 50 alternating calls",
            """
            Scenario: Identify first and observe its ACK. Submit 25 screens and 25 tracks, alternating, 50 ms apart. \
            Start without active content.
            Expected: Submissions can outpace ACKs. Check FIFO 1–50; completion here means submitted, not \
            acknowledged. Real screens use fake_reload=false.
            """,
            action: #selector(runAlternatingBurst(_:))
        )
        addScenario(
            "S12 Switch and logout during a burst",
            """
            Scenario: Identify first. Send 10 tracks → fresh user → 10 tracks → logout → another fresh user → 10 \
            tracks, with 50 ms between calls.
            Expected: Pending events clear at switch/logout. Final events follow the final identify ACK. Old ACKs \
            must not advance the new queue.
            """,
            action: #selector(runUserSwitchBurst(_:))
        )
    }

    private func addManualScenarios() {
        stackView.addArrangedSubview(makeSection("Manual controls"))
        addScenario(
            "Report home",
            """
            Scenario: Submit queue_s1_home. Repeat after the throttle window to check an unchanged title.
            Expected: A real screen uses fake_reload=false. The same title and its successful ACK preserve \
            session-start.
            """,
            action: #selector(manualS1)
        )
        addScenario(
            "Report settings",
            """
            Scenario: Submit queue_s2_settings after home.
            Expected: Joined socket + changed existing screen clears session-start, unless an initial identity \
            boundary is still pending.
            """,
            action: #selector(manualS2)
        )
        addScenario(
            "Report profile",
            """
            Scenario: Submit queue_s3_profile after settings.
            Expected: A real changed screen normally sends (false, false); inspect the title and both flags in the \
            socket payload.
            """,
            action: #selector(manualS3)
        )
        addScenario(
            "Track a unique event",
            """
            Scenario: Submit one named track event for the current user.
            Expected: Track does not change either screen flag. It retains its place in the ACK-driven queue.
            """,
            action: #selector(manualTrack)
        )
        addScenario(
            "Call endExperience()",
            """
            Scenario: While content is visible, call the public endExperience API. For completion/dismissal callback \
            checks, also use the actual content controls above.
            Expected: Inspect the resulting experience event and refresh. This API alone is not proof that every \
            real UI completion path has been exercised.
            """,
            action: #selector(endExperience)
        )
    }

    private func addScenario(_ title: String, _ details: String, action: Selector) {
        let label = makeLabel(details)
        label.textColor = .secondaryLabel
        stackView.addArrangedSubview(label)
        let button = makeButton(title, action: action)
        stackView.addArrangedSubview(button)
        stackView.setCustomSpacing(18, after: button)
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
        identify(userA(), ["scenario": "identify_only"])
        setStatus("S1: identify(A) submitted. Preserve session-start: true on first screen, false after navigation; fake_reload=true.")
    }

    @objc private func runNewUser() {
        identify(userB(), ["scenario": "new_user"])
        setStatus("S2: identify(B) submitted. B must differ from A; its first screen uses (true, false).")
    }

    @objc private func runIdentifyPlusScreen() {
        identify(userA(), ["scenario": "identify_plus_screen"])
        UserpilotManager.shared.screen(screenS1)
        setStatus("S3: identify → screen submitted. A queued screen prevents an extra generated refresh.")
    }

    @objc private func runIdentifyTrackScreen() {
        identify(userA(), ["scenario": "identify_track_screen"])
        UserpilotManager.shared.track(
            eventName: "queue_btn_\(Int(Date().timeIntervalSince1970 * 1000))",
            properties: ["scenario": "identify_track_screen"]
        )
        UserpilotManager.shared.screen(screenS1)
        setStatus("S4: identify → track → screen submitted. Inspect FIFO delivery and matching ACKs.")
    }

    @objc private func runIdentifyThenNewUser() {
        identify(userA(), ["scenario": "identify_then_switch_step1"])
        identify(userB(), ["scenario": "identify_then_switch_step2"])
        UserpilotManager.shared.screen(screenS1)
        setStatus("S5: identify(A) → identify(B) → screen submitted. B starts with (true, false).")
    }

    @objc private func runTwoScreens() {
        UserpilotManager.shared.screen(screenS1)
        UserpilotManager.shared.screen(screenS2)
        setStatus("S6: home → settings submitted. Changed screen: (false, false), except a pending initial boundary.")
    }

    @objc private func runThreeScreens() {
        submitThreeScreens()
        setStatus("S7: home → settings → profile submitted. After content finishes, inspect the refresh title.")
    }

    @objc private func runNoScreen() {
        reportScreenSwitch.isOn = false
        identify(userA(), ["scenario": "no_screen_yet"])
        setStatus(
            "S8 requires fresh SDK data and no known title. Existing app navigation is not cleared by this button."
        )
    }

    @objc private func runFailedAck() {
        setStatus(
            "S9 guided: start an initial session, block its screen ACK using a controlled proxy/network, " +
            "then inspect the failure. Failed ACKs do not consume session-start. No SDK call was submitted."
        )
    }

    @objc private func runTeo() {
        identify(userA(), ["scenario": "teo_app_screen", "screen": screenS1])
        UserpilotManager.shared.screen(screenS1)
        setStatus("S10: identify + home submitted for this app. Repeat with App 2; verify app-specific content.")
    }

    @objc private func runFirstIdentifyKnown() {
        reportScreenSwitch.isOn = false
        UserpilotManager.shared.screen(screenS1)
        identify(userA(), ["scenario": "first_identify_known_screen"])
        setStatus(
            "S13: screen before identify submitted. Fresh SDK data required; first identified screen: (true, false)."
        )
    }

    @objc private func runRepeatBeforeScreen() {
        UserpilotManager.shared.logout()
        identify(userA(), ["scenario": "repeat_before_screen", "attempt": 1])
        identify(userA(), ["scenario": "repeat_before_screen", "attempt": 2])
        UserpilotManager.shared.screen(screenS1)
        setStatus("S14: logout → identify(A) → identify(A) → screen submitted. First screen: (true, false).")
    }

    @objc private func runLogoutSameUser() {
        UserpilotManager.shared.logout()
        identify(userA(), ["scenario": "logout_same_user"])
        UserpilotManager.shared.screen(screenS1)
        setStatus("S15: logout → identify(A) → screen submitted. First screen after logout: (true, false).")
    }

    @objc private func runLogoutDifferentUser() {
        UserpilotManager.shared.logout()
        identify(userB(), ["scenario": "logout_different_user"])
        UserpilotManager.shared.screen(screenS1)
        setStatus("S16: logout → identify(B) → screen submitted. First screen after logout: (true, false).")
    }

    @objc private func runDismissalHint() {
        setStatus(
            "S17 guided: close or complete real content using its own controls, with no screen queued. " +
            "After UI removal: one queued refresh, fake_reload=true, current session-start preserved."
        )
    }

    @objc private func runQueuedDismissal() {
        submitThreeScreens()
        setStatus(
            "S18: three screens submitted. Close real content only while the trace confirms a later screen " +
            "is still queued. Expected: skip generated dismissal refresh. Fast ACKs may miss this precondition."
        )
    }

    @objc private func runPreservedStartHint() {
        setStatus(
            "S19 guided: expired same-user session, resumed screen acknowledged, no navigation or queued screen. " +
            "Repeat identify: (true, true). Screen ACKs preserve session-start. No SDK call was submitted."
        )
    }

    private func submitThreeScreens() {
        UserpilotManager.shared.screen(screenS1)
        UserpilotManager.shared.screen(screenS2)
        UserpilotManager.shared.screen(screenS3)
    }

    @objc private func runAlternatingBurst(_ sender: UIButton) {
        guard burstWorkItem == nil else { return }
        sender.isEnabled = false
        burstButton = sender
        let batchId = String(UUID().uuidString.prefix(8)).lowercased()
        sendBurstEvent(batchId: batchId, index: 1)
    }

    // Submit independently of ACKs so a slow socket can build up the normal analytics queue.
    private func sendBurstEvent(batchId: String, index: Int) {
        let kind = index % 2 == 1 ? "screen" : "track"
        let name = "queue_\(kind)_\(batchId)_\(index)"
        if kind == "screen" {
            UserpilotManager.shared.screen(name)
        } else {
            UserpilotManager.shared.track(eventName: name, properties: [
                "scenario": "alternating_burst", "batch_id": batchId, "index": index
            ])
        }
        setStatus("Batch \(batchId): submitted \(index)/\(burstEventCount)\n\(name)")
        if index == burstEventCount {
            burstWorkItem = nil
            burstButton?.isEnabled = true
            setStatus(
                """
                Batch \(batchId): submitted 50 calls (25 screens + 25 tracks), 50 ms apart.
                Submission finished; socket ACKs may still be pending. Check Logs + console for order 1…50.
                """
            )
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            self?.sendBurstEvent(batchId: batchId, index: index + 1)
        }
        burstWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + burstInterval, execute: workItem)
    }

    @objc private func runUserSwitchBurst(_ sender: UIButton) {
        guard burstWorkItem == nil else {
            setStatus("Wait for the current burst to finish before running S12.")
            return
        }
        sender.isEnabled = false
        burstButton = sender
        let batchId = String(UUID().uuidString.prefix(8)).lowercased()
        sendUserSwitchStep(batchId: batchId, step: 1)
    }

    // The 33 calls are 10 tracks, identify, 10 tracks, logout, identify, then 10 tracks.
    private func sendUserSwitchStep(batchId: String, step: Int) {
        let properties: [String: Any] = ["scenario": "user_switch_burst", "batch_id": batchId]
        switch step {
        case 1...10: sendUserSwitchEvent(batchId: batchId, phase: "before_switch", index: step)
        case 11: identify("queue_switch_\(batchId)", properties)
        case 12...21: sendUserSwitchEvent(batchId: batchId, phase: "after_switch", index: step - 11)
        case 22: UserpilotManager.shared.logout()
        case 23: identify("queue_login_\(batchId)", properties)
        default: sendUserSwitchEvent(batchId: batchId, phase: "after_logout", index: step - 23)
        }
        setStatus("S12 batch \(batchId): submitted call \(step)/\(userSwitchCallCount), 50 ms apart.")
        if step == userSwitchCallCount {
            burstWorkItem = nil
            burstButton?.isEnabled = true
            setStatus(
                """
                S12 batch \(batchId): submitted 30 track calls, 2 identifies, and logout, 50 ms apart.
                Switched to queue_switch_\(batchId); final user is queue_login_\(batchId).
                Expected: pending before_switch events clear on identify; pending after_switch events clear on logout.
                after_logout events follow the final Identify ACK. Already sent events may still receive old ACKs.
                Check Logs + console: old ACKs must not advance the final user's queue.
                """
            )
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            self?.sendUserSwitchStep(batchId: batchId, step: step + 1)
        }
        burstWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + burstInterval, execute: workItem)
    }

    private func sendUserSwitchEvent(batchId: String, phase: String, index: Int) {
        UserpilotManager.shared.track(
            eventName: "queue_\(phase)_\(batchId)_\(index)",
            properties: ["scenario": "user_switch_burst", "batch_id": batchId, "phase": phase, "index": index]
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
        setStatus(
            "endExperience() submitted. Also close actual content to verify UI removal and dismissal refresh ordering."
        )
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
