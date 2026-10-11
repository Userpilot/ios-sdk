import UIKit

// This app exists only to host the SDK's local XCTest rendering fixtures.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Renderer validation", sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var carouselFixture: CarouselFixture?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.backgroundColor = .systemBackground
        window.makeKeyAndVisible()
        self.window = window
        if ProcessInfo.processInfo.arguments.contains("-carousel-fixture") {
            let fixture = CarouselFixture()
            window.rootViewController = fixture.makeController()
            carouselFixture = fixture
        }
    }
}
