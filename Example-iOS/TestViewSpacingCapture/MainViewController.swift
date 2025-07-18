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

        // 플로팅 버튼 표시
        FloatingCaptureButton.shared.showFloatingButton()
        
    }


}

