//
//  SwiftUISpacingMarker.swift
//  ViewSpacingCapture
//
//  VStack/HStack 같은 레이아웃 컨테이너는 그리는 것이 없어 CALayer를 남기지 않습니다.
//  캡처가 프레임을 잡을 수 있도록 거의 투명한 테두리를 넣어 표시해 둡니다.
//

import SwiftUI

public extension View {
    /// 설정이 켜져 있을 때만 프레임에 거의 투명한 테두리를 넣어 캡처 대상으로 남깁니다.
    ///
    /// `Text`/`Image`처럼 이미 `contents` 레이어를 남기는 뷰는 자동으로 수집되므로,
    /// `VStack`/`HStack`/`ZStack`처럼 그리는 것이 없는 컨테이너에 붙이면 됩니다.
    func spacingMarker() -> some View {
        modifier(SpacingMarkerModifier())
    }
}

struct SpacingMarkerModifier: ViewModifier {
    /// 설정이 바뀌면 화면이 즉시 갱신되도록 UserDefaults를 직접 관찰합니다.
    @AppStorage(ViewSpacingCaptureSettings.spacingMarkerKey) private var isEnabled = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.border(Color.red.opacity(0.01))
        }
        else {
            content
        }
    }
}
