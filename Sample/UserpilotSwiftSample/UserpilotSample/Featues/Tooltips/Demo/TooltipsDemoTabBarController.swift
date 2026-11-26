//
//  TooltipsDemoTabBarController.swift
//  UserpilotSample
//
//  Bottom tab bar hosting Dashboard, Newsfeed, and Profile demo screens.
//

import UIKit

final class TooltipsDemoTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Demo App"
        view.backgroundColor = SampleAppearance.screenBackground
        setupTabs()
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserpilotManager.shared.screen("tooltips demo")
    }

    private func setupTabs() {
        let dashboard = DashboardViewController()
        dashboard.tabBarItem = UITabBarItem(
            title: "Dashboard",
            image: UIImage(systemName: "chart.bar.fill"),
            tag: 0
        )

        let newsfeed = NewsfeedViewController()
        newsfeed.tabBarItem = UITabBarItem(
            title: "Newsfeed",
            image: UIImage(systemName: "photo.on.rectangle.angled"),
            tag: 1
        )

        let profile = ProfileViewController()
        profile.tabBarItem = UITabBarItem(
            title: "Profile",
            image: UIImage(systemName: "person.crop.circle"),
            tag: 2
        )

        viewControllers = [dashboard, newsfeed, profile]
        selectedIndex = 0
    }
}
