//
//  SwiftUIViewSpacingItem.swift
//  ViewSpacingCapture
//
//  측정 대상 하나를 나타내는 공용 모델.
//  SwiftUI 수동 등록(PreferenceKey)과 CALayer 자동 수집이 모두 이 타입으로 결과를 넘깁니다.
//

import CoreGraphics

struct SwiftUIViewSpacingItem: Equatable, Identifiable {
    let id: String
    /// 부모로 취급할 항목의 id. nil이면 측정 루트를 부모로 사용합니다.
    let parentId: String?
    /// 측정 루트 기준 좌표
    let frame: CGRect
}
