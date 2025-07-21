//
//  FloatingCaptureButton.swift
//  ViewSpacingCapture
//
//  Created by 박길호 on 7/18/25.
//

import UIKit

// MARK: - 플로팅 캡처 버튼 관리자
public class FloatingCaptureButton {
    public static let shared = FloatingCaptureButton()

    private var floatingButton: DraggableButton?

    private init() {}

    public func showFloatingButton() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            return
        }

        // 기존 버튼이 있으면 제거
        hideFloatingButton()
        
        // 드래그 가능한 버튼 생성
        floatingButton = DraggableButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        guard let button = floatingButton else { return }

        button.setTitle("📷", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false

        // 버튼 탭 액션 설정 (클로저 사용)
        button.onTap = { [weak self] in
            self?.captureButtonTapped()
        }
        button.onRemove = { [weak self] in
            self?.hideFloatingButton()
        }

        // 윈도우에 추가
        window.addSubview(button)

        // 초기 위치 설정 (우측 상단)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 50),
            button.heightAnchor.constraint(equalToConstant: 50),
            button.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -20),
            button.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 100)
        ])

        // 애니메이션으로 나타나기
        button.alpha = 0
        button.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            button.alpha = 1
            button.transform = .identity
        }
    }

    func hideFloatingButton() {
        floatingButton?.removeFromSuperview()
        floatingButton = nil
    }

    @objc private func captureButtonTapped() {
        // 현재 표시중인 뷰컨트롤러 찾기
        guard let currentVC = getCurrentViewController() else {
            print("현재 뷰컨트롤러를 찾을 수 없습니다.")
            return
        }

        // 네비게이션의 마지막 뷰컨트롤러 또는 현재 뷰컨트롤러 캡처
        let targetVC = getTargetViewController(from: currentVC)
        captureViewControllerWithBounds(targetVC)
    }

    private func captureViewControllerWithBounds(_ viewController: UIViewController) {
        // 플로팅 버튼 임시 숨기기
        let wasButtonHidden = floatingButton?.isHidden ?? true
        floatingButton?.isHidden = true

        // 잠시 후 캡처 실행 (UI 업데이트 대기)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let viewSpacingCapture = ViewSpacingCaptureManager()
            viewSpacingCapture.captureViewControllerWithBounds(viewController) { [weak self] success in
                // 캡처 완료 후 버튼 다시 표시
                self?.floatingButton?.isHidden = wasButtonHidden

                if success {
                    // 햅틱 피드백
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            }

            // 임시로 성공 처리 및 버튼 복원
            print("\(viewController.self) 캡처 시뮬레이션 성공")
            self.floatingButton?.isHidden = wasButtonHidden
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }
}

// MARK: - 드래그 가능한 버튼
class DraggableButton: UIButton, UIGestureRecognizerDelegate {

    // 탭 이벤트가 발생했을 때 실행될 클로저
    var onTap: (() -> Void)?
    // 제거 이벤트
    var onRemove: (() -> Void)?

    private var panGesture: UIPanGestureRecognizer!
    private var tapGesture: UITapGestureRecognizer!
    private var longPress: UILongPressGestureRecognizer!
    private var initialCenter: CGPoint = .zero

    deinit {
        print("deinit DraggableButton")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }

    private func setupGestures() {
        // 팬 제스처 (드래그)
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        self.addGestureRecognizer(panGesture)

        // 탭 제스처 (클릭)
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        self.addGestureRecognizer(tapGesture)

        longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture(_:)))
        self.addGestureRecognizer(longPress)
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let superview = self.superview else { return }
        let translation = gesture.translation(in: superview)

        switch gesture.state {
        case .began:
            initialCenter = self.center
            // 드래그 시작 시 약간 작아지는 애니메이션
            UIView.animate(withDuration: 0.1) {
                self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        case .changed:
            let newCenter = CGPoint(
                x: initialCenter.x + translation.x,
                y: initialCenter.y + translation.y
            )
            // 화면 경계 체크
            let safeArea = superview.safeAreaInsets
            let minX = bounds.width / 2
            let maxX = superview.bounds.width - bounds.width / 2
            let minY = safeArea.top + bounds.height / 2
            let maxY = superview.bounds.height - safeArea.bottom - bounds.height / 2

            self.center = CGPoint(
                x: max(minX, min(maxX, newCenter.x)),
                y: max(minY, min(maxY, newCenter.y))
            )
        case .ended, .cancelled:
            // 터치 종료 시 원래 크기로 복원 및 가장자리로 이동
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
                self.transform = .identity
            }
            snapToEdge()
        default:
            break
        }
    }

    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        // 탭 애니메이션
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
        // 설정된 클로저 실행
        onTap?()
    }

    private func snapToEdge() {
        guard let superview = superview else { return }

        let centerX = center.x
        let screenWidth = superview.bounds.width
        let margin: CGFloat = 20

        // 좌측 또는 우측 가장자리로 이동
        let targetX = centerX < screenWidth / 2 ? margin + bounds.width / 2 : screenWidth - margin - bounds.width / 2

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.center.x = targetX
        }
    }

    @objc private func handleLongPressGesture(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard let currentVC = getCurrentViewController() else { return }

        let alertController = UIAlertController(title: "알림",
                                                message: "OFF 하시겠습니까?",
                                                preferredStyle: .alert)

        let okAction = UIAlertAction(title: "확인", style: .default) { _ in
            self.removeFromSuperview()
            self.onRemove?()
        }
        alertController.addAction(okAction)

        let cancelAction = UIAlertAction(title: "취소", style: .cancel) { _ in

        }
        alertController.addAction(cancelAction)


        currentVC.present(alertController, animated: true, completion: nil)
    }

    // 팬 제스처가 시작되면 탭 제스처는 실패하도록 하여 동시 인식을 방지
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

private func getCurrentViewController() -> UIViewController? {
    guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
          let rootVC = window.rootViewController else {
        return nil
    }

    return findTopViewController(from: rootVC)
}

private func findTopViewController(from viewController: UIViewController) -> UIViewController {
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

private func getTargetViewController(from currentVC: UIViewController) -> UIViewController {
    // 네비게이션 컨트롤러가 있는 경우 마지막 뷰컨트롤러 반환
    if let navigationController = currentVC.navigationController {
        return navigationController.topViewController ?? currentVC
    }

    return currentVC
}
