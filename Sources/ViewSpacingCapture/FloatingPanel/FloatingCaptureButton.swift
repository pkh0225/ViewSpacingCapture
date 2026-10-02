//
//  FloatingCaptureButton.swift
//  ViewSpacingCapture
//
//  Created by 박길호 on 7/18/25.
//

import UIKit
import DragAbleView

// MARK: - 플로팅 캡처 버튼 관리자
@MainActor
public class FloatingCaptureButton {
    public static let shared = FloatingCaptureButton()

    private var dragAbleViewManager: DragAbleViewManager?
    private var floatingPanel: FloatingCapturePanel?

    public var isShow: Bool {
        floatingPanel != nil
    }

    private init() {}

    private func addFloatingButton(view: UIView) {
        guard let window = WindowSceneResolver.keyWindow() else { return }

        let top = window.safeAreaInsets.top
        let bottom = window.safeAreaInsets.bottom

        if dragAbleViewManager == nil {
            dragAbleViewManager = DragAbleViewManager(containerView: window,
                                                      setBoundsIntoBoundary: UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0),
                                                      itemViews: [view],
                                                      snapsToNearestEdge: false)
        }
        else {
            dragAbleViewManager?.addView(view: view)
        }
    }

    func resizeFloatingPanel(_ panel: FloatingCapturePanel, to frame: CGRect) {
        guard floatingPanel === panel else {
            panel.frame = frame
            return
        }

        // UIKit Dynamics는 뷰의 중심 위치를 추적하므로, 크기를 바꾼 뒤 다시 등록해
        // 패널이 이동하지 않고 헤더 아래쪽으로 펼쳐지도록 합니다.
        dragAbleViewManager?.removeView(view: panel)
        panel.frame = frame
        dragAbleViewManager?.addView(view: panel)
    }

    public func showFloatingButton() {
        guard let window = WindowSceneResolver.keyWindow() else {
            return
        }

        hideFloatingButton()

        let panel = FloatingCapturePanel()
        floatingPanel = panel
        panel.onRemove = { [weak self] in
            self?.hideFloatingButton()
        }

        let top = window.safeAreaInsets.top + 100
        let size = panel.collapsedSize
        panel.frame = CGRect(
            x: window.bounds.width - 20 - size.width,
            y: top,
            width: size.width,
            height: size.height
        )

        panel.alpha = 0
        panel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)

        addFloatingButton(view: panel)

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            panel.alpha = 1
            panel.transform = .identity
        }
    }

    func hideFloatingButton() {
        if let panel = floatingPanel {
            dragAbleViewManager?.removeView(view: panel)
        }
        floatingPanel = nil
    }
}
