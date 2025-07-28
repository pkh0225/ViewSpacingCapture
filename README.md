# ViewSpacingCapture
View Spaceing Viewer

[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

화면에 보여지는 뷰들의 간격을 볼 수 있는 기능

버튼만 추가 후 원하는 화면으로 이동 수 버튼을 클릭하면 볼 수 있음

```swift
import UIKit
import ViewSpacingCapture

class MainViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // 플로팅 버튼 표시
        FloatingCaptureButton.shared.showFloatingButton()
        
    }
}
```
<img src="https://github.com/pkh0225/ViewSpacingCapture/blob/main/Images/Sample.png" width="500">  <img src="https://github.com/pkh0225/ViewSpacingCapture/blob/main/Images/Sample2.png" width="500">


