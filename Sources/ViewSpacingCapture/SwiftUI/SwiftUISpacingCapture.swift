//
//  SwiftUISpacingCapture.swift
//  ViewSpacingCapture
//
//  뷰 등록 없이 SwiftUI 화면의 간격을 캡처합니다.
//  (기존 UIKit `ViewSpacingCaptureManager` 경로와는 독립적으로 동작합니다.)
//

import UIKit

@MainActor
public enum SwiftUISpacingCapture {

    /// 측정선을 표시할 최대 길이 (pt)
    public static var spacingLimit: CGFloat = 99

    /// 각 박스에 크기 라벨을 함께 표시할지 여부
    public static var isShowSize = false

    /// 이 크기 미만의 레이어는 무시합니다.
    public static var minimumSize: CGFloat = 1

    /// 텍스트/이미지처럼 `contents`로만 그려지는 레이어 포함 여부
    public static var includesContentLayers = true

    /// 현재 화면을 캡처해 측정 결과를 미리보기로 표시합니다.
    /// - Parameter viewController: 대상 컨트롤러. nil이면 최상단 컨트롤러를 사용합니다.
    public static func capture(
        from viewController: UIViewController? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let presenter = viewController ?? topViewController() else {
            completion?(false)
            return
        }

        let targetView = presenter.view ?? presenter.viewIfLoaded
        guard let targetView else {
            completion?(false)
            return
        }

        // UIKit 플로팅 버튼이 떠 있으면 캡처 동안만 숨깁니다.
        let wasFloatingVisible = FloatingCaptureButton.shared.isShow
        if wasFloatingVisible {
            FloatingCaptureButton.shared.hideFloatingButton()
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)

            defer {
                if wasFloatingVisible {
                    FloatingCaptureButton.shared.showFloatingButton()
                }
            }

            guard let image = makeImage(of: targetView) else {
                completion?(false)
                return
            }

            let preview = ImagePreviewViewController()
            preview.image = image
            preview.modalPresentationStyle = .fullScreen
            presenter.present(preview, animated: true)

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            completion?(true)
        }
    }

    /// 대상 뷰의 스크린샷 위에 자동 수집한 경계와 간격을 그립니다.
    public static func makeImage(of view: UIView) -> UIImage? {
        guard let screenshot = render(view) else { return nil }

        var options = SwiftUILayerHierarchyBuilder.Options()
        options.minimumSize = minimumSize
        options.includesContentLayers = includesContentLayers

        let items = SwiftUILayerHierarchyBuilder.build(rootView: view, options: options)
        guard !items.isEmpty else { return screenshot }

        return SwiftUIViewSpacingCaptureRenderer.draw(
            on: screenshot,
            items: items,
            rootBounds: view.bounds,
            spacingLimit: spacingLimit,
            isShowSize: isShowSize
        )
    }

    // MARK: - Helpers

    private static func render(_ view: UIView) -> UIImage? {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
        return renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }

        var current = window?.rootViewController
        while let presented = current?.presentedViewController {
            current = presented
        }
        if let navigation = current as? UINavigationController {
            return navigation.topViewController ?? navigation
        }
        if let tab = current as? UITabBarController {
            return tab.selectedViewController ?? tab
        }
        return current
    }
}
