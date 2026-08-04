//
//  SwiftUISpacingCaptureButton.swift
//  ViewSpacingCapture
//
//  SwiftUI 화면에서 캡처를 실행하기 위한 트리거 UI.
//  플로팅 패널을 쓰지 않는 앱에서 사용합니다.
//  측정 대상 등록은 필요 없고, 이 modifier 하나만 붙이면 됩니다.
//

import SwiftUI

@available(iOS 15.0, *)
public extension View {
    /// 화면에 캡처 버튼을 띄웁니다. 측정 대상 등록은 필요 없습니다.
    func swiftUISpacingCaptureButton(alignment: Alignment = .bottomTrailing) -> some View {
        modifier(SwiftUISpacingCaptureButtonModifier(alignment: alignment))
    }
}

@available(iOS 15.0, *)
private struct SwiftUISpacingCaptureButtonModifier: ViewModifier {
    let alignment: Alignment

    /// 버튼 자신이 측정에 잡히지 않도록, 캡처 중에는 계층에서 제거합니다.
    @State private var isCapturing = false

    func body(content: Content) -> some View {
        content.overlay(alignment: alignment) {
            if !isCapturing {
                button
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
            }
        }
    }

    private var button: some View {
        Button {
            isCapturing = true
            SwiftUISpacingCapture.capture { _ in
                isCapturing = false
            }
        } label: {
            Label("swiftUI 캡쳐", systemImage: "camera.viewfinder")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
