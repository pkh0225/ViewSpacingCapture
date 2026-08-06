//
//  SwiftUILayerHierarchyBuilder.swift
//  ViewSpacingCapture
//
//  CALayer 트리에서 측정 대상을 자동 수집합니다.
//
//  SwiftUI는 VStack/padding 같은 컨테이너를 UIView로 남기지 않지만,
//  실제로 그려지는 것(Color, Shape, Text, Image)은 CALayer로 남습니다.
//  다만 그 레이어들은 계층 없이 평평하게 나열되므로,
//  rect 포함 관계로 부모-자식을 다시 세워 간격 측정에 사용합니다.
//

import UIKit

enum SwiftUILayerHierarchyBuilder {

    struct Options {
        /// 이 크기 미만의 레이어는 무시합니다.
        var minimumSize: CGFloat = 1
        /// 텍스트/이미지처럼 `contents`로만 그려지는 레이어 포함 여부
        var includesContentLayers = true
        /// 이 값 이내로 프레임이 겹치면 같은 레이어로 보고 하나만 남깁니다.
        var duplicateTolerance: CGFloat = 1
        /// 포함 관계 판정 시 허용 오차
        var containmentTolerance: CGFloat = 0.5

        /// 나중에 그려진 불투명 레이어에 덮인 항목을 결과에서 제외합니다.
        var hidesOccludedViews = false
        /// 가림 판정 시 가장자리 오차를 흡수하기 위한 inset
        var occlusionSampleInset: CGFloat = 1
        /// 샘플 중 이 비율 이상 덮이면 가려진 것으로 처리 (0...1)
        var occlusionCoverageThreshold: Double = 0.1
        /// 축당 최대 샘플 수
        var occlusionMaxSamplesPerAxis = 12

        init() {}
    }

    /// 수집 단계에서 다루는 레이어 한 개
    private struct Candidate {
        let frame: CGRect
        /// 아래에 있는 것을 완전히 덮을 수 있는(불투명하게 전체를 칠하는) 레이어인지
        let isOpaque: Bool
    }

    /// 그리기 순서(뒤 → 앞)를 유지한 채 측정 대상을 수집합니다.
    static func build(rootView: UIView, options: Options = Options()) -> [SwiftUIViewSpacingItem] {
        let rootLayer = rootView.layer
        let rootBounds = rootView.bounds

        var collected: [Candidate] = []
        collect(
            layer: rootLayer,
            rootLayer: rootLayer,
            clip: rootBounds,
            alpha: 1,
            options: options,
            into: &collected
        )

        let unique = deduplicate(collected, rootBounds: rootBounds, options: options)
        let visible = removeOccluded(unique, options: options)
        return makeItems(from: visible.map(\.frame), options: options)
    }

    // MARK: - 레이어 수집

    private static func collect(
        layer: CALayer,
        rootLayer: CALayer,
        clip: CGRect,
        alpha: Float,
        options: Options,
        into result: inout [Candidate]
    ) {
        if layer.isHidden || layer.opacity < 0.009 { return }

        // 조상의 투명도가 누적되므로 곱해서 내려보냅니다.
        let currentAlpha = alpha * layer.opacity
        if currentAlpha < 0.009 { return }

        let frame = layer.convert(layer.bounds, to: rootLayer)
        let visible = frame.intersection(clip)
        // 클리핑으로 완전히 잘려나간 경우 자식도 볼 필요가 없습니다.
        if visible.isNull || visible.isEmpty { return }

        if isDrawn(layer, options: options),
           visible.width >= options.minimumSize,
           visible.height >= options.minimumSize {
            result.append(Candidate(
                frame: visible,
                isOpaque: currentAlpha >= 0.99 && fillsBoundsOpaquely(layer)
            ))
        }

        let childClip = layer.masksToBounds ? visible : clip
        for sublayer in layer.sublayers ?? [] {
            collect(
                layer: sublayer,
                rootLayer: rootLayer,
                clip: childClip,
                alpha: currentAlpha,
                options: options,
                into: &result
            )
        }
    }

    /// 자기 영역 전체를 불투명하게 칠해서 아래를 가릴 수 있는 레이어인지 판정합니다.
    ///
    /// 텍스트나 아이콘처럼 `contents`로 그려지는 레이어는 글자 사이가 비어 있어
    /// 실제로는 아래를 가리지 못하므로 obscurer로 보지 않습니다.
    private static func fillsBoundsOpaquely(_ layer: CALayer) -> Bool {
        if let background = layer.backgroundColor, background.alpha >= 0.99 {
            return true
        }
        if let gradient = layer as? CAGradientLayer,
           let colors = gradient.colors as? [CGColor],
           !colors.isEmpty,
           colors.allSatisfy({ $0.alpha >= 0.99 }) {
            return true
        }
        return false
    }

    /// 실제로 픽셀을 그리는 레이어인지 판정합니다.
    /// 클래스 이름은 iOS 버전마다 달라지므로 그리기 속성만 봅니다.
    private static func isDrawn(_ layer: CALayer, options: Options) -> Bool {
        if let background = layer.backgroundColor, background.alpha >= 0.009 {
            return true
        }
        if layer.borderWidth > 0, let border = layer.borderColor, border.alpha >= 0.009 {
            return true
        }
        if let shape = layer as? CAShapeLayer, shape.path != nil {
            if let fill = shape.fillColor, fill.alpha >= 0.009 { return true }
            if let stroke = shape.strokeColor, stroke.alpha >= 0.009, shape.lineWidth > 0 { return true }
        }
        if let gradient = layer as? CAGradientLayer, gradient.colors?.isEmpty == false {
            return true
        }
        if options.includesContentLayers, layer.contents != nil {
            return true
        }
        return false
    }

    // MARK: - 중복 제거

    private static func deduplicate(
        _ candidates: [Candidate],
        rootBounds: CGRect,
        options: Options
    ) -> [Candidate] {
        var result: [Candidate] = []
        for candidate in candidates {
            // 루트 전체와 같은 크기는 rootBounds가 대신하므로 제외합니다.
            if isNearlyEqual(candidate.frame, rootBounds, tolerance: options.duplicateTolerance) { continue }
            if result.contains(where: { isNearlyEqual($0.frame, candidate.frame, tolerance: options.duplicateTolerance) }) { continue }
            result.append(candidate)
        }
        return result
    }

    // MARK: - 가려진 항목 제거

    private static func removeOccluded(_ candidates: [Candidate], options: Options) -> [Candidate] {
        guard options.hidesOccludedViews else { return candidates }
        return candidates.enumerated()
            .filter { !isOccluded($0.element, in: candidates, at: $0.offset, options: options) }
            .map(\.element)
    }

    /// 나보다 나중에 그려진 불투명 레이어들이 내 영역을 충분히 덮는지 격자 샘플링으로 판정합니다.
    private static func isOccluded(
        _ candidate: Candidate,
        in candidates: [Candidate],
        at index: Int,
        options: Options
    ) -> Bool {
        let target = candidate.frame

        var obscurers: [CGRect] = []
        for next in (index + 1)..<candidates.count {
            let other = candidates[next]
            guard other.isOpaque, target.intersects(other.frame) else { continue }
            // 내 안에 놓인 자식은 나를 가리는 것으로 보지 않습니다.
            if contains(target, other.frame, tolerance: options.containmentTolerance) { continue }
            obscurers.append(other.frame)
        }
        guard !obscurers.isEmpty else { return false }

        let insetX = min(options.occlusionSampleInset, target.width / 2)
        let insetY = min(options.occlusionSampleInset, target.height / 2)
        let sampleFrame = target.insetBy(dx: insetX, dy: insetY)
        guard sampleFrame.width > 0, sampleFrame.height > 0 else { return false }

        // 빠른 경로: 한 레이어가 통째로 포함하면 즉시 가림
        if obscurers.contains(where: { $0.contains(sampleFrame) }) { return true }

        // 큰 것부터 검사해 샘플 히트 확률을 높입니다.
        obscurers.sort { $0.width * $0.height > $1.width * $1.height }

        let maxAxis = max(2, options.occlusionMaxSamplesPerAxis)
        let sampleXs = samplePositions(from: sampleFrame.minX, to: sampleFrame.maxX, maxCount: maxAxis)
        let sampleYs = samplePositions(from: sampleFrame.minY, to: sampleFrame.maxY, maxCount: maxAxis)

        let expectedTotal = sampleXs.count * sampleYs.count
        guard expectedTotal > 0 else { return false }
        let neededCovered = Int(ceil(Double(expectedTotal) * options.occlusionCoverageThreshold))

        var coveredSamples = 0
        var checkedSamples = 0
        for sampleY in sampleYs {
            for sampleX in sampleXs {
                checkedSamples += 1
                if coveredSamples >= neededCovered { return true }
                if coveredSamples + (expectedTotal - checkedSamples) < neededCovered { return false }

                let point = CGPoint(x: sampleX, y: sampleY)
                if obscurers.contains(where: { containsInclusive($0, point) }) {
                    coveredSamples += 1
                }
            }
        }
        return coveredSamples >= neededCovered
    }

    private static func samplePositions(from start: CGFloat, to end: CGFloat, maxCount: Int) -> [CGFloat] {
        let step = max(2.0, (end - start) / CGFloat(maxCount - 1))
        var result: [CGFloat] = []
        result.reserveCapacity(maxCount)
        var value = start
        while true {
            result.append(value)
            if value >= end { break }
            value = min(value + step, end)
        }
        return result
    }

    /// `CGRect.contains`와 달리 maxX/maxY 경계를 포함합니다.
    private static func containsInclusive(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x <= rect.maxX
            && point.y >= rect.minY && point.y <= rect.maxY
    }

    // MARK: - 계층 복원

    /// 각 레이어의 부모를 "나보다 먼저 그려졌고, 나를 완전히 포함하는 가장 작은 레이어"로 정합니다.
    private static func makeItems(from rects: [CGRect], options: Options) -> [SwiftUIViewSpacingItem] {
        rects.enumerated().map { index, rect in
            var parentIndex: Int?
            var parentArea = CGFloat.greatestFiniteMagnitude

            for candidate in 0..<index {
                let candidateRect = rects[candidate]
                guard contains(candidateRect, rect, tolerance: options.containmentTolerance) else { continue }
                let candidateArea = candidateRect.width * candidateRect.height
                guard candidateArea > rect.width * rect.height else { continue }
                if candidateArea < parentArea {
                    parentArea = candidateArea
                    parentIndex = candidate
                }
            }

            return SwiftUIViewSpacingItem(
                id: identifier(index),
                parentId: parentIndex.map(identifier),
                frame: rect
            )
        }
    }

    private static func identifier(_ index: Int) -> String {
        "layer-\(index)"
    }

    private static func contains(_ outer: CGRect, _ inner: CGRect, tolerance: CGFloat) -> Bool {
        outer.minX <= inner.minX + tolerance
            && outer.minY <= inner.minY + tolerance
            && outer.maxX >= inner.maxX - tolerance
            && outer.maxY >= inner.maxY - tolerance
    }

    private static func isNearlyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
