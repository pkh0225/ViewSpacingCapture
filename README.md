# ViewSpacingCapture
View Spacing Viewer

[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

화면에 보여지는 뷰들의 간격을 볼 수 있는 기능  
**UIKit**과 **SwiftUI** 모두 지원합니다.

버튼만 추가 후 원하는 화면으로 이동해 버튼을 클릭하면 볼 수 있습니다.  
플로팅 패널에서 UIKit 캡처(space / image / font / radius)와 **swiftUI** 캡처를 선택할 수 있습니다.

### UIKit

```swift
import UIKit
import ViewSpacingCapture

class MainViewController: UIViewController {

    @IBAction func showCheckerTapped(_ sender: Any) {
        FloatingCaptureButton.shared.showFloatingButton()
    }
}
```

### SwiftUI

```swift
import SwiftUI
import ViewSpacingCapture

struct ContentView: View {
    var body: some View {
        Button("UI Checker 표시") {
            FloatingCaptureButton.shared.showFloatingButton()
        }
    }
}
```

SwiftUI 화면은 별도 뷰 등록 없이, 패널의 **swiftUI**로 레이어 트리를 자동 수집해 간격을 표시합니다.

UI Checker 롱터치시 닫기 기능 지원

<img src="https://github.com/pkh0225/ViewSpacingCapture/blob/main/Images/Sample.png" width="500"> 
<img src="https://github.com/pkh0225/ViewSpacingCapture/blob/main/Images/Sample3.png" width="500">
<img src="https://github.com/pkh0225/ViewSpacingCapture/blob/main/Images/Sample2.png" width="500">
