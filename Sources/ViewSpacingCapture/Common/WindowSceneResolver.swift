import UIKit

@MainActor
enum WindowSceneResolver {
    static func keyWindow(for view: UIView? = nil) -> UIWindow? {
        if let scene = view?.window?.windowScene,
           let window = scene.windows.first(where: \.isKeyWindow) {
            return window
        }

        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let activeScenes = scenes.filter { $0.activationState == .foregroundActive }
        return (activeScenes + scenes.filter { $0.activationState != .foregroundActive })
            .lazy
            .compactMap { $0.windows.first(where: \.isKeyWindow) }
            .first
    }
}
