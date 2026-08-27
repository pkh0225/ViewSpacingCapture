//
//  ViewSpacingSettingsView.swift
//
//  Created by 박길호(팀원) - 서비스개발담당App개발팀 on 7/20/26.
//  Copyright © 2025 emart. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - 표시/해제를 담당하는 호스트 뷰

@MainActor
final class ViewSpacingSettingsView: UIView {
    private static let dimViewTag = 2_835_769_824
    private static let panelViewTag = 2_835_769_825

    private var onDismiss: (() -> Void)?
    private let model = ViewSpacingSettingsModel()
    private var hostingController: UIHostingController<ViewSpacingSettingsScreen>?

    /// 호스트 뷰 위에 설정 패널을 표시합니다.
    static func present(on hostView: UIView, onDismiss: (() -> Void)? = nil) {
        dismiss(from: hostView)

        let dimButton = UIButton(type: .custom)
        dimButton.tag = dimViewTag
        dimButton.translatesAutoresizingMaskIntoConstraints = false
        dimButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        hostView.addSubview(dimButton)

        let settingsView = ViewSpacingSettingsView()
        settingsView.tag = panelViewTag
        settingsView.onDismiss = onDismiss
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(settingsView)

        dimButton.addAction(UIAction { _ in
            dismiss(from: hostView)
        }, for: .touchUpInside)

        NSLayoutConstraint.activate([
            dimButton.topAnchor.constraint(equalTo: hostView.topAnchor),
            dimButton.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),
            dimButton.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            dimButton.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),

            settingsView.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
            settingsView.centerYAnchor.constraint(equalTo: hostView.centerYAnchor),
            settingsView.widthAnchor.constraint(equalTo: hostView.widthAnchor, multiplier: 0.88),
            settingsView.heightAnchor.constraint(equalTo: hostView.heightAnchor, multiplier: 0.78)
        ])
    }

    static func dismiss(from hostView: UIView) {
        let panel = hostView.viewWithTag(panelViewTag) as? ViewSpacingSettingsView
        let callback = panel?.onDismiss
        panel?.onDismiss = nil

        hostView.viewWithTag(dimViewTag)?.removeFromSuperview()
        panel?.removeFromSuperview()
        callback?()
    }

    deinit {
        print("ViewSpacingSettingsView deinit")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHosting()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupHosting()
    }

    private func setupHosting() {
        backgroundColor = .clear

        let screen = ViewSpacingSettingsScreen(model: model) { [weak self] in
            self?.close()
        }
        let host = UIHostingController(rootView: screen)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController = host
        addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func close() {
        guard let hostView = superview else {
            removeFromSuperview()
            return
        }
        Self.dismiss(from: hostView)
    }
}

// MARK: - 설정 값 바인딩

@MainActor
final class ViewSpacingSettingsModel: ObservableObject {
    @Published var isShowSize: Bool {
        didSet { ViewSpacingCaptureSettings.isShowSize = isShowSize }
    }

    @Published var isHidesOccludedViews: Bool {
        didSet { ViewSpacingCaptureSettings.isHidesOccludedViews = isHidesOccludedViews }
    }

    @Published var isWindowsTarget: Bool {
        didSet { ViewSpacingCaptureSettings.isWindowsTarget = isWindowsTarget }
    }

    @Published var isEmptyButtonHidden: Bool {
        didSet { ViewSpacingCaptureSettings.isEmptyButtonHidden = isEmptyButtonHidden }
    }

    @Published var isUIButtonSubViewCheck: Bool {
        didSet { ViewSpacingCaptureSettings.isUIButtonSubViewCheck = isUIButtonSubViewCheck }
    }

    @Published var isUITextFieldSubViewCheck: Bool {
        didSet { ViewSpacingCaptureSettings.isUITextFieldSubViewCheck = isUITextFieldSubViewCheck }
    }

    @Published var includesContentLayers: Bool {
        didSet { ViewSpacingCaptureSettings.includesContentLayers = includesContentLayers }
    }

    @Published var isSpacingMarkerEnabled: Bool {
        didSet { ViewSpacingCaptureSettings.isSpacingMarkerEnabled = isSpacingMarkerEnabled }
    }

    @Published var spacingLimitText: String
    @Published var occlusionSampleInsetText: String
    @Published var occlusionCoveragePercentText: String
    @Published var occlusionMaxSamplesText: String

    /// 키보드에 가려지지 않도록 스크롤 하단에 확보할 여백
    @Published var keyboardHeight: CGFloat = 0

    private var keyboardObservers: [NSObjectProtocol] = []

    init() {
        isShowSize = ViewSpacingCaptureSettings.isShowSize
        isHidesOccludedViews = ViewSpacingCaptureSettings.isHidesOccludedViews
        isWindowsTarget = ViewSpacingCaptureSettings.isWindowsTarget
        isEmptyButtonHidden = ViewSpacingCaptureSettings.isEmptyButtonHidden
        isUIButtonSubViewCheck = ViewSpacingCaptureSettings.isUIButtonSubViewCheck
        isUITextFieldSubViewCheck = ViewSpacingCaptureSettings.isUITextFieldSubViewCheck
        includesContentLayers = ViewSpacingCaptureSettings.includesContentLayers
        isSpacingMarkerEnabled = ViewSpacingCaptureSettings.isSpacingMarkerEnabled

        spacingLimitText = "\(Int(ViewSpacingCaptureSettings.spacingLimit))"
        occlusionSampleInsetText = Self.formatNumber(ViewSpacingCaptureSettings.occlusionSampleInset)
        occlusionCoveragePercentText = "\(Int(round(ViewSpacingCaptureSettings.occlusionCoverageThreshold * 100)))"
        occlusionMaxSamplesText = "\(ViewSpacingCaptureSettings.occlusionMaxSamplesPerAxis)"

        observeKeyboard()
    }

    deinit {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func commitSpacingLimit() {
        ViewSpacingCaptureSettings.spacingLimit = CGFloat(Double(trimmed(spacingLimitText)) ?? 0)
        spacingLimitText = "\(Int(ViewSpacingCaptureSettings.spacingLimit))"
    }

    func commitOcclusionSampleInset() {
        ViewSpacingCaptureSettings.occlusionSampleInset = CGFloat(Double(trimmed(occlusionSampleInsetText)) ?? 0)
        occlusionSampleInsetText = Self.formatNumber(ViewSpacingCaptureSettings.occlusionSampleInset)
    }

    func commitOcclusionCoveragePercent() {
        let percent = Double(trimmed(occlusionCoveragePercentText)) ?? 0
        ViewSpacingCaptureSettings.occlusionCoverageThreshold = percent / 100
        occlusionCoveragePercentText = "\(Int(round(ViewSpacingCaptureSettings.occlusionCoverageThreshold * 100)))"
    }

    func commitOcclusionMaxSamples() {
        ViewSpacingCaptureSettings.occlusionMaxSamplesPerAxis = Int(trimmed(occlusionMaxSamplesText)) ?? 2
        occlusionMaxSamplesText = "\(ViewSpacingCaptureSettings.occlusionMaxSamplesPerAxis)"
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func observeKeyboard() {
        let center = NotificationCenter.default
        let willShow = center.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            Task { @MainActor in
                self?.keyboardHeight = keyboardFrame?.height ?? 0
            }
        }
        let willHide = center.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.keyboardHeight = 0
            }
        }
        keyboardObservers = [willShow, willHide]
    }

    private static func formatNumber(_ value: CGFloat) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - SwiftUI 화면

struct ViewSpacingSettingsScreen: View {
    @ObservedObject var model: ViewSpacingSettingsModel
    var onClose: () -> Void

    @State private var isEditingField = false

    private let legendItems: [(String, Color)] = [
        ("UILabel", Color(red: 0, green: 200 / 255, blue: 0)),
        ("UIImageView / WKWebView", .red),
        ("UIButton", .blue),
        ("Cell", .purple),
        ("UITextField", Color(UIColor.darkGray)),
        ("UIView", Color(red: 1, green: 229 / 255, blue: 0)),
        ("Inset", .red),
        ("Gap", Color(UIColor.magenta))
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    legendSection
                    displaySection
                    occlusionSection
                    collectSection
                    swiftUISection
                }
                .padding(16)
                .padding(.bottom, model.keyboardHeight)
            }
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UI Checker 설정")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("캡처 표시 · 가림 판정 옵션")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                if isEditingField {
                    Button("닫기") {
                        endEditing()
                    }
                    .font(.system(size: 14, weight: .semibold))
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider()
        }
        .background(Color.white)
    }

    private var legendSection: some View {
        section("컬러 가이드") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(legendItems, id: \.0) { item in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.1)
                            .frame(width: 12, height: 12)

                        Text(item.0)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
    }

    private var displaySection: some View {
        section("표시") {
            VStack(spacing: 0) {
                fieldRow(
                    title: "라인 표시 제한",
                    subtitle: "Pixel",
                    text: $model.spacingLimitText,
                    keyboard: .numberPad,
                    onCommit: model.commitSpacingLimit
                )
                separator
                switchRow("사이즈 표시", isOn: $model.isShowSize)
            }
        }
    }

    private var occlusionSection: some View {
        section("가려진 뷰") {
            VStack(spacing: 0) {
                switchRow("가려진뷰 숨기기", isOn: $model.isHidesOccludedViews)

                VStack(spacing: 0) {
                    separator
                    fieldRow(
                        title: "Sample Inset",
                        subtitle: "가장자리 오차 흡수 (pt)",
                        text: $model.occlusionSampleInsetText,
                        keyboard: .decimalPad,
                        onCommit: model.commitOcclusionSampleInset
                    )
                    separator
                    fieldRow(
                        title: "Coverage",
                        subtitle: "덮임 비율 (%)",
                        text: $model.occlusionCoveragePercentText,
                        keyboard: .numberPad,
                        onCommit: model.commitOcclusionCoveragePercent
                    )
                    separator
                    fieldRow(
                        title: "Max Samples / Axis",
                        subtitle: "축당 최대 샘플 수",
                        text: $model.occlusionMaxSamplesText,
                        keyboard: .numberPad,
                        onCommit: model.commitOcclusionMaxSamples
                    )
                }
                .opacity(model.isHidesOccludedViews ? 1 : 0.4)
                .disabled(!model.isHidesOccludedViews)
            }
        }
    }

    private var collectSection: some View {
        section("수집") {
            VStack(spacing: 0) {
                switchRow("Window 캡쳐", isOn: $model.isWindowsTarget)
                separator
                switchRow("투명버튼 무시하기", isOn: $model.isEmptyButtonHidden)
                separator
                switchRow("UIButton 내부 포함하기", isOn: $model.isUIButtonSubViewCheck)
                separator
                switchRow("UITextField 내부 포함하기", isOn: $model.isUITextFieldSubViewCheck)
            }
        }
    }

    private var swiftUISection: some View {
        section("SwiftUI 전용") {
            VStack(spacing: 0) {
                switchRow("텍스트/이미지 포함하기", isOn: $model.includesContentLayers)
//                separator
//                switchRow("레이아웃 컨테이너 표시", isOn: $model.isSpacingMarkerEnabled)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            content()
                .padding(.vertical, 4)
                .padding(.horizontal, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color(UIColor.separator).opacity(0.35))
            .frame(height: 1 / UIScreen.main.scale)
    }

    private func switchRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
        .padding(.vertical, 10)
    }

    private func fieldRow(
        title: String,
        subtitle: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        onCommit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            TextField("", text: text) { isEditing in
                isEditingField = isEditing
                if !isEditing {
                    onCommit()
                }
            }
            .keyboardType(keyboard)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .padding(.horizontal, 10)
            .frame(width: 72, height: 34)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
        .padding(.vertical, 10)
    }

    /// `numberPad`에는 완료 키가 없어 헤더의 닫기 버튼으로 포커스를 내려줍니다.
    private func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Preview

struct ViewSpacingSettingsScreen_Previews: PreviewProvider {
    static var previews: some View {
        ViewSpacingSettingsScreen(model: ViewSpacingSettingsModel(), onClose: {})
            .frame(width: 340, height: 620)
            .padding(24)
            .background(Color.black.opacity(0.45))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Settings")
    }
}
