//
//  SwiftUIViewSpacingCaptureRenderer.swift
//  ViewSpacingCapture
//
//  SwiftUI Preference frame 기반 간격 측정/렌더링 (UIKit 로직과 독립)
//

import UIKit

enum SwiftUIViewSpacingCaptureRenderer {

    struct MeasurementLine {
        let start: CGPoint
        let end: CGPoint
        let value: Int
        let isParentInset: Bool
    }

    private enum Edge {
        case top, bottom, left, right
    }

    private static let rootParentId = "__swiftui_spacing_root__"

    // MARK: - Public

    static func draw(
        on image: UIImage,
        items: [SwiftUIViewSpacingItem],
        rootBounds: CGRect,
        frameOffset: CGPoint = .zero,
        spacingLimit: CGFloat,
        isShowSize: Bool
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { ctx in
            image.draw(at: .zero)

            let cg = ctx.cgContext
            let shifted = items.map {
                SwiftUIViewSpacingItem(
                    id: $0.id,
                    parentId: $0.parentId,
                    frame: $0.frame.offsetBy(dx: frameOffset.x, dy: frameOffset.y)
                )
            }
            let root = rootBounds.offsetBy(dx: frameOffset.x, dy: frameOffset.y)

            drawBounds(items: shifted, isShowSize: isShowSize, in: cg)
            drawMeasurements(items: shifted, rootBounds: root, spacingLimit: spacingLimit, in: cg)
        }
    }

    static func measurements(
        items: [SwiftUIViewSpacingItem],
        rootBounds: CGRect,
        spacingLimit: CGFloat
    ) -> [MeasurementLine] {
        var lines: [MeasurementLine] = []
        var drawnVertical: Set<Set<String>> = []
        var drawnHorizontal: Set<Set<String>> = []

        let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let effectiveRoot = rootBounds.isNull
            ? boundingRect(of: items) ?? .zero
            : rootBounds

        for item in items {
            let parentId = item.parentId ?? rootParentId
            let parentFrame: CGRect
            if parentId == rootParentId {
                parentFrame = effectiveRoot
            } else if let parent = byId[parentId] {
                parentFrame = parent.frame
            } else {
                continue
            }

            let siblings = items.filter {
                ($0.parentId ?? rootParentId) == parentId && $0.id != item.id
            }

            // Top
            let above = siblings.filter {
                $0.frame.maxY <= item.frame.minY && framesOverlapHorizontally(item.frame, $0.frame)
            }
            if let closest = above.max(by: { $0.frame.maxY < $1.frame.maxY }) {
                let pair: Set<String> = [item.id, closest.id]
                if !drawnVertical.contains(pair) {
                    if let line = siblingLine(from: closest.frame, to: item.frame, edge: .top, spacingLimit: spacingLimit) {
                        lines.append(line)
                    }
                    drawnVertical.insert(pair)
                }
            } else if let line = parentInsetLine(
                from: parentFrame,
                to: item.frame,
                edge: .top,
                siblings: siblings,
                spacingLimit: spacingLimit
            ) {
                lines.append(line)
            }

            // Bottom
            let below = siblings.filter {
                $0.frame.minY >= item.frame.maxY && framesOverlapHorizontally(item.frame, $0.frame)
            }
            if let closest = below.min(by: { $0.frame.minY < $1.frame.minY }) {
                let pair: Set<String> = [item.id, closest.id]
                if !drawnVertical.contains(pair) {
                    if let line = siblingLine(from: item.frame, to: closest.frame, edge: .bottom, spacingLimit: spacingLimit) {
                        lines.append(line)
                    }
                    drawnVertical.insert(pair)
                }
            } else if let line = parentInsetLine(
                from: parentFrame,
                to: item.frame,
                edge: .bottom,
                siblings: siblings,
                spacingLimit: spacingLimit
            ) {
                lines.append(line)
            }

            // Left
            let left = siblings.filter {
                $0.frame.maxX <= item.frame.minX && framesOverlapVertically(item.frame, $0.frame)
            }
            if let closest = left.max(by: { $0.frame.maxX < $1.frame.maxX }) {
                let pair: Set<String> = [item.id, closest.id]
                if !drawnHorizontal.contains(pair) {
                    if let line = siblingLine(from: closest.frame, to: item.frame, edge: .left, spacingLimit: spacingLimit) {
                        lines.append(line)
                    }
                    drawnHorizontal.insert(pair)
                }
            } else if let line = parentInsetLine(
                from: parentFrame,
                to: item.frame,
                edge: .left,
                siblings: siblings,
                spacingLimit: spacingLimit
            ) {
                lines.append(line)
            }

            // Right
            let right = siblings.filter {
                $0.frame.minX >= item.frame.maxX && framesOverlapVertically(item.frame, $0.frame)
            }
            if let closest = right.min(by: { $0.frame.minX < $1.frame.minX }) {
                let pair: Set<String> = [item.id, closest.id]
                if !drawnHorizontal.contains(pair) {
                    if let line = siblingLine(from: item.frame, to: closest.frame, edge: .right, spacingLimit: spacingLimit) {
                        lines.append(line)
                    }
                    drawnHorizontal.insert(pair)
                }
            } else if let line = parentInsetLine(
                from: parentFrame,
                to: item.frame,
                edge: .right,
                siblings: siblings,
                spacingLimit: spacingLimit
            ) {
                lines.append(line)
            }
        }

        return lines
    }

    // MARK: - Draw

    private static func drawBounds(items: [SwiftUIViewSpacingItem], isShowSize: Bool, in context: CGContext) {
        context.setStrokeColor(UIColor.cyan.cgColor)
        context.setLineWidth(0.8)

        // UIKit 캡처처럼 컨테이너는 빼고 말단 요소에만 크기를 표시합니다.
        let parentIds = Set(items.compactMap(\.parentId))

        for item in items {
            context.stroke(item.frame.insetBy(dx: 0.4, dy: 0.4))

            if isShowSize, !parentIds.contains(item.id) {
                drawSizeCross(in: item.frame, color: .cyan, in: context)
                let text = "\(Int(round(item.frame.width)))×\(Int(round(item.frame.height)))"
                drawSizeLabel(text, color: .cyan, viewFrame: item.frame, in: context)
            }
        }
    }

    /// 크기 표시용 X자 점선. UIKit 캡처의 표현과 맞춥니다.
    private static func drawSizeCross(in frame: CGRect, color: UIColor, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(color.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(0.5)
        context.setLineDash(phase: 0, lengths: [1, 3])

        context.move(to: CGPoint(x: frame.minX, y: frame.minY))
        context.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        context.strokePath()

        context.move(to: CGPoint(x: frame.minX, y: frame.maxY))
        context.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        context.strokePath()

        context.restoreGState()
    }

    private static func drawMeasurements(
        items: [SwiftUIViewSpacingItem],
        rootBounds: CGRect,
        spacingLimit: CGFloat,
        in context: CGContext
    ) {
        let lines = measurements(items: items, rootBounds: rootBounds, spacingLimit: spacingLimit)
        for line in lines {
            let color: UIColor = line.isParentInset ? .red : .magenta
            drawMeasurement(
                from: line.start,
                to: line.end,
                value: line.value,
                color: color,
                arrow: line.isParentInset,
                spacingLimit: spacingLimit,
                in: context
            )
        }
    }

    private static func siblingLine(from: CGRect, to: CGRect, edge: Edge, spacingLimit: CGFloat) -> MeasurementLine? {
        switch edge {
        case .top, .bottom:
            let spacing = to.minY - from.maxY
            guard spacing > 0.5, spacing < spacingLimit else { return nil }
            let x = (max(from.minX, to.minX) + min(from.maxX, to.maxX)) / 2
            return MeasurementLine(
                start: CGPoint(x: x, y: from.maxY),
                end: CGPoint(x: x, y: to.minY),
                value: Int(round(spacing)),
                isParentInset: false
            )
        case .left, .right:
            let spacing = to.minX - from.maxX
            guard spacing > 0.5, spacing < spacingLimit else { return nil }
            let y = (max(from.minY, to.minY) + min(from.maxY, to.maxY)) / 2
            return MeasurementLine(
                start: CGPoint(x: from.maxX, y: y),
                end: CGPoint(x: to.minX, y: y),
                value: Int(round(spacing)),
                isParentInset: false
            )
        }
    }

    private static func parentInsetLine(
        from parentFrame: CGRect,
        to childFrame: CGRect,
        edge: Edge,
        siblings: [SwiftUIViewSpacingItem],
        spacingLimit: CGFloat
    ) -> MeasurementLine? {
        switch edge {
        case .top:
            let inset = childFrame.minY - parentFrame.minY
            guard inset > 0.5, inset < spacingLimit else { return nil }
            let x = childFrame.midX
            let start = CGPoint(x: x, y: parentFrame.minY)
            let end = CGPoint(x: x, y: childFrame.minY)
            let lineRect = CGRect(x: x - 0.5, y: start.y, width: 1, height: end.y - start.y)
            guard !siblings.contains(where: { lineRect.intersects($0.frame) }) else { return nil }
            return MeasurementLine(start: end, end: start, value: Int(round(inset)), isParentInset: true)
        case .bottom:
            let inset = parentFrame.maxY - childFrame.maxY
            guard inset > 0.5, inset < spacingLimit else { return nil }
            let x = childFrame.midX
            let start = CGPoint(x: x, y: childFrame.maxY)
            let end = CGPoint(x: x, y: parentFrame.maxY)
            let lineRect = CGRect(x: x - 0.5, y: start.y, width: 1, height: end.y - start.y)
            guard !siblings.contains(where: { lineRect.intersects($0.frame) }) else { return nil }
            return MeasurementLine(start: start, end: end, value: Int(round(inset)), isParentInset: true)
        case .left:
            let inset = childFrame.minX - parentFrame.minX
            guard inset > 0.5, inset < spacingLimit else { return nil }
            let y = childFrame.midY
            let start = CGPoint(x: parentFrame.minX, y: y)
            let end = CGPoint(x: childFrame.minX, y: y)
            let lineRect = CGRect(x: start.x, y: y - 0.5, width: end.x - start.x, height: 1)
            guard !siblings.contains(where: { lineRect.intersects($0.frame) }) else { return nil }
            return MeasurementLine(start: end, end: start, value: Int(round(inset)), isParentInset: true)
        case .right:
            let inset = parentFrame.maxX - childFrame.maxX
            guard inset > 0.5, inset < spacingLimit else { return nil }
            let y = childFrame.midY
            let start = CGPoint(x: childFrame.maxX, y: y)
            let end = CGPoint(x: parentFrame.maxX, y: y)
            let lineRect = CGRect(x: start.x, y: y - 0.5, width: end.x - start.x, height: 1)
            guard !siblings.contains(where: { lineRect.intersects($0.frame) }) else { return nil }
            return MeasurementLine(start: start, end: end, value: Int(round(inset)), isParentInset: true)
        }
    }

    private static func drawMeasurement(
        from start: CGPoint,
        to end: CGPoint,
        value: Int,
        color: UIColor,
        arrow: Bool,
        spacingLimit: CGFloat,
        in context: CGContext
    ) {
        let isVertical = abs(end.x - start.x) < 0.5
        let length = isVertical ? abs(end.y - start.y) : abs(end.x - start.x)
        guard length < spacingLimit else { return }

        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(0.5)
        context.setLineDash(phase: 0, lengths: [4, 2])
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        context.setLineDash(phase: 0, lengths: [])
        let tick: CGFloat = 1.5

        if isVertical {
            context.move(to: CGPoint(x: start.x - tick, y: start.y))
            context.addLine(to: CGPoint(x: start.x + tick, y: start.y))
            context.strokePath()

            if arrow {
                drawArrow(at: end, from: start, color: color, in: context)
            } else {
                context.move(to: CGPoint(x: end.x - tick, y: end.y))
                context.addLine(to: CGPoint(x: end.x + tick, y: end.y))
                context.strokePath()
            }
        } else {
            context.move(to: CGPoint(x: start.x, y: start.y - tick))
            context.addLine(to: CGPoint(x: start.x, y: start.y + tick))
            context.strokePath()

            if arrow {
                drawArrow(at: end, from: start, color: color, in: context)
            } else {
                context.move(to: CGPoint(x: end.x, y: end.y - tick))
                context.addLine(to: CGPoint(x: end.x, y: end.y + tick))
                context.strokePath()
            }
        }

        context.restoreGState()

        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        drawLabel("\(value)", at: mid, color: color, in: context)
    }

    private static func drawArrow(at end: CGPoint, from start: CGPoint, color: UIColor, in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        let arrowSize: CGFloat = 3
        let arrowAngle = CGFloat.pi / 6

        if abs(end.x - start.x) < 0.5 {
            let isPointingDown = end.y > start.y
            let angleModifier: CGFloat = isPointingDown ? -1 : 1
            let dx = arrowSize * sin(arrowAngle)
            let dy = arrowSize * cos(arrowAngle)
            context.move(to: CGPoint(x: end.x - dx, y: end.y + dy * angleModifier))
            context.addLine(to: end)
            context.addLine(to: CGPoint(x: end.x + dx, y: end.y + dy * angleModifier))
            context.strokePath()
        } else {
            let isPointingRight = end.x > start.x
            let angleModifier: CGFloat = isPointingRight ? -1 : 1
            let dx = arrowSize * cos(arrowAngle)
            let dy = arrowSize * sin(arrowAngle)
            context.move(to: CGPoint(x: end.x + dx * angleModifier, y: end.y - dy))
            context.addLine(to: end)
            context.addLine(to: CGPoint(x: end.x + dx * angleModifier, y: end.y + dy))
            context.strokePath()
        }
    }

    /// 크기 라벨. UIKit 캡처처럼 테두리가 있는 배경 박스를 두르고, 대상이 작으면 글자를 줄입니다.
    private static func drawSizeLabel(_ text: String, color: UIColor, viewFrame: CGRect, in context: CGContext) {
        var fontSize: CGFloat = 6
        var fontWeight: UIFont.Weight = .bold
        let smallestSide = min(viewFrame.width, viewFrame.height)
        if smallestSide < 50 {
            fontSize = 4
            fontWeight = .regular
        }
        if smallestSide < 30 {
            fontSize = 3
        }

        let attributed = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight),
            .foregroundColor: darkened(color)
        ])
        let size = attributed.size()
        let center = CGPoint(x: viewFrame.midX, y: viewFrame.midY)
        let textRect = CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )

        context.saveGState()
        context.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.fill(textRect.insetBy(dx: -2, dy: -1))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(0.5)
        context.stroke(textRect.insetBy(dx: -2, dy: -1))
        attributed.draw(in: textRect)
        context.restoreGState()
    }

    /// 흰 배경 위에서도 읽히도록 경계선 색을 어둡게 변형합니다.
    /// 시안처럼 밝은 색은 흰 배경과 대비가 거의 없습니다.
    private static func darkened(_ color: UIColor) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return .darkGray
        }
        return UIColor(hue: hue, saturation: saturation, brightness: brightness * 0.55, alpha: 1)
    }

    private static func drawLabel(_ text: String, at point: CGPoint, color: UIColor, in context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 5, weight: .medium),
            .foregroundColor: color,
            .backgroundColor: UIColor.white.withAlphaComponent(0.8)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let size = attributed.size()
        attributed.draw(
            in: CGRect(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2,
                width: size.width,
                height: size.height
            )
        )
    }

    private static func framesOverlapHorizontally(_ a: CGRect, _ b: CGRect) -> Bool {
        max(a.minX, b.minX) < min(a.maxX, b.maxX)
    }

    private static func framesOverlapVertically(_ a: CGRect, _ b: CGRect) -> Bool {
        max(a.minY, b.minY) < min(a.maxY, b.maxY)
    }

    private static func boundingRect(of items: [SwiftUIViewSpacingItem]) -> CGRect? {
        guard let first = items.first else { return nil }
        return items.dropFirst().reduce(first.frame) { $0.union($1.frame) }
    }
}
