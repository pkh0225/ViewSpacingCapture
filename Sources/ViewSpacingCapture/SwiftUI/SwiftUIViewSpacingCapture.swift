//
//  SwiftUIViewSpacingCapture.swift
//  ViewSpacingCapture
//
//  SwiftUI 전용 간격 캡처 (UIKit ViewSpacingCaptureManager와 독립)
//

import SwiftUI
import UIKit

// MARK: - Public API

/// SwiftUI 뷰 간격 캡처 진입점.
/// PreferenceKey로 등록된 뷰 frame을 모아 형제/부모 간격을 측정합니다.
@available(iOS 16.0, *)
@MainActor
public enum SwiftUIViewSpacingCapture {
    public static let coordinateSpaceName = "SwiftUIViewSpacingCapture.Root"

    /// 측정선 표시 최대 길이 (pt). UIKit 쪽 `spacingLimit`과 별개입니다.
    public static var spacingLimit: CGFloat {
        get { SwiftUIViewSpacingCaptureStore.shared.spacingLimit }
        set { SwiftUIViewSpacingCaptureStore.shared.spacingLimit = newValue }
    }

    /// 뷰 크기 라벨 표시 여부
    public static var isShowSize: Bool {
        get { SwiftUIViewSpacingCaptureStore.shared.isShowSize }
        set { SwiftUIViewSpacingCaptureStore.shared.isShowSize = newValue }
    }

    /// 현재 등록된 SwiftUI 타겟으로 캡처 후 미리보기를 표시합니다.
    public static func capture(from viewController: UIViewController? = nil) {
        SwiftUIViewSpacingCaptureStore.shared.capture(from: viewController)
    }
}

// MARK: - View Modifiers

@available(iOS 16.0, *)
public extension View {
    /// 간격 캡처 루트. 화면(또는 측정 범위) 최상위에 한 번 붙입니다.
    /// - Parameters:
    ///   - showsLiveOverlay: true면 실시간으로 경계/간격을 화면에 그립니다.
    ///   - showsCaptureButton: true면 우하단에 SwiftUI 전용 캡처 버튼을 표시합니다.
    func viewSpacingCaptureRoot(
        showsLiveOverlay: Bool = false,
        showsCaptureButton: Bool = true
    ) -> some View {
        modifier(
            SwiftUIViewSpacingCaptureRootModifier(
                showsLiveOverlay: showsLiveOverlay,
                showsCaptureButton: showsCaptureButton
            )
        )
    }

    /// 측정 대상 뷰로 등록합니다.
    /// - Parameters:
    ///   - id: 고유 ID
    ///   - parentId: 부모로 취급할 뷰 ID. nil이면 루트를 부모로 사용합니다.
    func viewSpacingCapture(id: String, parentId: String? = nil) -> some View {
        modifier(SwiftUIViewSpacingCaptureItemModifier(id: id, parentId: parentId))
    }
}

// MARK: - Preference

@available(iOS 16.0, *)
enum SwiftUIViewSpacingFramePreferenceKey: PreferenceKey {
    static var defaultValue: [SwiftUIViewSpacingItem] { [] }

    static func reduce(value: inout [SwiftUIViewSpacingItem], nextValue: () -> [SwiftUIViewSpacingItem]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Store

@available(iOS 16.0, *)
@MainActor
final class SwiftUIViewSpacingCaptureStore: ObservableObject {
    static let shared = SwiftUIViewSpacingCaptureStore()

    @Published private(set) var items: [SwiftUIViewSpacingItem] = []
    @Published var showsLiveOverlay = false

    var spacingLimit: CGFloat = 99
    var isShowSize = false

    weak var hostView: UIView?

    private init() {}

    func updateItems(_ items: [SwiftUIViewSpacingItem]) {
        // 같은 id가 여러 번 올라오면 마지막 frame을 사용
        var merged: [String: SwiftUIViewSpacingItem] = [:]
        for item in items {
            merged[item.id] = item
        }
        self.items = Array(merged.values)
    }

    @Published var isCapturing = false

    func capture(from viewController: UIViewController?) {
        let targetView = hostView
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }

        guard let targetView else {
            presentAlert(
                message: "SwiftUI 캡처 루트가 없습니다.\n.viewSpacingCaptureRoot()를 화면 최상위에 추가하세요.",
                from: viewController
            )
            return
        }
        guard !items.isEmpty else {
            presentAlert(
                message: "측정 대상 뷰가 없습니다.\n.viewSpacingCapture(id:)로 뷰를 등록하세요.",
                from: viewController
            )
            return
        }

        let presenter = viewController
            ?? topViewController()
            ?? targetView.window?.rootViewController

        guard let presenter else { return }

        let wasLive = showsLiveOverlay
        showsLiveOverlay = false
        isCapturing = true

        // UIKit 플로팅 버튼이 있으면 잠시 숨김 (기존 로직 미변경, API만 호출)
        let wasFloatingVisible = FloatingCaptureButton.shared.isShow
        if wasFloatingVisible {
            FloatingCaptureButton.shared.hideFloatingButton()
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)

            defer {
                showsLiveOverlay = wasLive
                isCapturing = false
                if wasFloatingVisible {
                    FloatingCaptureButton.shared.showFloatingButton()
                }
            }

            guard let screenshot = captureView(targetView) else { return }

            // Preference frame은 .global → 캡처 뷰 local로 변환
            let originInGlobal = targetView.convert(CGPoint.zero, to: nil)
            let drawn = SwiftUIViewSpacingCaptureRenderer.draw(
                on: screenshot,
                items: items,
                rootBounds: CGRect(origin: .zero, size: targetView.bounds.size),
                frameOffset: CGPoint(x: -originInGlobal.x, y: -originInGlobal.y),
                spacingLimit: spacingLimit,
                isShowSize: isShowSize
            )

            let preview = ImagePreviewViewController()
            preview.image = drawn
            preview.modalPresentationStyle = .fullScreen
            presenter.present(preview, animated: true)

            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }

    private func captureView(_ view: UIView) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
        return renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }

    private func presentAlert(message: String, from viewController: UIViewController?) {
        let presenter = viewController ?? topViewController()
        guard let presenter else { return }
        let alert = UIAlertController(title: "SwiftUI Capture", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        presenter.present(alert, animated: true)
    }

    private func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        var current = window?.rootViewController
        while let presented = current?.presentedViewController {
            current = presented
        }
        if let nav = current as? UINavigationController {
            return nav.topViewController ?? nav
        }
        if let tab = current as? UITabBarController {
            return tab.selectedViewController ?? tab
        }
        return current
    }
}

// MARK: - Item Modifier

@available(iOS 16.0, *)
private struct SwiftUIViewSpacingCaptureItemModifier: ViewModifier {
    let id: String
    let parentId: String?

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SwiftUIViewSpacingFramePreferenceKey.self,
                    value: [
                        SwiftUIViewSpacingItem(
                            id: id,
                            parentId: parentId,
                            frame: proxy.frame(in: .global)
                        )
                    ]
                )
            }
        }
    }
}

// MARK: - Root Modifier

@available(iOS 16.0, *)
private struct SwiftUIViewSpacingCaptureRootModifier: ViewModifier {
    let showsLiveOverlay: Bool
    let showsCaptureButton: Bool

    @ObservedObject private var store = SwiftUIViewSpacingCaptureStore.shared

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: SwiftUIViewSpacingCapture.coordinateSpaceName)
            .background {
                HostViewAnchor { view in
                    // UIHostingController.view 또는 window를 캡처 대상으로 사용
                    store.hostView = resolveHostView(from: view)
                }
            }
            .onPreferenceChange(SwiftUIViewSpacingFramePreferenceKey.self) { items in
                store.updateItems(items)
            }
            .onAppear {
                store.showsLiveOverlay = showsLiveOverlay
            }
            .overlay {
                if store.showsLiveOverlay {
                    GeometryReader { proxy in
                        let origin = proxy.frame(in: .global).origin
                        SwiftUIViewSpacingLiveOverlay(
                            items: store.items.map {
                                SwiftUIViewSpacingItem(
                                    id: $0.id,
                                    parentId: $0.parentId,
                                    frame: $0.frame.offsetBy(dx: -origin.x, dy: -origin.y)
                                )
                            }
                        )
                    }
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showsCaptureButton, !store.isCapturing {
                    captureButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
    }

    private func resolveHostView(from anchor: UIView) -> UIView {
        var current: UIView? = anchor
        var hostingView: UIView?
        while let view = current {
            let name = String(describing: type(of: view))
            if name.contains("HostingView") || name.contains("UIHostingController") {
                hostingView = view
            }
            if let window = view as? UIWindow {
                return hostingView ?? window
            }
            current = view.superview
        }
        return hostingView ?? anchor.superview ?? anchor
    }

    private var captureButton: some View {
        Button {
            store.capture(from: nil)
        } label: {
            Label("SwiftUI 캡처", systemImage: "camera.viewfinder")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Host Anchor

@available(iOS 16.0, *)
private struct HostViewAnchor: UIViewRepresentable {
    var onResolve: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            onResolve(uiView)
        }
    }
}

// MARK: - Live Overlay

@available(iOS 16.0, *)
private struct SwiftUIViewSpacingLiveOverlay: View {
    let items: [SwiftUIViewSpacingItem]

    var body: some View {
        Canvas { context, _ in
            let measurements = SwiftUIViewSpacingCaptureRenderer.measurements(
                items: items,
                rootBounds: .null,
                spacingLimit: SwiftUIViewSpacingCaptureStore.shared.spacingLimit
            )

            for item in items {
                var path = Path(item.frame.insetBy(dx: 0.25, dy: 0.25))
                context.stroke(path, with: .color(.cyan.opacity(0.85)), lineWidth: 0.8)
            }

            for line in measurements {
                var path = Path()
                path.move(to: line.start)
                path.addLine(to: line.end)
                context.stroke(
                    path,
                    with: .color(line.isParentInset ? .red : .pink),
                    style: StrokeStyle(lineWidth: 0.8, dash: [4, 2])
                )
            }
        }
    }
}
