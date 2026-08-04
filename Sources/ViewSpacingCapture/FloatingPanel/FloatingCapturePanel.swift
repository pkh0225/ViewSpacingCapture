//
//  FloatingCapturePanel.swift
//  ViewSpacingCapture
//
//  Created by 박길호(팀원) - D/I개발담당App개발팀 on 7/20/26.
//

import UIKit

@MainActor
final class FloatingCapturePanel: UIView {

    var onRemove: (() -> Void)?

    private enum Layout {
        static let panelWidth: CGFloat = 165
        static let headerHeight: CGFloat = 44
        static let separatorHeight: CGFloat = 1
        static let rowHeight: CGFloat = 48
        static let horizontalPadding: CGFloat = 12
        static let chevronSize: CGFloat = 16
    }

    private var isExpanded = false
    private var menuRows: [UIView] = []
    /// 이 행 위에 구분선을 그립니다.
    private weak var swiftUIRow: UIView?

    let collapsedSize = CGSize(width: Layout.panelWidth, height: Layout.headerHeight)

    var expandedHeight: CGFloat {
        Layout.headerHeight
            + Layout.separatorHeight * CGFloat(separatorViews.count)
            + Layout.rowHeight * CGFloat(menuRows.count)
    }

    private var separatorViews: [UIView] {
        [separatorView, swiftUISeparatorView]
    }

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.15
        view.layer.shadowRadius = 8
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "UI Checker"
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = .black
        return label
    }()

    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .black
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let headerButton: UIButton = {
        let button = UIButton(type: .custom)
        return button
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.9, alpha: 1)
        view.isHidden = true
        return view
    }()

    /// UIKit 캡처 행과 SwiftUI 캡처 행을 구분합니다.
    private let swiftUISeparatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.9, alpha: 1)
        view.isHidden = true
        return view
    }()

    private let settingButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        button.setImage(UIImage(systemName: "gearshape.fill", withConfiguration: config), for: .normal)
        button.tintColor = UIColor(named: "gray900") ?? .darkGray
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        updateChevron()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        updateChevron()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutContent()
    }

    private func setupUI() {
        addSubview(cardView)
        cardView.addSubview(headerButton)
        cardView.addSubview(titleLabel)
        cardView.addSubview(chevronImageView)
        cardView.addSubview(separatorView)
        cardView.addSubview(swiftUISeparatorView)
        cardView.addSubview(settingButton)

        titleLabel.isUserInteractionEnabled = false
        chevronImageView.isUserInteractionEnabled = false

        ViewSpacingCaptureManager.Option.allCases.forEach { type in
            let row = makeMenuRow(for: type)
            menuRows.append(row)
            cardView.addSubview(row)
            row.isHidden = true
        }

        // SwiftUI 화면용: 뷰 등록 없이 CALayer 트리에서 자동 수집합니다.
        let row = makeMenuRow(title: "swiftUI", tag: 0, action: #selector(swiftUICaptureButtonTapped))
        menuRows.append(row)
        cardView.addSubview(row)
        row.isHidden = true
        swiftUIRow = row

        headerButton.addTarget(self, action: #selector(headerTapped), for: .touchUpInside)
        settingButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        addLongPressGesture(to: headerButton)
    }

    private func layoutContent() {
        let width = bounds.width

        cardView.frame = bounds
        headerButton.frame = CGRect(x: 0, y: 0, width: width, height: Layout.headerHeight)

        chevronImageView.frame = CGRect(
            x: width - Layout.horizontalPadding - Layout.chevronSize,
            y: (Layout.headerHeight - Layout.chevronSize) / 2,
            width: Layout.chevronSize,
            height: Layout.chevronSize
        )

        settingButton.frame.size = CGSizeMake(28, 28)
        settingButton.frame.origin = CGPoint(
            x: 8,
            y: (Layout.headerHeight - settingButton.bounds.height) / 2
        )

        titleLabel.sizeToFit()
        titleLabel.frame.origin = CGPoint(
            x: settingButton.frame.maxX + 4,
            y: (Layout.headerHeight - titleLabel.bounds.height) / 2
        )

        separatorView.frame = CGRect(
            x: 0,
            y: Layout.headerHeight,
            width: width,
            height: Layout.separatorHeight
        )

        var rowY = Layout.headerHeight + Layout.separatorHeight
        for row in menuRows {
            if row === swiftUIRow {
                swiftUISeparatorView.frame = CGRect(
                    x: 0,
                    y: rowY,
                    width: width,
                    height: Layout.separatorHeight
                )
                rowY += Layout.separatorHeight
            }
            row.frame = CGRect(x: 0, y: rowY, width: width, height: Layout.rowHeight)
            layoutMenuRow(row)
            rowY += Layout.rowHeight
        }
    }

    private func layoutMenuRow(_ rowView: UIView) {
        guard let label = rowView.viewWithTag(1) as? UILabel,
              let captureButton = rowView.subviews.compactMap({ $0 as? UIButton }).first else { return }

        let buttonSize = captureButton.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: Layout.rowHeight)
        )
        let buttonWidth = max(buttonSize.width, 52)
        let buttonHeight = max(buttonSize.height, 32)

        captureButton.frame = CGRect(
            x: rowView.bounds.width - Layout.horizontalPadding - buttonWidth,
            y: (rowView.bounds.height - buttonHeight) / 2,
            width: buttonWidth,
            height: buttonHeight
        )

        label.sizeToFit()
        label.frame.origin = CGPoint(
            x: Layout.horizontalPadding,
            y: (rowView.bounds.height - label.bounds.height) / 2
        )
    }

    private func addLongPressGesture(to view: UIView) {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture(_:)))
        view.addGestureRecognizer(gesture)
    }

    private func makeMenuRow(for type: ViewSpacingCaptureManager.Option) -> UIView {
        makeMenuRow(
            title: type.rawValue,
            tag: ViewSpacingCaptureManager.Option.allCases.firstIndex(of: type) ?? 0,
            action: #selector(captureButtonTapped(_:))
        )
    }

    private func makeMenuRow(title: String, tag: Int, action: Selector) -> UIView {
        let rowView = UIView()

        let label = UILabel()
        label.tag = 1
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .black

        let captureButton = UIButton(type: .system)
        captureButton.setTitle("캡쳐", for: .normal)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        captureButton.backgroundColor = UIColor(white: 0.15, alpha: 1)
        captureButton.layer.cornerRadius = 8
        captureButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        captureButton.addTarget(self, action: action, for: .touchUpInside)
        captureButton.tag = tag

        rowView.addSubview(label)
        rowView.addSubview(captureButton)

        return rowView
    }

    private func captureViewControllerWithBounds(_ viewController: UIViewController, option: ViewSpacingCaptureManager.Option) {
        let wasButtonHidden = FloatingCaptureButton.shared.isShow

        FloatingCaptureButton.shared.hideFloatingButton()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            let viewSpacingCapture = ViewSpacingCaptureManager()
            viewSpacingCapture.option = option
            viewSpacingCapture.captureViewControllerWithBounds(viewController) { success in
                if wasButtonHidden {
                    FloatingCaptureButton.shared.showFloatingButton()
                }

                if success {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            }
        }
    }

    @objc private func headerTapped() {
        setExpanded(!isExpanded)
    }

    @objc private func captureButtonTapped(_ sender: UIButton) {
        guard sender.tag < ViewSpacingCaptureManager.Option.allCases.count else { return }
        let type = ViewSpacingCaptureManager.Option.allCases[sender.tag]
        guard let currentViewController = getCurrentViewController() else { return }
        let topViewController = currentViewController.navigationController?.topViewController ?? currentViewController
        captureViewControllerWithBounds(topViewController, option: type)
    }

    /// 플로팅 버튼 숨김/복원은 `SwiftUISpacingCapture`가 처리합니다.
    @objc private func swiftUICaptureButtonTapped() {
        guard let currentViewController = getCurrentViewController() else { return }
        let topViewController = currentViewController.navigationController?.topViewController ?? currentViewController
        SwiftUISpacingCapture.capture(from: topViewController)
    }

    private func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        separatorViews.forEach { $0.isHidden = !expanded }
        menuRows.forEach { $0.isHidden = !expanded }
        updateChevron()

        var frame = self.frame
        frame.size.height = expanded ? expandedHeight : collapsedSize.height
        self.frame = frame
        layoutContent()
    }

    @objc private func settingsTapped() {
        guard let hostView = window else { return }
        isHidden = true
        ViewSpacingSettingsView.present(on: hostView) { [weak self] in
            self?.isHidden = false
        }
    }

    private func updateChevron() {
        let symbolName = isExpanded ? "chevron.up" : "chevron.down"
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        chevronImageView.image = UIImage(systemName: symbolName, withConfiguration: config)
    }

    @objc private func handleLongPressGesture(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard let currentVC = getCurrentViewController() else { return }

        let alertController = UIAlertController(
            title: "알림",
            message: "OFF 하시겠습니까?",
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.onRemove?()
        })
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))

        currentVC.present(alertController, animated: true)
    }

    private func getCurrentViewController() -> UIViewController? {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return nil
        }

        return findTopViewController(from: rootVC)
    }

    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presentedVC = viewController.presentedViewController {
            return findTopViewController(from: presentedVC)
        }

        if let navigationVC = viewController as? UINavigationController {
            return navigationVC.topViewController ?? navigationVC
        }

        if let tabBarVC = viewController as? UITabBarController {
            return findTopViewController(from: tabBarVC.selectedViewController ?? tabBarVC)
        }

        return viewController
    }

}
