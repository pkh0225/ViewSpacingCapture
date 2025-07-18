//
//  ViewSpacingCaptureManager.swift
//  ViewSpacingCapture
//
//  Created by 박길호 on 7/18/25.
//

import UIKit
import WebKit

// MARK: - 뷰 간격 캡처 관리자
public class ViewSpacingCaptureManager {
    static let exception: Int = 2835769823
    static var isShowSize: Bool {
        get {
            if let show = UserDefaults.standard.value(forKey: "ViewSpacingCaptureManager.isShowSize") as? Bool {
                return show
            }
            return true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ViewSpacingCaptureManager.isShowSize")
        }
    }
    static var spacingLimit: CGFloat {
        get {
            if let limit = UserDefaults.standard.value(forKey: "ViewSpacingCaptureManager.spacingLimit") as? CGFloat {
                return limit
            }
            return 200
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ViewSpacingCaptureManager.spacingLimit")
        }
    }
    static var isHidesOccludedViews: Bool {
        get {
            if let show = UserDefaults.standard.value(forKey: "ViewSpacingCaptureManager.hidesOccludedViews") as? Bool {
                return show
            }
            return false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ViewSpacingCaptureManager.hidesOccludedViews")
        }
    }

    public init() {}

    public func captureViewControllerWithBounds(_ viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        let targetView = viewController.view!

        // 뷰 캡처
        guard let screenshot = captureView(targetView) else {
            completion(false)
            return
        }

        // 뷰 경계와 측정값을 그린 이미지 생성
        let imageWithBounds = drawViewBoundsWithMeasurements(on: screenshot, rootView: targetView)

        // 결과 이미지를 바로 미리보기로 표시
        showImagePreview(imageWithBounds, from: viewController)
        completion(true)
    }

    // MARK: - 뷰 캡처 메서드
    private func captureView(_ view: UIView) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
        return renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }

    // MARK: - 뷰 경계와 측정값 그리기 메서드
    private func drawViewBoundsWithMeasurements(on image: UIImage, rootView: UIView) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)

        return renderer.image { context in
            // 원본 이미지 그리기
            image.draw(at: .zero)

            let cgContext = context.cgContext

            // 모든 뷰들의 정보 수집
            let viewInfos = collectViewInfos(rootView: rootView)

            // 뷰 타입별로 다른 색상으로 경계 및 크기 그리기
            drawViewBoundsByType(viewInfos: viewInfos, in: cgContext)

            // 인셋과 간격 측정 및 표시
            drawMeasurements(viewInfos: viewInfos, rootView: rootView, in: cgContext)
        }
    }

    // MARK: - 뷰 정보 수집 (보이는 뷰만)
    private func collectViewInfos(rootView: UIView) -> [ViewInfo] {
        var allViewInfos: [ViewInfo] = []
        // 1. 모든 뷰의 정보를 재귀적으로 수집합니다. (순서가 중요)
        collectAllViewInfosRecursively(view: rootView, rootView: rootView, viewInfos: &allViewInfos)

        if Self.isHidesOccludedViews {
            // 2. 가려진 뷰를 필터링합니다. (좀 더 보완해서 추가할지 결정)
            let visibleViewInfos = allViewInfos.enumerated().compactMap { (index, viewInfo) -> ViewInfo? in
                // 자식뷰중에 하나라도 그대로 덮고 있는 뷰가 있으면 빼지 않는다.
                for subView in viewInfo.view.subviews {
                    if sameFrame(viewInfo.view.bounds, subView.frame) {
                        return viewInfo
                    }
                }
                // 현재 뷰가 다른 뷰들에 의해 완전히 가려졌는지 확인합니다.
                let isObscured = isViewCompletelyObscured(viewInfoToTest: viewInfo, in: allViewInfos, at: index)
                // 가려지지 않았을 때만 최종 리스트에 포함시킵니다.
                return isObscured ? nil : viewInfo
            }
            return visibleViewInfos
        }
        else {
            return allViewInfos
        }
    }

    private func collectAllViewInfosRecursively(view: UIView, rootView: UIView, viewInfos: inout [ViewInfo]) {
        // 히든 상태이거나 투명한 뷰는 수집하지 않습니다.
        if view.isHidden || view.alpha == 0 {
            return
        }
        // 뷰의 크기가 1x1 미만이면 무시합니다.
        if view.frame.width < 1 || view.frame.height < 1 {
            return
        }
        // 화면에서 벗어났는지 검사
        if !UIScreen.main.bounds.intersects(view.convert(view.bounds, to: nil)) {
            return
        }
        // 내용이 없는 라벨과 버튼은 수집하지 않습니다.
        if let label = view as? UILabel {
            if label.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                return
            }
            if label.attributedText == nil {
                return
            }
        }
        if let button = view as? UIButton, let superView = button.superview?.superview {
            if button.title(for: .normal)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true &&
                button.attributedTitle(for: .normal) == nil &&
                button.image(for: .normal) == nil &&
                button.backgroundImage(for: .normal) == nil {
                if let view = superView as? UITableViewCell, sameFrame(view.contentView.bounds, button.frame) {
                    return
                }
                if let view = superView as? UITableViewHeaderFooterView, sameFrame(view.bounds, button.frame) {
                    return
                }
                if let view = superView as? UICollectionReusableView, sameFrame(view.bounds, button.frame) {
                    return
                }
                if let view = superView as? UICollectionViewCell, sameFrame(view.contentView.bounds, button.frame) {
                    return
                }
            }
        }

        if view.tag != Self.exception {
            let frameInRootView = view.convert(view.bounds, to: rootView)
            let viewInfo = ViewInfo(view: view, frame: frameInRootView)
            viewInfos.append(viewInfo)
        }

        if !(view is UIButton) && !(view is UITextField) {
            for subview in view.subviews {
                collectAllViewInfosRecursively(view: subview, rootView: rootView, viewInfos: &viewInfos)
            }
        }
    }

    // MARK: - 뷰 타입별 색상으로 경계 및 크기 그리기
    private func drawViewBoundsByType(viewInfos: [ViewInfo], in context: CGContext) {
        for viewInfo in viewInfos {
            let view = viewInfo.view
            let frame = viewInfo.frame
            let viewColor = getColorForViewType(view).view

            // 1. 모든 뷰의 경계선 그리기
            context.saveGState()
            context.setLineWidth(0.5)
            context.setLineDash(phase: 0, lengths: [])
            context.setStrokeColor(viewColor.cgColor)
            context.stroke(frame)
            context.restoreGState()

            // 사이즈 표시 사용 여부
            guard Self.isShowSize else { continue }

            // 2. 특정 타입의 뷰이거나, 자식 뷰가 없는 UIView인 경우 크기 정보 표시
            let isIncludedFromSizeLabel = view is UILabel || view is UIImageView || view is UIButton || view is WKWebView || view is UITextField || view is UITextView || view is UISwitch || view is UISlider || view is UISegmentedControl || view is UIStepper || view is UIProgressView || view is UIActivityIndicatorView || view is UINavigationBar || view is UITabBar || view is UIToolbar || view is UIDatePicker || view is UIPickerView

            // 순수 UIView 타입이면서 자식 뷰가 없는 경우를 확인하는 조건 추가
            var isLeafUIView = (type(of: view) == UIView.self && view.subviews.isEmpty)

            if let superView = view.superview, isLeafUIView {
                if sameFrame(superView.bounds, view.frame) {
                    isLeafUIView = false
                }
                else {
                    for sv in superView.subviews {
                        if sv !== view && sameFrame(sv.frame, view.frame) {
                            isLeafUIView = false
                            break
                        }
                    }
                }
            }

            if isIncludedFromSizeLabel || isLeafUIView {
                context.saveGState()

                // 2.1. 크기 표시를 위한 X자 점선 그리기 (경계선 색상 사용)
                context.setStrokeColor(viewColor.withAlphaComponent(0.4).cgColor)
                context.setLineWidth(0.5)
                context.setLineDash(phase: 0, lengths: [1, 3]) // 점선으로 변경

                // 첫 번째 대각선 (좌상단 -> 우하단)
                context.move(to: CGPoint(x: frame.minX, y: frame.minY))
                context.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
                context.strokePath()

                // 두 번째 대각선 (좌하단 -> 우상단)
                context.move(to: CGPoint(x: frame.minX, y: frame.maxY))
                context.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
                context.strokePath()

                context.restoreGState()

                // 2.2. 크기 텍스트 그리기 (경계선 색상 사용)
                let textColor = getColorForViewType(view).text
                let sizeString = "\(Int(round(frame.width)))x\(Int(round(frame.height)))"
                let center = CGPoint(x: frame.midX, y: frame.midY)
                drawSizeLabel(text: sizeString, at: center, color: textColor, viewFrame: frame, in: context)
            }
        }
    }

    // MARK: - 계층적 측정값 그리기 (중복 및 겹침 방지 포함)
    private func drawMeasurements(viewInfos: [ViewInfo], rootView: UIView, in context: CGContext) {
//        context.setStrokeColor(UIColor.red.cgColor)
//        context.setLineWidth(0.5)
//        context.setLineDash(phase: 0, lengths: [4, 2]) // 점선

        var drawnVerticalSiblingPairs: Set<Set<ObjectIdentifier>> = []
        var drawnHorizontalSiblingPairs: Set<Set<ObjectIdentifier>> = []

        for currentViewInfo in viewInfos where currentViewInfo.view !== rootView {
            guard let parentInfo = findParentViewInfo(for: currentViewInfo, in: viewInfos) else { continue }

            let childFrame = currentViewInfo.frame
            let parentFrame = parentInfo.frame
            let siblings = viewInfos.filter { $0.view.superview === parentInfo.view && $0.view !== currentViewInfo.view && $0.view.frame != parentInfo.view.bounds }

            // 상단
            let potentialAbove = siblings.filter { $0.frame.maxY <= childFrame.minY && framesOverlapHorizontally(childFrame, $0.frame) }
            if let closestAbove = potentialAbove.max(by: { $0.frame.maxY < $1.frame.maxY }) {
                let pair: Set<ObjectIdentifier> = [ObjectIdentifier(currentViewInfo.view), ObjectIdentifier(closestAbove.view)]
                if !drawnVerticalSiblingPairs.contains(pair) {
                    drawSiblingSpacing(from: closestAbove.frame, to: childFrame, edge: .top, in: context)
                    drawnVerticalSiblingPairs.insert(pair)
                }
            }
            else {
                drawParentInset(from: parentFrame, to: childFrame, edge: .top, siblings: siblings, in: context)
            }

            // 하단
            let potentialBelow = siblings.filter { $0.frame.minY >= childFrame.maxY && framesOverlapHorizontally(childFrame, $0.frame) }
            if let closestBelow = potentialBelow.min(by: { $0.frame.minY < $1.frame.minY }) {
                let pair: Set<ObjectIdentifier> = [ObjectIdentifier(currentViewInfo.view), ObjectIdentifier(closestBelow.view)]
                if !drawnVerticalSiblingPairs.contains(pair) {
                    drawSiblingSpacing(from: childFrame, to: closestBelow.frame, edge: .bottom, in: context)
                    drawnVerticalSiblingPairs.insert(pair)
                }
            }
            else {
                drawParentInset(from: parentFrame, to: childFrame, edge: .bottom, siblings: siblings, in: context)
            }

            // 좌측
            let potentialLeft = siblings.filter { $0.frame.maxX <= childFrame.minX && framesOverlapVertically(childFrame, $0.frame) }
            if let closestLeft = potentialLeft.max(by: { $0.frame.maxX < $1.frame.maxX }) {
                let pair: Set<ObjectIdentifier> = [ObjectIdentifier(currentViewInfo.view), ObjectIdentifier(closestLeft.view)]
                if !drawnHorizontalSiblingPairs.contains(pair) {
                    drawSiblingSpacing(from: closestLeft.frame, to: childFrame, edge: .left, in: context)
                    drawnHorizontalSiblingPairs.insert(pair)
                }
            }
            else {
                drawParentInset(from: parentFrame, to: childFrame, edge: .left, siblings: siblings, in: context)
            }

            // 우측
            let potentialRight = siblings.filter { $0.frame.minX >= childFrame.maxX && framesOverlapVertically(childFrame, $0.frame) }
            if let closestRight = potentialRight.min(by: { $0.frame.minX < $1.frame.minX }) {
                let pair: Set<ObjectIdentifier> = [ObjectIdentifier(currentViewInfo.view), ObjectIdentifier(closestRight.view)]
                if !drawnHorizontalSiblingPairs.contains(pair) {
                    drawSiblingSpacing(from: childFrame, to: closestRight.frame, edge: .right, in: context)
                    drawnHorizontalSiblingPairs.insert(pair)
                }
            }
            else {
                drawParentInset(from: parentFrame, to: childFrame, edge: .right, siblings: siblings, in: context)
            }
        }
    }

    // MARK: - 그리기 헬퍼
    private enum MeasurementEdge { case top, bottom, left, right }

    private func drawParentInset(from parentFrame: CGRect, to childFrame: CGRect, edge: MeasurementEdge, siblings: [ViewInfo], in context: CGContext) {
        let color = UIColor.red
        switch edge {
        case .top:
            let inset = childFrame.minY - parentFrame.minY
            if inset > 0.5 {
                let lineX = childFrame.midX
                let startY = parentFrame.minY
                let endY = childFrame.minY

                let isObstructed = siblings.contains { siblingInfo -> Bool in
                    let siblingFrame = siblingInfo.frame
                    let measurementLine = CGRect(x: lineX - 0.5, y: startY, width: 1, height: endY - startY)
                    return measurementLine.intersects(siblingFrame)
                }
                guard !isObstructed else { return }

                drawVerticalMeasurement(from: CGPoint(x: lineX, y: endY), to: CGPoint(x: lineX, y: startY), value: Int(round(inset)), textPosition: CGPoint(x: lineX, y: (startY + endY) / 2), color: color, in: context, arrow: true)
            }
        case .bottom:
            let inset = parentFrame.maxY - childFrame.maxY
            if inset > 0.5 {
                let lineX = childFrame.midX
                let startY = childFrame.maxY
                let endY = parentFrame.maxY

                let isObstructed = siblings.contains { siblingInfo -> Bool in
                    let siblingFrame = siblingInfo.frame
                    let measurementLine = CGRect(x: lineX - 0.5, y: startY, width: 1, height: endY - startY)
                    return measurementLine.intersects(siblingFrame)
                }
                guard !isObstructed else { return }

                drawVerticalMeasurement(from: CGPoint(x: lineX, y: startY), to: CGPoint(x: lineX, y: endY), value: Int(round(inset)), textPosition: CGPoint(x: lineX, y: (startY + endY) / 2), color: color, in: context, arrow: true)
            }
        case .left:
            let inset = childFrame.minX - parentFrame.minX
            if inset > 0.5 {
                let lineY = childFrame.midY
                let startX = parentFrame.minX
                let endX = childFrame.minX

                let isObstructed = siblings.contains { siblingInfo -> Bool in
                    let siblingFrame = siblingInfo.frame
                    let measurementLine = CGRect(x: startX, y: lineY - 0.5, width: endX - startX, height: 1)
                    return measurementLine.intersects(siblingFrame)
                }
                guard !isObstructed else { return }

                drawHorizontalMeasurement(from: CGPoint(x: endX, y: lineY), to: CGPoint(x: startX, y: lineY), value: Int(round(inset)), textPosition: CGPoint(x: (startX + endX) / 2, y: lineY), color: color, in: context, arrow: true)
            }
        case .right:
            let inset = parentFrame.maxX - childFrame.maxX
            if inset > 0.5 {
                let lineY = childFrame.midY
                let startX = childFrame.maxX
                let endX = parentFrame.maxX

                let isObstructed = siblings.contains { siblingInfo -> Bool in
                    let siblingFrame = siblingInfo.frame
                    let measurementLine = CGRect(x: startX, y: lineY - 0.5, width: endX - startX, height: 1)
                    return measurementLine.intersects(siblingFrame)
                }
                guard !isObstructed else { return }

                drawHorizontalMeasurement(from: CGPoint(x: startX, y: lineY), to: CGPoint(x: endX, y: lineY), value: Int(round(inset)), textPosition: CGPoint(x: (startX + endX) / 2, y: lineY), color: color, in: context, arrow: true)
            }
        }
    }

    private func drawSiblingSpacing(from: CGRect, to: CGRect, edge: MeasurementEdge, in context: CGContext) {
        let color = UIColor.magenta
        switch edge {
        case .top, .bottom:
            let spacing = to.minY - from.maxY
            if spacing > 0.5 {
                let lineX = (max(from.minX, to.minX) + min(from.maxX, to.maxX)) / 2
                drawVerticalMeasurement(from: CGPoint(x: lineX, y: from.maxY), to: CGPoint(x: lineX, y: to.minY), value: Int(round(spacing)), textPosition: CGPoint(x: lineX, y: (from.maxY + to.minY) / 2), color: color, in: context, arrow: false)
            }
        case .left, .right:
            let spacing = to.minX - from.maxX
            if spacing > 0.5 {
                let lineY = (max(from.minY, to.minY) + min(from.maxY, to.maxY)) / 2
                drawHorizontalMeasurement(from: CGPoint(x: from.maxX, y: lineY), to: CGPoint(x: to.minX, y: lineY), value: Int(round(spacing)), textPosition: CGPoint(x: (from.maxX + to.minX) / 2, y: lineY), color: color, in: context, arrow: false)
            }
        }
    }

    // MARK: - 뷰 프레임 겹침 확인 헬퍼 메서드
    private func framesOverlapHorizontally(_ rect1: CGRect, _ rect2: CGRect) -> Bool {
        return max(rect1.minX, rect2.minX) < min(rect1.maxX, rect2.maxX)
    }

    private func framesOverlapVertically(_ rect1: CGRect, _ rect2: CGRect) -> Bool {
        return max(rect1.minY, rect2.minY) < min(rect1.maxY, rect2.maxY)
    }

    // MARK: - 수직 측정선 그리기 (텍스트 위치 별도 지정)
    private func drawVerticalMeasurement(from startPoint: CGPoint, to endPoint: CGPoint, value: Int, textPosition: CGPoint, color: UIColor, in context: CGContext, arrow: Bool) {
        // 화면에서 벗어났는지 검사
        guard startPoint.y >= 0, endPoint.y <= UIScreen.main.bounds.height else { return }
        // 라인 길이 제한
        guard abs(endPoint.y - startPoint.y) < Self.spacingLimit else { return }

        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(0.5)

        // 1. 점선 그리기
        context.setLineDash(phase: 0, lengths: [4, 2])
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()

        // 2. 실선으로 변경 및 눈금 그리기
        let tickLength: CGFloat = 1.5
        context.setLineDash(phase: 0, lengths: []) // 실선으로 변경

        // 3. 시작점 눈금
        context.move(to: CGPoint(x: startPoint.x - tickLength, y: startPoint.y))
        context.addLine(to: CGPoint(x: startPoint.x + tickLength, y: startPoint.y))
        context.strokePath()

        // 4. 끝점 눈금
        if arrow {
            // 화살표 그리기
            let arrowSize: CGFloat = 3 // 화살표 한 변의 길이
            let arrowAngle = CGFloat.pi / 6 // 화살표의 각도 (30도)

            // y좌표를 비교하여 화살표 방향 결정 (아래로 향하는지, 위로 향하는지)
            let isPointingDown = endPoint.y > startPoint.y
            let angleModifier: CGFloat = isPointingDown ? -1.0 : 1.0

            // 화살표를 구성하는 양쪽 끝 점 계산
            let dx = arrowSize * sin(arrowAngle)
            let dy = arrowSize * cos(arrowAngle)

            let arrowPoint1 = CGPoint(x: endPoint.x - dx, y: endPoint.y + (dy * angleModifier))
            let arrowPoint2 = CGPoint(x: endPoint.x + dx, y: endPoint.y + (dy * angleModifier))

            // 화살표 경로 그리기
            context.move(to: arrowPoint1)
            context.addLine(to: endPoint)
            context.addLine(to: arrowPoint2)
            context.strokePath()
        }
        else {
            context.move(to: CGPoint(x: endPoint.x - tickLength, y: endPoint.y))
            context.addLine(to: CGPoint(x: endPoint.x + tickLength, y: endPoint.y))
            context.strokePath()
        }

        // 상태 복원
        context.restoreGState()

        let lineLength = abs(endPoint.y - startPoint.y)
        drawMeasurementText("\(value)", at: textPosition, lineLength: lineLength, color: color, in: context)
    }

    // MARK: - 수평 측정선 그리기 (텍스트 위치 별도 지정)
    private func drawHorizontalMeasurement(from startPoint: CGPoint, to endPoint: CGPoint, value: Int, textPosition: CGPoint, color: UIColor, in context: CGContext, arrow: Bool) {
        // 화면에서 벗어났는지 검사
        guard startPoint.x >= 0, endPoint.x <= UIScreen.main.bounds.width else { return }
        // 라인 길이 제한
        guard abs(endPoint.x - startPoint.x) < Self.spacingLimit else { return }

        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(0.5)

        // 1. 점선 그리기
        context.setLineDash(phase: 0, lengths: [4, 2])
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()

        // 2. 실선으로 변경 및 눈금 그리기
        let tickLength: CGFloat = 1.5
        context.setLineDash(phase: 0, lengths: []) // 실선으로 변경

        // 3. 시작점 눈금
        context.move(to: CGPoint(x: startPoint.x, y: startPoint.y - tickLength))
        context.addLine(to: CGPoint(x: startPoint.x, y: startPoint.y + tickLength))
        context.strokePath()

        // 3. 끝점 눈금
        if arrow {
            // 화살표 그리기
            let arrowSize: CGFloat = 3
            let arrowAngle = CGFloat.pi / 6 // 30도

            // x좌표를 비교하여 화살표 방향 결정 (오른쪽으로 향하는지, 왼쪽으로 향하는지)
            let isPointingRight = endPoint.x > startPoint.x
            let angleModifier: CGFloat = isPointingRight ? -1.0 : 1.0

            // 화살표를 구성하는 양쪽 끝 점 계산
            let dx = arrowSize * cos(arrowAngle)
            let dy = arrowSize * sin(arrowAngle)

            let arrowPoint1 = CGPoint(x: endPoint.x + (dx * angleModifier), y: endPoint.y - dy)
            let arrowPoint2 = CGPoint(x: endPoint.x + (dx * angleModifier), y: endPoint.y + dy)

            // 화살표 경로 그리기
            context.move(to: arrowPoint1)
            context.addLine(to: endPoint)
            context.addLine(to: arrowPoint2)
            context.strokePath()
        }
        else {
            context.move(to: CGPoint(x: endPoint.x, y: endPoint.y - tickLength))
            context.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y + tickLength))
            context.strokePath()
        }

        // 상태 복원
        context.restoreGState()

        let lineLength = abs(endPoint.x - startPoint.x)
        drawMeasurementText("\(value)", at: textPosition, lineLength: lineLength, color: color, in: context)
    }

    // MARK: - 측정값 텍스트 그리기 (동적 폰트 크기 조절)
    private func drawMeasurementText(_ text: String, at point: CGPoint, lineLength: CGFloat, color: UIColor, in context: CGContext) {
        let defaultFontSize: CGFloat = 5.0
        let reducedFontSize: CGFloat = 3.0
        let minFontSize: CGFloat = 3.0
        let reduceThreshold: CGFloat = 12.0
        let minThreshold: CGFloat = 8.0

        var fontWeight: UIFont.Weight = .medium
        var fontSize = defaultFontSize
        if lineLength < reduceThreshold {
            fontSize = reducedFontSize
            fontWeight = .regular
        }
        if lineLength < minThreshold {
            fontSize = minFontSize
            fontWeight = .light
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight),
            .foregroundColor: color.withAlphaComponent(1.0),
            .backgroundColor: UIColor.white.withAlphaComponent(0.8)
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        // 수치 표시될 영역 박스 표시
//        let backgroundRect = CGRect(
//            x: point.x - textSize.width / 2 - 2,
//            y: point.y - textSize.height / 2 - 1,
//            width: textSize.width + 4,
//            height: textSize.height + 2
//        )

//        context.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
//        context.fill(backgroundRect)
//        context.setStrokeColor(color.cgColor)
//        context.setLineWidth(0.5)
//        context.stroke(backgroundRect)

        let textRect = CGRect(
            x: point.x - textSize.width / 2,
            y: point.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )

        attributedString.draw(in: textRect)
    }

    // MARK: - 뷰 크기 레이블 그리기 (동적 폰트 크기 조절)
    private func drawSizeLabel(text: String, at point: CGPoint, color: UIColor, viewFrame: CGRect, in context: CGContext) {
        let defaultFontSize: CGFloat = 6.0
        let reducedFontSize: CGFloat = 4.0
        let minFontSize: CGFloat = 3.0
        let reduceThreshold: CGFloat = 50.0
        let minThreshold: CGFloat = 30.0

        var fontWeight: UIFont.Weight = .bold
        let smallestSide = min(viewFrame.width, viewFrame.height)
        var fontSize = defaultFontSize
        if smallestSide < reduceThreshold {
            fontSize = reducedFontSize
            fontWeight = .regular
        }
        if smallestSide < minThreshold {
            fontSize = minFontSize
            fontWeight = .light
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight),
            .foregroundColor: color.withAlphaComponent(1.0),
            .backgroundColor: UIColor.clear
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        let backgroundRect = CGRect(
            x: point.x - textSize.width / 2 - 2,
            y: point.y - textSize.height / 2 - 1,
            width: textSize.width + 4,
            height: textSize.height + 2
        )

        context.saveGState()

        context.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.fill(backgroundRect)

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(0.5)
        context.stroke(backgroundRect)

        let textRect = CGRect(
            x: point.x - textSize.width / 2,
            y: point.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )

        attributedString.draw(in: textRect)

        context.restoreGState()
    }

    // MARK: - 뷰 타입별 색상 반환
    private func getColorForViewType(_ view: UIView) -> (view: UIColor, text: UIColor) {
        let alpha: CGFloat = 0.7
        switch view {
        case is UILabel:
            let color = UIColor(red: 0.0, green: 200.0 / 255.0, blue: 0.0, alpha: alpha)
            return (color, color)
        case is UIImageView:
            let color = UIColor.red.withAlphaComponent(alpha)
            return (color, color)
        case is UIButton:
            let color = UIColor.blue.withAlphaComponent(alpha)
            return (color, color)
        case is UITableViewCell, is UICollectionViewCell:
            let color = UIColor.purple.withAlphaComponent(alpha)
            return (color, color)
        case is WKWebView:
            let color = UIColor.red.withAlphaComponent(alpha)
            return (color, color)
        case is UITextField:
            let color = UIColor.darkGray.withAlphaComponent(alpha)
            return (color, color)
        case is UIScrollView:
            let color = UIColor.systemPurple.withAlphaComponent(alpha)
            return (color, color)
        case is UIStackView:
            let color = UIColor.systemOrange.withAlphaComponent(alpha)
            return (color, color)
        case is UITextView:
            let color = UIColor.cyan.withAlphaComponent(alpha)
            return (color, color)
        case is UISwitch:
            let color = UIColor.systemPink.withAlphaComponent(alpha)
            return (color, color)
        case is UISlider:
            let color = UIColor.systemYellow.withAlphaComponent(alpha)
            return (color, color)
        case is UISegmentedControl:
            let color = UIColor.systemIndigo.withAlphaComponent(alpha)
            return (color, color)
        case is UIStepper:
            let color = UIColor.systemBrown.withAlphaComponent(alpha)
            return (color, color)
        case is UIProgressView:
            let color = UIColor.systemGray.withAlphaComponent(alpha)
            return (color, color)
        case is UIActivityIndicatorView:
            let color = UIColor.systemGray2.withAlphaComponent(alpha)
            return (color, color)
        case is UINavigationBar:
            let color = UIColor.systemRed.withAlphaComponent(alpha)
            return (color, color)
        case is UITabBar:
            let color = UIColor.systemOrange.withAlphaComponent(alpha)
            return (color, color)
        case is UIToolbar:
            let color = UIColor.systemYellow.withAlphaComponent(alpha)
            return (color, color)
        case is UIDatePicker:
            let color = UIColor.systemBlue.withAlphaComponent(alpha)
            return (color, color)
        case is UIPickerView:
            let color = UIColor.systemGreen.withAlphaComponent(alpha)
            return (color, color)
        default:
            return (UIColor(red: 1.0, green: 229.0 / 255.0, blue: 0.0, alpha: alpha),
                    UIColor(red: 183.0 / 255, green: 183.0 / 255.0, blue: 0.0, alpha: alpha))
        }
    }

    // MARK: - 헬퍼 메서드들

    /// 뷰 크기가 소수점자리로 살짝실 다르게 나올때가 있어서 따로 체크
    private func sameFrame(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        if abs(lhs.minX - rhs.minX) > 1 { return false }
        if abs(lhs.minY - rhs.minY) > 1 { return false }
        if abs(lhs.width - rhs.width) > 1 { return false }
        if abs(lhs.height - rhs.height) > 1 { return false }
        return true
    }

    private func findParentViewInfo(for viewInfo: ViewInfo, in viewInfos: [ViewInfo]) -> ViewInfo? {
        guard let superview = viewInfo.view.superview else {
            return nil
        }
        return viewInfos.first { $0.view === superview }
    }

    private func isViewInsideCell(_ view: UIView) -> Bool {
        var parent = view.superview
        while parent != nil {
            if parent is UITableViewCell || parent is UICollectionViewCell {
                return true
            }
            parent = parent?.superview
        }
        return false
    }

    /// 특정 뷰가 전체 뷰 목록 내에서 완전히 가려졌는지 확인합니다.
    /// - Parameters:
    ///   - viewInfoToTest: 검사할 뷰의 정보
    ///   - allViewInfos: 전체 뷰 정보 목록 (그려지는 순서대로 정렬됨)
    ///   - testIndex: `allViewInfos`에서 `viewInfoToTest`의 인덱스
    /// - Returns: 뷰가 완전히 가려졌으면 true, 아니면 false
    private func isViewCompletelyObscured(viewInfoToTest: ViewInfo, in allViewInfos: [ViewInfo], at testIndex: Int) -> Bool {
        let frameToTest = viewInfoToTest.frame

        // 1. 가릴 가능성이 있는 뷰들을 찾습니다.
        // 나 자신보다 뒤에(즉, 위에) 그려지는 뷰들만 후보가 됩니다.
        // 또한, 검사할 뷰의 프레임과 겹치는 뷰들만 실질적인 후보입니다.
        let potentialObscuringViews = allViewInfos[(testIndex + 1)...].filter { otherViewInfo in
            // 뷰위에 버튼을 추가 해서 사용하는 경우가 많아서 제외
            if otherViewInfo.view is UIButton {
                return false
            }
            return frameToTest.intersects(otherViewInfo.frame)
        }

        // 가릴만한 뷰가 없으면 false를 반환합니다.
        if potentialObscuringViews.isEmpty {
            return false
        }

        // 2. 5픽셀 격자 샘플링으로 완전히 가려졌는지 검사합니다.
        let step: CGFloat = 2.0
        var y: CGFloat = 0
        while true {
            var x: CGFloat = 0
            while true {
                // 검사할 좌표는 viewInfoToTest의 프레임 기준입니다.
                let testPoint = CGPoint(x: frameToTest.minX + x, y: frameToTest.minY + y)

                var isPointCovered = false
                for obscuringViewInfo in potentialObscuringViews {
                    // 이 좌표가 가리는 뷰의 프레임에 포함되는지 확인합니다.
                    if obscuringViewInfo.frame.contains(testPoint) {
                        isPointCovered = true
                        break
                    }
                }

                // 한 점이라도 가려지지 않았다면, '완전히' 가려진 것이 아니므로 즉시 false를 반환합니다.
                if !isPointCovered {
                    return false
                }

                if x == frameToTest.width {
                    break
                }
                x = min(x + step, frameToTest.width)
            }

            if y == frameToTest.height {
                break
            }
            y = min(y + step, frameToTest.height)
        }

        // 모든 샘플링 지점이 가려졌다면, 뷰는 완전히 가려진 것입니다.
        return true
    }

    // MARK: - 결과 표시
    private func showImagePreview(_ image: UIImage, from viewController: UIViewController) {
         let previewVC = ImagePreviewViewController()
         previewVC.image = image
         previewVC.modalPresentationStyle = .fullScreen
         viewController.present(previewVC, animated: true)
    }
}

// MARK: - 뷰 정보 구조체
struct ViewInfo {
    let view: UIView
    let frame: CGRect
}
