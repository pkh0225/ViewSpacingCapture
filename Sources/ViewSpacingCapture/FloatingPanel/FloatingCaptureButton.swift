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
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }

        let top = window.safeAreaInsets.top
        let bottom = window.safeAreaInsets.bottom

        if dragAbleViewManager == nil {
            dragAbleViewManager = DragAbleViewManager(containerView: window,
                                                      setBoundsIntoBoundary: UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0),
                                                      itemViews: [view])
        }
        else {
            dragAbleViewManager?.addView(view: view)
        }
    }

    public func showFloatingButton() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
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
