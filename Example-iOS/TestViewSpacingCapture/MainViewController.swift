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
    }

    @IBAction func pushSwiftUIScreenCapture(_ sender: Any) {
        let viewController = ScreenCaptureSwiftUIViewController()
        viewController.title = "TestScreenCaptureSwiftUI"
        navigationController?.pushViewController(viewController, animated: true)
    }

    @IBAction func showCaptureButton(_ sender: UIButton) {
        FloatingCaptureButton.shared.showFloatingButton()
    }
}

