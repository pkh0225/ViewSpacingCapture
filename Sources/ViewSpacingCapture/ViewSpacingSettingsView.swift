//
//  ViewSpacingSettingsView.swift
//
//  Created by 박길호(팀원) - 서비스개발담당App개발팀 on 7/20/26.
//  Copyright © 2025 emart. All rights reserved.
//

import UIKit

final class ViewSpacingSettingsView: UIView {
    private static let dimViewTag = 2_835_769_824
    private static let panelViewTag = 2_835_769_825

    private var onDismiss: (() -> Void)?

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

    private enum SwitchTag: Int {
        case showSize = 0
        case hidesOccludedViews = 1
        case windowsTarget = 2
        case emptyButtonHidden = 3
        case allowComponent = 4
        case uiButtonSubView = 5
        case uiTextFieldSubView = 6
    }

    private enum FieldTag: Int {
        case spacingLimit = 0
        case occlusionSampleInset = 1
        case occlusionCoveragePercent = 2
        case occlusionMaxSamples = 3
    }

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private weak var occlusionDetailStack: UIStackView?

//    deinit {
//        print("ViewSpacingSettingsView deinit")
//    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }

    private func setupLayout() {
        backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
        layer.cornerRadius = 18
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor.black.withAlphaComponent(0.06).cgColor

        let header = makeHeader()
        addSubview(header)
        addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        contentStack.addArrangedSubview(makeLegendCard())
        contentStack.addArrangedSubview(makeDisplaySection())
        contentStack.addArrangedSubview(makeOcclusionSection())
        contentStack.addArrangedSubview(makeCollectSection())

        updateOcclusionDetailEnabled(ViewSpacingCaptureManager.isHidesOccludedViews)
    }

    private func makeHeader() -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "UI Checker 설정"
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.textColor = .label
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "캡처 표시 · 가림 판정 옵션"
        subtitle.font = .systemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = .secondaryLabel
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = UIButton(type: .system)
        let closeConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: closeConfig), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.backgroundColor = UIColor.secondarySystemBackground
        closeButton.layer.cornerRadius = 14
        closeButton.clipsToBounds = true
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(onCloseButton), for: .touchUpInside)

        let divider = UIView()
        divider.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        divider.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(title)
        container.addSubview(subtitle)
        container.addSubview(closeButton)
        container.addSubview(divider)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

            divider.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 14),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
        return container
    }

    @objc private func onCloseButton() {
        guard let hostView = superview else {
            removeFromSuperview()
            return
        }
        ViewSpacingSettingsView.dismiss(from: hostView)
    }

    private func makeLegendCard() -> UIView {
        let items: [(String, UIColor)] = [
            ("UILabel", UIColor(red: 0, green: 200 / 255, blue: 0, alpha: 1)),
            ("UIImageView / WKWebView", .red),
            ("UIButton", .blue),
            ("Cell", .purple),
            ("UITextField", .darkGray),
            ("UIView", UIColor(red: 1, green: 229 / 255, blue: 0, alpha: 1)),
            ("Inset", .red),
            ("Gap", .magenta)
        ]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        let title = makeSectionTitle("컬러 가이드")
        stack.addArrangedSubview(title)

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 6

        for item in items {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.alignment = .center

            let swatch = UIView()
            swatch.backgroundColor = item.1
            swatch.layer.cornerRadius = 3
            swatch.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                swatch.widthAnchor.constraint(equalToConstant: 12),
                swatch.heightAnchor.constraint(equalToConstant: 12)
            ])

            let label = UILabel()
            label.text = item.0
            label.font = .systemFont(ofSize: 12, weight: .regular)
            label.textColor = .secondaryLabel

            row.addArrangedSubview(swatch)
            row.addArrangedSubview(label)
            grid.addArrangedSubview(row)
        }

        stack.addArrangedSubview(wrapInCard(grid))
        return stack
    }

    private func makeDisplaySection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.addArrangedSubview(makeSectionTitle("표시"))

        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 0
        cardStack.addArrangedSubview(makeFieldRow(
            title: "라인 표시 제한",
            subtitle: "Pixel",
            value: "\(Int(ViewSpacingCaptureManager.spacingLimit))",
            tag: FieldTag.spacingLimit.rawValue,
            keyboard: .numberPad
        ))
        cardStack.addArrangedSubview(makeSeparator())
        cardStack.addArrangedSubview(makeSwitchRow(title: "사이즈 표시", tag: .showSize))
        stack.addArrangedSubview(wrapInCard(cardStack))
        return stack
    }

    private func makeOcclusionSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.addArrangedSubview(makeSectionTitle("가려진 뷰"))

        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 0
        cardStack.addArrangedSubview(makeSwitchRow(title: "가려진뷰 숨기기", tag: .hidesOccludedViews))

        let detailStack = UIStackView()
        detailStack.axis = .vertical
        detailStack.spacing = 0
        detailStack.addArrangedSubview(makeSeparator())
        detailStack.addArrangedSubview(makeFieldRow(
            title: "Sample Inset",
            subtitle: "가장자리 오차 흡수 (pt)",
            value: formatNumber(ViewSpacingCaptureManager.occlusionSampleInset),
            tag: FieldTag.occlusionSampleInset.rawValue,
            keyboard: .decimalPad
        ))
        detailStack.addArrangedSubview(makeSeparator())
        detailStack.addArrangedSubview(makeFieldRow(
            title: "Coverage",
            subtitle: "덮임 비율 (%)",
            value: "\(Int(round(ViewSpacingCaptureManager.occlusionCoverageThreshold * 100)))",
            tag: FieldTag.occlusionCoveragePercent.rawValue,
            keyboard: .numberPad
        ))
        detailStack.addArrangedSubview(makeSeparator())
        detailStack.addArrangedSubview(makeFieldRow(
            title: "Max Samples / Axis",
            subtitle: "축당 최대 샘플 수",
            value: "\(ViewSpacingCaptureManager.occlusionMaxSamplesPerAxis)",
            tag: FieldTag.occlusionMaxSamples.rawValue,
            keyboard: .numberPad
        ))
        cardStack.addArrangedSubview(detailStack)
        occlusionDetailStack = detailStack

        stack.addArrangedSubview(wrapInCard(cardStack))
        return stack
    }

    private func makeCollectSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.addArrangedSubview(makeSectionTitle("수집"))

        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 0
        cardStack.addArrangedSubview(makeSwitchRow(title: "Window 캡쳐", tag: .windowsTarget))
        cardStack.addArrangedSubview(makeSeparator())
        cardStack.addArrangedSubview(makeSwitchRow(title: "투명버튼 무시하기", tag: .emptyButtonHidden))
        cardStack.addArrangedSubview(makeSeparator())
        cardStack.addArrangedSubview(makeSwitchRow(title: "컴포넌트 포함하기", tag: .allowComponent))
        cardStack.addArrangedSubview(makeSeparator())
        cardStack.addArrangedSubview(makeSwitchRow(title: "UIButton 내부 포함하기", tag: .uiButtonSubView))
        cardStack.addArrangedSubview(makeSeparator())
        cardStack.addArrangedSubview(makeSwitchRow(title: "UITextField 내부 포함하기", tag: .uiTextFieldSubView))
        stack.addArrangedSubview(wrapInCard(cardStack))
        return stack
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabel
        return label
    }

    private func wrapInCard(_ content: UIView) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 12
        card.layer.masksToBounds = true

        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4)
        ])
        return card
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = UIColor.separator.withAlphaComponent(0.35)
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        return line
    }

    private func makeSwitchRow(title: String, tag: SwitchTag) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let switchButton = UISwitch()
        switchButton.tag = tag.rawValue
        switchButton.onTintColor = UIColor.systemBlue
        switch tag {
        case .showSize: switchButton.isOn = ViewSpacingCaptureManager.isShowSize
        case .hidesOccludedViews: switchButton.isOn = ViewSpacingCaptureManager.isHidesOccludedViews
        case .windowsTarget: switchButton.isOn = ViewSpacingCaptureManager.isWindowsTarget
        case .emptyButtonHidden: switchButton.isOn = ViewSpacingCaptureManager.isEmptyButtonHidden
        case .allowComponent: switchButton.isOn = ViewSpacingCaptureManager.isAllowCompont
        case .uiButtonSubView: switchButton.isOn = ViewSpacingCaptureManager.isUIButtonSubViewCheck
        case .uiTextFieldSubView: switchButton.isOn = ViewSpacingCaptureManager.isUITextFieldSubViewCheck
        }
        switchButton.addTarget(self, action: #selector(switchDidChangeValue(_:)), for: .valueChanged)

        row.addArrangedSubview(label)
        row.addArrangedSubview(switchButton)
        return row
    }

    private func makeFieldRow(
        title: String,
        subtitle: String,
        value: String,
        tag: Int,
        keyboard: UIKeyboardType
    ) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let textField = UITextField()
        textField.tag = tag
        textField.text = value
        textField.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        textField.textAlignment = .right
        textField.keyboardType = keyboard
        textField.borderStyle = .none
        textField.backgroundColor = UIColor.secondarySystemBackground
        textField.layer.cornerRadius = 8
        textField.clipsToBounds = true
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        textField.rightViewMode = .always
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 72).isActive = true
        textField.heightAnchor.constraint(equalToConstant: 34).isActive = true
        textField.addTarget(self, action: #selector(textFieldEditingDidEnd(_:)), for: .editingDidEnd)
        textField.addTarget(self, action: #selector(textFieldEditingDidEnd(_:)), for: .editingDidEndOnExit)

        row.addArrangedSubview(textStack)
        row.addArrangedSubview(textField)
        return row
    }

    private func updateOcclusionDetailEnabled(_ enabled: Bool) {
        occlusionDetailStack?.alpha = enabled ? 1 : 0.4
        occlusionDetailStack?.isUserInteractionEnabled = enabled
    }

    private func formatNumber(_ value: CGFloat) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    @objc private func switchDidChangeValue(_ sender: UISwitch) {
        guard let tag = SwitchTag(rawValue: sender.tag) else { return }
        switch tag {
        case .showSize:
            ViewSpacingCaptureManager.isShowSize = sender.isOn
        case .hidesOccludedViews:
            ViewSpacingCaptureManager.isHidesOccludedViews = sender.isOn
            updateOcclusionDetailEnabled(sender.isOn)
        case .windowsTarget:
            ViewSpacingCaptureManager.isWindowsTarget = sender.isOn
        case .emptyButtonHidden:
            ViewSpacingCaptureManager.isEmptyButtonHidden = sender.isOn
        case .allowComponent:
            ViewSpacingCaptureManager.isAllowCompont = sender.isOn
        case .uiButtonSubView:
            ViewSpacingCaptureManager.isUIButtonSubViewCheck = sender.isOn
        case .uiTextFieldSubView:
            ViewSpacingCaptureManager.isUITextFieldSubViewCheck = sender.isOn
        }
    }

    @objc private func textFieldEditingDidEnd(_ sender: UITextField) {
        guard let tag = FieldTag(rawValue: sender.tag) else { return }
        let text = sender.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch tag {
        case .spacingLimit:
            ViewSpacingCaptureManager.spacingLimit = CGFloat(Double(text) ?? 0)
            sender.text = "\(Int(ViewSpacingCaptureManager.spacingLimit))"
        case .occlusionSampleInset:
            ViewSpacingCaptureManager.occlusionSampleInset = CGFloat(Double(text) ?? 0)
            sender.text = formatNumber(ViewSpacingCaptureManager.occlusionSampleInset)
        case .occlusionCoveragePercent:
            let percent = Double(text) ?? 0
            ViewSpacingCaptureManager.occlusionCoverageThreshold = percent / 100
            sender.text = "\(Int(round(ViewSpacingCaptureManager.occlusionCoverageThreshold * 100)))"
        case .occlusionMaxSamples:
            ViewSpacingCaptureManager.occlusionMaxSamplesPerAxis = Int(text) ?? 2
            sender.text = "\(ViewSpacingCaptureManager.occlusionMaxSamplesPerAxis)"
        }
    }
}
