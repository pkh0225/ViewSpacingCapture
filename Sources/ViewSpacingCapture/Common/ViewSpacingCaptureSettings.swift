//
//  ViewSpacingCaptureSettings.swift
//  ViewSpacingCapture
//
//  캡처 옵션을 한곳에서 관리합니다.
//  UIKit(`ViewSpacingCaptureManager`)과 SwiftUI(`SwiftUISpacingCapture`) 캡처가 함께 사용합니다.
//

import UIKit

enum ViewSpacingCaptureSettings {
    // MARK: - 표시

    /// 각 박스에 크기 라벨을 함께 표시할지 여부
    static var isShowSize: Bool {
        get { store.bool(Key.isShowSize, default: false) }
        set { store.set(newValue, forKey: Key.isShowSize) }
    }

    /// 측정선을 표시할 최대 길이 (pt)
    static var spacingLimit: CGFloat {
        get { store.cgFloat(Key.spacingLimit, default: 99) }
        set { store.set(newValue, forKey: Key.spacingLimit) }
    }

    // MARK: - 가려진 뷰

    /// 다른 요소에 덮인 항목을 결과에서 제외할지 여부
    static var isHidesOccludedViews: Bool {
        get { store.bool(Key.isHidesOccludedViews, default: true) }
        set { store.set(newValue, forKey: Key.isHidesOccludedViews) }
    }

    /// 가림 판정 시 가장자리 오차를 흡수하기 위한 inset
    static var occlusionSampleInset: CGFloat {
        get { store.cgFloat(Key.occlusionSampleInset, default: 1.0) }
        set { store.set(max(0, newValue), forKey: Key.occlusionSampleInset) }
    }

    /// 샘플 중 이 비율 이상 덮이면 가려진 것으로 처리 (0...1)
    static var occlusionCoverageThreshold: Double {
        get { store.double(Key.occlusionCoverageThreshold, default: 0.10) }
        set { store.set(min(max(newValue, 0), 1), forKey: Key.occlusionCoverageThreshold) }
    }

    /// 축당 최대 샘플 수 (큰 뷰의 과도한 샘플링 방지)
    static var occlusionMaxSamplesPerAxis: Int {
        get { max(2, store.int(Key.occlusionMaxSamplesPerAxis, default: 12)) }
        set { store.set(max(2, newValue), forKey: Key.occlusionMaxSamplesPerAxis) }
    }

    // MARK: - 수집

    /// 화면 컨트롤러 대신 window 전체를 캡처할지 여부
    static var isWindowsTarget: Bool {
        get { store.bool(Key.isWindowsTarget, default: true) }
        set { store.set(newValue, forKey: Key.isWindowsTarget) }
    }

    /// 배경도 이미지도 없는 빈 버튼을 수집에서 제외할지 여부
    static var isEmptyButtonHidden: Bool {
        get { store.bool(Key.isEmptyButtonHidden, default: false) }
        set { store.set(newValue, forKey: Key.isEmptyButtonHidden) }
    }

    /// `UIButton` 내부 서브뷰까지 수집할지 여부
    static var isUIButtonSubViewCheck: Bool {
        get { store.bool(Key.isUIButtonSubViewCheck, default: false) }
        set { store.set(newValue, forKey: Key.isUIButtonSubViewCheck) }
    }

    /// `UITextField` 내부 서브뷰까지 수집할지 여부
    static var isUITextFieldSubViewCheck: Bool {
        get { store.bool(Key.isUITextFieldSubViewCheck, default: false) }
        set { store.set(newValue, forKey: Key.isUITextFieldSubViewCheck) }
    }

    // MARK: - SwiftUI 전용

    /// 텍스트/이미지처럼 `contents`로만 그려지는 레이어를 수집할지 여부
    static var includesContentLayers: Bool {
        get { store.bool(Key.includesContentLayers, default: true) }
        set { store.set(newValue, forKey: Key.includesContentLayers) }
    }

    // MARK: - 저장소

    private static var store: UserDefaults { .standard }

    private enum Key {
        static let isShowSize = "isShowSize"
        static let spacingLimit = "spacingLimit"
        static let isHidesOccludedViews = "isHidesOccludedViews"
        static let occlusionSampleInset = "occlusionSampleInset"
        static let occlusionCoverageThreshold = "occlusionCoverageThreshold"
        static let occlusionMaxSamplesPerAxis = "occlusionMaxSamplesPerAxis"
        static let isWindowsTarget = "isWindowsTarget"
        static let isEmptyButtonHidden = "isEmptyButtonHidden"
        static let isUIButtonSubViewCheck = "isUIButtonSubViewCheck"
        static let isUITextFieldSubViewCheck = "isUITextFieldSubViewCheck"
        static let includesContentLayers = "includesContentLayers"
    }
}

private extension UserDefaults {
    func bool(_ key: String, default defaultValue: Bool) -> Bool {
        value(forKey: key) as? Bool ?? defaultValue
    }

    func cgFloat(_ key: String, default defaultValue: CGFloat) -> CGFloat {
        value(forKey: key) as? CGFloat ?? defaultValue
    }

    func double(_ key: String, default defaultValue: Double) -> Double {
        value(forKey: key) as? Double ?? defaultValue
    }

    func int(_ key: String, default defaultValue: Int) -> Int {
        value(forKey: key) as? Int ?? defaultValue
    }
}
