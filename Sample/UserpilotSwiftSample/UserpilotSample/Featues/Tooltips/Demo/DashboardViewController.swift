//
//  DashboardViewController.swift
//  UserpilotSample
//
//  Demo dashboard with statistic cards and charts.
//

import UIKit

final class DashboardViewController: BaseViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let metrics: [DashboardMetric] = [
        DashboardMetric(
            id: "users",
            title: "Active Users",
            value: "12.4K",
            delta: "+8.2%",
            symbolName: "person.3.fill",
            chartValues: [4, 6, 5, 8, 7, 9, 11],
            chartLabels: ["M", "T", "W", "T", "F", "S", "S"]
        ),
        DashboardMetric(
            id: "revenue",
            title: "Revenue",
            value: "$48.2K",
            delta: "+12.1%",
            symbolName: "dollarsign.circle.fill",
            chartValues: [12, 15, 14, 18, 22, 20, 25],
            chartLabels: ["M", "T", "W", "T", "F", "S", "S"]
        ),
        DashboardMetric(
            id: "sessions",
            title: "Sessions",
            value: "3.8K",
            delta: "-2.4%",
            symbolName: "chart.line.uptrend.xyaxis",
            chartValues: [9, 8, 10, 7, 6, 8, 7],
            chartLabels: ["M", "T", "W", "T", "F", "S", "S"]
        )
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dashboard"
        view.accessibilityIdentifier = "demo-dashboard-screen"
        setupLayout()
        buildContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("demo dashboard")
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 32, right: 16)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func buildContent() {
        let header = UILabel()
        header.text = "Overview"
        header.font = .systemFont(ofSize: 22, weight: .bold)
        contentStack.addArrangedSubview(header)

        let cardsRow = UIStackView()
        cardsRow.axis = .horizontal
        cardsRow.spacing = 12
        cardsRow.distribution = .fillEqually

        for metric in metrics {
            let card = makeStatCard(for: metric)
            cardsRow.addArrangedSubview(card)
        }
        contentStack.addArrangedSubview(cardsRow)

        let chartsHeader = UILabel()
        chartsHeader.text = "Trends"
        chartsHeader.font = .systemFont(ofSize: 22, weight: .bold)
        contentStack.addArrangedSubview(chartsHeader)

        for metric in metrics {
            contentStack.addArrangedSubview(makeChartCard(for: metric))
        }
    }

    private func makeStatCard(for metric: DashboardMetric) -> UIView {
        let card = CardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.accessibilityIdentifier = "demo-stat-\(metric.id)"
        card.isUserInteractionEnabled = true

        let icon = UIImageView(image: UIImage(systemName: metric.symbolName))
        icon.tintColor = SampleAppearance.accentColor
        // Symbols are not square; fit them inside the 22 pt box instead of stretching.
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = metric.title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 2

        let valueLabel = UILabel()
        valueLabel.text = metric.value
        valueLabel.font = .systemFont(ofSize: 20, weight: .bold)

        let deltaLabel = UILabel()
        deltaLabel.text = metric.delta
        deltaLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        deltaLabel.textColor = metric.delta.hasPrefix("-") ? .systemRed : .systemGreen

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, valueLabel, deltaLabel])
        stack.axis = .vertical
        // Leading, not fill: fill would stretch the 22 pt icon across the whole card.
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMetricTap(_:)))
        card.addGestureRecognizer(tap)
        card.tag = metrics.firstIndex(where: { $0.id == metric.id }) ?? 0
        return card
    }

    private func makeChartCard(for metric: DashboardMetric) -> UIView {
        let card = CardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.accessibilityIdentifier = "demo-chart-\(metric.id)"
        card.isUserInteractionEnabled = true

        let titleLabel = UILabel()
        titleLabel.text = "\(metric.title) · 7 days"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)

        let chart = SimpleBarChartView()
        chart.values = metric.chartValues
        chart.labels = metric.chartLabels
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.heightAnchor.constraint(equalToConstant: 140).isActive = true

        let stack = UIStackView(arrangedSubviews: [titleLabel, chart])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMetricTap(_:)))
        card.addGestureRecognizer(tap)
        card.tag = metrics.firstIndex(where: { $0.id == metric.id }) ?? 0
        return card
    }

    @objc
    private func handleMetricTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, metrics.indices.contains(view.tag) else { return }
        FlowRoutingManager.shared.openViewController(
            DashboardDetailViewController(metric: metrics[view.tag])
        )
    }
}

struct DashboardMetric {
    let id: String
    let title: String
    let value: String
    let delta: String
    let symbolName: String
    let chartValues: [CGFloat]
    let chartLabels: [String]
}
