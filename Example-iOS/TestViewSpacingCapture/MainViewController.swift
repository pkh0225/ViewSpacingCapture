//
//  ViewController.swift
//  TestViewSpacingCapture
//
//  Created by 박길호(팀원) - 서비스개발담당App개발팀 on 7/18/25.
//

import UIKit
import ViewSpacingCapture

class MainViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        Task{ @MainActor in
            // 플로팅 버튼 표시
            FloatingCaptureButton.shared.showFloatingButton()
        }
    }

    @IBAction func pushSwiftUIScreenCapture(_ sender: Any) {
        if #available(iOS 16.0, *) {
            let viewController = ScreenCaptureSwiftUIViewController()
            viewController.title = "TestScreenCaptureSwiftUI"
            navigationController?.pushViewController(viewController, animated: true)
        } else {
            let alert = UIAlertController(
                title: nil,
                message: "SwiftUI 테스트 화면은 iOS 16 이상에서 사용할 수 있습니다.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
        }
    }
}

