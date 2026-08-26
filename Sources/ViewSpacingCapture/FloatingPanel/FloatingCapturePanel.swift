//
//  FloatingCapturePanel.swift
//  ViewSpacingCapture
//
//  Created by 박길호(팀원) - D/I개발담당App개발팀 on 7/20/26.
//

import SwiftUI
import UIKit

// MARK: - DragAbleView 연동용 호스트 뷰

@MainActor
final class FloatingCapturePanel: UIView {
    var onRemove: (() -> Void)?

    private enum Layout {
        static let panelWidth: CGFloat = 165
        static let headerHeight: CGFloat = 44
        static let separatorHeight: CGFloat = 1
        static let rowHeight: CGFloat = 48
    }

    private let model = FloatingCapturePanelModel()
    private var hostingController: UIHostingController<FloatingCapturePanelContent>?

    let collapsedSize = CGSize(width: Layout.panelWidth, height: Layout.headerHeight)

    /// 메뉴 행은 캡처 옵션 + SwiftUI 전용 행, 구분선은 헤더 아래와 SwiftUI 행 위 두 개입니다.
    var expandedHeight: CGFloat {
        let rowCount = ViewSpacingCaptureManager.Option.allCases.count + 1
        return Layout.headerHeight
            + Layout.separatorHeight * 2
            + Layout.rowHeight * CGFloat(rowCount)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHosting()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupHosting()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hostingController?.view.frame = bounds
    }

    private func setupHosting() {
        backgroundColor = .clear

        model.onToggleExpand = { [weak self] in
            guard let self else { return }
            self.setExpanded(!self.model.isExpanded)
        }
        model.onCapture = { [weak self] option in
            self?.capture(option: option)
        }
        model.onSwiftUICapture = { [weak self] in
            self?.captureSwiftUI()
        }
        model.onSettings = { [weak self] in
            self?.presentSettings()
        }
        model.onLongPress = { [weak self] in
            self?.confirmRemove()
        }

        let host = UIHostingController(rootView: FloatingCapturePanelContent(model: model))
        host.view.backgroundColor = .clear
        hostingController = host
        addSubview(host.view)
    }

    private func setExpanded(_ expanded: Bool) {
        model.isExpanded = expanded

        var newFrame = frame
        newFrame.size.height = expanded ? expandedHeight : collapsedSize.height
        UIView.performWithoutAnimation {
            frame = newFrame
            layoutIfNeeded()
        }
    }

    private func capture(option: ViewSpacingCaptureManager.Option) {
        guard let topViewController = Self.currentTopViewController() else { return }
        let target = topViewController.navigationController?.topViewController ?? topViewController
        let wasButtonHidden = FloatingCaptureButton.shared.isShow

        FloatingCaptureButton.shared.hideFloatingButton()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            let viewSpacingCapture = ViewSpacingCaptureManager()
            viewSpacingCapture.option = option
            viewSpacingCapture.captureViewControllerWithBounds(target) { success in
                if wasButtonHidden {
                    FloatingCaptureButton.shared.showFloatingButton()
                }

                if success {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            }
        }
    }

    /// 플로팅 버튼 숨김/복원은 `SwiftUISpacingCapture`가 처리합니다.
    private func captureSwiftUI() {
        guard let topViewController = Self.currentTopViewController() else { return }
        let target = topViewController.navigationController?.topViewController ?? topViewController
        SwiftUISpacingCapture.capture(from: target)
    }

    private func presentSettings() {
        guard let hostView = window else { return }
        isHidden = true
        ViewSpacingSettingsView.present(on: hostView) { [weak self] in
            self?.isHidden = false
        }
    }

    private func confirmRemove() {
        guard let currentVC = Self.currentTopViewController() else { return }

        let alertController = UIAlertController(
            title: "알림",
            message: "OFF 하시겠습니까?",
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.onRemove?()
        })
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))

        currentVC.present(alertController, animated: true)
    }

    private static func currentTopViewController() -> UIViewController? {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return nil
        }

        return findTopViewController(from: rootVC)
    }

    private static func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presentedVC = viewController.presentedViewController {
            return findTopViewController(from: presentedVC)
        }

        if let navigationVC = viewController as? UINavigationController {
            return navigationVC.topViewController ?? navigationVC
        }

        if let tabBarVC = viewController as? UITabBarController {
            return findTopViewController(from: tabBarVC.selectedViewController ?? tabBarVC)
        }

        return viewController
    }
}

// MARK: - 상태 및 액션 전달

@MainActor
final class FloatingCapturePanelModel: ObservableObject {
    @Published var isExpanded = false

    var onToggleExpand: (() -> Void)?
    var onCapture: ((ViewSpacingCaptureManager.Option) -> Void)?
    var onSwiftUICapture: (() -> Void)?
    var onSettings: (() -> Void)?
    var onLongPress: (() -> Void)?
}

// MARK: - SwiftUI 콘텐츠

struct FloatingCapturePanelContent: View {
    @ObservedObject var model: FloatingCapturePanelModel

    private let options = ViewSpacingCaptureManager.Option.allCases

    var body: some View {
        VStack(spacing: 0) {
            header

            if model.isExpanded {
                separator
                ForEach(options, id: \.self) { option in
                    menuRow(title: option.rawValue) {
                        model.onCapture?(option)
                    }
                }
                // SwiftUI 화면용: 뷰 등록 없이 CALayer 트리에서 자동 수집합니다.
                separator
                menuRow(title: "swiftUI") {
                    model.onSwiftUICapture?()
                }
            }
        }
        .frame(width: 165)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        // 호스트 뷰 높이가 갱신되기 전에도 헤더가 제자리를 지키도록 위쪽에 붙입니다.
        .frame(maxHeight: .infinity, alignment: .top)
        .transaction { $0.animation = nil }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Button {
                model.onSettings?()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(UIColor(named: "gray900") ?? .darkGray))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(PlainButtonStyle())

            Button {
                model.onToggleExpand?()
            } label: {
                HStack(spacing: 4) {
                    Text("UI Checker")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)

                    Spacer(minLength: 0)

                    Image(systemName: model.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 16, height: 16)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture {
                model.onLongPress?()
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color(white: 0.9))
            .frame(height: 1)
    }

    private func menuRow(title: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.black)

            Spacer(minLength: 0)

            Button(action: action) {
                Text("캡쳐")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(minWidth: 52)
                    .background(Color(white: 0.15))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
    }
}

// MARK: - Preview

struct FloatingCapturePanelContent_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FloatingCapturePanelContent(model: makeModel(isExpanded: false))
                .previewDisplayName("Collapsed")

            FloatingCapturePanelContent(model: makeModel(isExpanded: true))
                .previewDisplayName("Expanded")
        }
        .padding(24)
        .background(Color(white: 0.85))
        .previewLayout(.sizeThatFits)
    }

    private static func makeModel(isExpanded: Bool) -> FloatingCapturePanelModel {
        let model = FloatingCapturePanelModel()
        model.isExpanded = isExpanded
        model.onToggleExpand = { model.isExpanded.toggle() }
        return model
    }
}
