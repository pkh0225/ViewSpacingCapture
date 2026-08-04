//
//  SwiftUISpacingCapture.swift
//  ViewSpacingCapture
//
//  뷰 등록 없이 SwiftUI 화면의 간격을 캡처합니다.
//  수집 방식은 UIKit 경로와 다르지만, 설정 화면의 공통 옵션은 함께 사용합니다.
//

import UIKit

@MainActor
public enum SwiftUISpacingCapture {

    /// 측정선을 표시할 최대 길이 (pt). 설정 화면의 "라인 표시 제한"과 공유합니다.
    public static var spacingLimit: CGFloat {
        get { ViewSpacingCaptureSettings.spacingLimit }
        set { ViewSpacingCaptureSettings.spacingLimit = newValue }
    }

    /// 각 박스에 크기 라벨을 표시할지 여부. 설정 화면의 "사이즈 표시"와 공유합니다.
    public static var isShowSize: Bool {
        get { ViewSpacingCaptureSettings.isShowSize }
        set { ViewSpacingCaptureSettings.isShowSize = newValue }
    }

    /// 화면 컨트롤러 대신 key window 전체를 캡처할지 여부. 설정 화면의 "Window 캡쳐"와 공유합니다.
    public static var isWindowsTarget: Bool {
        get { ViewSpacingCaptureSettings.isWindowsTarget }
        set { ViewSpacingCaptureSettings.isWindowsTarget = newValue }
    }

    /// 덮인 레이어를 결과에서 제외할지 여부. 설정 화면의 "가려진뷰 숨기기"와 공유합니다.
    public static var isHidesOccludedViews: Bool {
        get { ViewSpacingCaptureSettings.isHidesOccludedViews }
        set { ViewSpacingCaptureSettings.isHidesOccludedViews = newValue }
    }

    /// 가림 판정 시 가장자리 오차를 흡수하기 위한 inset. 설정 화면의 "Sample Inset"과 공유합니다.
    public static var occlusionSampleInset: CGFloat {
        get { ViewSpacingCaptureSettings.occlusionSampleInset }
        set { ViewSpacingCaptureSettings.occlusionSampleInset = newValue }
    }

    /// 가려진 것으로 처리할 덮임 비율 (0...1). 설정 화면의 "Coverage"와 공유합니다.
    public static var occlusionCoverageThreshold: Double {
        get { ViewSpacingCaptureSettings.occlusionCoverageThreshold }
        set { ViewSpacingCaptureSettings.occlusionCoverageThreshold = newValue }
    }

    /// 축당 최대 샘플 수. 설정 화면의 "Max Samples / Axis"와 공유합니다.
    public static var occlusionMaxSamplesPerAxis: Int {
        get { ViewSpacingCaptureSettings.occlusionMaxSamplesPerAxis }
        set { ViewSpacingCaptureSettings.occlusionMaxSamplesPerAxis = newValue }
    }

    /// 텍스트/이미지처럼 `contents`로만 그려지는 레이어 포함 여부. 설정 화면의 "텍스트/이미지 포함하기"와 공유합니다.
    public static var includesContentLayers: Bool {
        get { ViewSpacingCaptureSettings.includesContentLayers }
        set { ViewSpacingCaptureSettings.includesContentLayers = newValue }
    }

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

        let targetView = isWindowsTarget ? (keyWindow() ?? presenter.view) : presenter.view
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
        options.includesContentLayers = includesContentLayers
        options.hidesOccludedViews = isHidesOccludedViews
        options.occlusionSampleInset = occlusionSampleInset
        options.occlusionCoverageThreshold = occlusionCoverageThreshold
        options.occlusionMaxSamplesPerAxis = occlusionMaxSamplesPerAxis

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

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    private static func topViewController() -> UIViewController? {
        var current = keyWindow()?.rootViewController
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
