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
    private var experienceFixture: ExperienceFixture?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.backgroundColor = .systemBackground
        window.makeKeyAndVisible()
        self.window = window
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-carousel-fixture") {
            let fixture = CarouselFixture()
            window.rootViewController = fixture.makeController()
            carouselFixture = fixture
        }
        if let index = arguments.firstIndex(of: "-experience-fixture"), arguments.indices.contains(index + 1) {
            let fixture = ExperienceFixture()
            window.rootViewController = fixture.makeController(
                kind: arguments[index + 1], textScaling: arguments.contains("-text-scaling"))
            experienceFixture = fixture
        }
    }
}
