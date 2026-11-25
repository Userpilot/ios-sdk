//
//  DebuggerPanelView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//

import UIKit

internal final class DebuggerPanelView: UIView {

    var onDismissRequested: (() -> Void)?

    private let eventStore: DebugEventStoring
    private let configFactory: DebugConfigSnapshotMaking
    private let userFactory: DebugUserSnapshotMaking

    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let tabStack = UIStackView()
    private let indicator = UIView()
    private let content = UIView()
    private let toastLabel = UILabel()

    private let configList = DebuggerListView()
    private let userList = DebuggerListView()
    private let manualList = DebuggerListView()
    private let autoList = DebuggerListView()
    private let internalList = DebuggerListView()
    private let flowList = DebuggerListView()

    private var tabs: [UIButton] = []
    private var selectedTab = DebugTab.config
    private var observerIds: [UUID] = []
    private var indicatorLeading: NSLayoutConstraint?
    private var indicatorWidth: NSLayoutConstraint?

    private enum DebugTab: Int, CaseIterable {
        case config, user, manual, autoCapture, internalSDK, flow

        var title: String {
            switch self {
            case .config: return DebuggerStrings.tabConfig
            case .user: return DebuggerStrings.tabUser
            case .manual: return DebuggerStrings.tabManual
            case .autoCapture: return DebuggerStrings.tabAuto
            case .internalSDK: return DebuggerStrings.tabInternal
            case .flow: return DebuggerStrings.tabFlow
            }
        }
    }

    init(
        eventStore: DebugEventStoring,
        configFactory: DebugConfigSnapshotMaking,
        userFactory: DebugUserSnapshotMaking
    ) {
        self.eventStore = eventStore
        self.configFactory = configFactory
        self.userFactory = userFactory
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observerIds.forEach { eventStore.removeObserver($0) }
    }

    func onShown() {
        refreshStaticTab()
        startObserving()
    }

    func onHidden() {
        stopObserving()
    }

    private func setup() {
        backgroundColor = DebuggerTheme.surface
        layer.cornerRadius = DebuggerTheme.panelCorner
        clipsToBounds = true
        isUserInteractionEnabled = true

        titleLabel.text = DebuggerStrings.panelTitle
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = DebuggerTheme.text

        configureIconButton(closeButton, systemName: "xmark", label: DebuggerStrings.closeAccessibility)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        tabStack.axis = .horizontal
        tabStack.distribution = .fillEqually
        tabStack.alignment = .fill

        indicator.backgroundColor = DebuggerTheme.brand

        toastLabel.text = DebuggerStrings.copied
        toastLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastLabel.layer.cornerRadius = 16
        toastLabel.clipsToBounds = true
        toastLabel.alpha = 0

        bindLists()
        layoutChrome()
        buildTabs()
        showTab(.config)
        refreshStaticTab()
    }

    private func bindLists() {
        let copy: (String) -> Void = { [weak self] value in
            DebuggerClipboard.copy(value)
            self?.showCopiedToast()
        }
        configList.onPropertyTap = copy
        userList.onPropertyTap = copy
        flowList.onPropertyTap = copy
    }

    private func layoutChrome() {
        let header = UIStackView(arrangedSubviews: [titleLabel, closeButton])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 4

        let divider = UIView()
        divider.backgroundColor = DebuggerTheme.divider

        [header, tabStack, indicator, divider, content, toastLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        closeButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        indicator.heightAnchor.constraint(equalToConstant: 2).isActive = true
        indicatorLeading = indicator.leadingAnchor.constraint(equalTo: tabStack.leadingAnchor)
        indicatorWidth = indicator.widthAnchor.constraint(equalToConstant: 0)
        indicatorLeading?.isActive = true
        indicatorWidth?.isActive = true

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            tabStack.topAnchor.constraint(equalTo: header.bottomAnchor),
            tabStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabStack.heightAnchor.constraint(equalToConstant: 44),
            indicator.topAnchor.constraint(equalTo: tabStack.bottomAnchor),
            divider.topAnchor.constraint(equalTo: indicator.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            content.topAnchor.constraint(equalTo: divider.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            toastLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -24),
            toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 88),
            toastLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
        toastLabel.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }

    private func buildTabs() {
        for tab in DebugTab.allCases {
            let button = UIButton(type: .system)
            button.setTitle(tab.title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.8
            button.tag = tab.rawValue
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabs.append(button)
            tabStack.addArrangedSubview(button)
        }
        updateTabColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        moveIndicator(animated: false)
    }
}

// MARK: - Tabs, lists, toast

private extension DebuggerPanelView {

    @objc func tabTapped(_ sender: UIButton) {
        guard let tab = DebugTab(rawValue: sender.tag) else { return }
        showTab(tab)
    }

    @objc func closeTapped() {
        onDismissRequested?()
    }

    private func showTab(_ tab: DebugTab) {
        selectedTab = tab
        updateTabColors()
        moveIndicator(animated: true)
        content.subviews.forEach { $0.removeFromSuperview() }
        let list = listForTab(tab)
        list.frame = content.bounds
        list.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        content.addSubview(list)
        refreshStaticTab()
    }

    private func listForTab(_ tab: DebugTab) -> DebuggerListView {
        switch tab {
        case .user: return userList
        case .manual: return manualList
        case .autoCapture: return autoList
        case .internalSDK: return internalList
        case .flow: return flowList
        case .config: return configList
        }
    }

    func refreshStaticTab() {
        if selectedTab == .config {
            configList.showProperties(configFactory.create().toListItems())
        } else if selectedTab == .user {
            userList.showProperties(userFactory.create().toListItems())
        } else if selectedTab == .flow {
            let snapshot = DebugSnapshot(sections: eventStore.flowRuns.map(\.section))
            flowList.showProperties(snapshot.toListItems(), emptyText: DebuggerStrings.emptyFlows)
        }
    }

    func startObserving() {
        stopObserving()
        observerIds = [
            eventStore.observe(.manual) { [weak self] in
                performOnMain {
                    guard let self else { return }
                    self.manualList.showEvents(self.eventStore.events(for: .manual))
                }
            },
            eventStore.observe(.autoCapture) { [weak self] in
                performOnMain {
                    guard let self else { return }
                    self.autoList.showEvents(self.eventStore.events(for: .autoCapture))
                }
            },
            eventStore.observe(.internalSDK) { [weak self] in
                performOnMain {
                    guard let self else { return }
                    self.internalList.showEvents(self.eventStore.events(for: .internalSDK))
                }
            },
            eventStore.observe(.flow) { [weak self] in
                performOnMain {
                    guard let self, self.selectedTab == .flow else { return }
                    self.refreshStaticTab()
                }
            }
        ]
    }

    func stopObserving() {
        observerIds.forEach { eventStore.removeObserver($0) }
        observerIds = []
    }

    func updateTabColors() {
        for (index, button) in tabs.enumerated() {
            let selected = index == selectedTab.rawValue
            button.setTitleColor(selected ? DebuggerTheme.brand : DebuggerTheme.secondary, for: .normal)
        }
    }

    func moveIndicator(animated: Bool) {
        guard !tabs.isEmpty, tabStack.bounds.width > 0 else { return }
        let width = tabStack.bounds.width / CGFloat(tabs.count)
        indicatorWidth?.constant = width
        indicatorLeading?.constant = width * CGFloat(selectedTab.rawValue)
        if animated {
            UIView.animate(withDuration: DebuggerTheme.fadeDuration) { self.layoutIfNeeded() }
        }
    }

    func showCopiedToast() {
        toastLabel.alpha = 1
        UIView.animate(
            withDuration: DebuggerTheme.fadeDuration,
            delay: 1.2,
            options: [.curveEaseIn, .beginFromCurrentState]
        ) {
            self.toastLabel.alpha = 0
        }
    }

    func configureIconButton(_ button: UIButton, systemName: String, label: String) {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = DebuggerTheme.icon
        button.accessibilityLabel = label
    }

}
