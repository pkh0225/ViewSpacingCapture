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

        init() {}
    }

    /// 그리기 순서(뒤 → 앞)를 유지한 채 측정 대상을 수집합니다.
    static func build(rootView: UIView, options: Options = Options()) -> [SwiftUIViewSpacingItem] {
        let rootLayer = rootView.layer
        let rootBounds = rootView.bounds

        var collected: [CGRect] = []
        collect(
            layer: rootLayer,
            rootLayer: rootLayer,
            clip: rootBounds,
            options: options,
            into: &collected
        )

        let unique = deduplicate(collected, rootBounds: rootBounds, options: options)
        return makeItems(from: unique, options: options)
    }

    // MARK: - 레이어 수집

    private static func collect(
        layer: CALayer,
        rootLayer: CALayer,
        clip: CGRect,
        options: Options,
        into result: inout [CGRect]
    ) {
        if layer.isHidden || layer.opacity < 0.01 { return }

        let frame = layer.convert(layer.bounds, to: rootLayer)
        let visible = frame.intersection(clip)
        // 클리핑으로 완전히 잘려나간 경우 자식도 볼 필요가 없습니다.
        if visible.isNull || visible.isEmpty { return }

        if isDrawn(layer, options: options),
           visible.width >= options.minimumSize,
           visible.height >= options.minimumSize {
            result.append(visible)
        }

        let childClip = layer.masksToBounds ? visible : clip
        for sublayer in layer.sublayers ?? [] {
            collect(
                layer: sublayer,
                rootLayer: rootLayer,
                clip: childClip,
                options: options,
                into: &result
            )
        }
    }

    /// 실제로 픽셀을 그리는 레이어인지 판정합니다.
    /// 클래스 이름은 iOS 버전마다 달라지므로 그리기 속성만 봅니다.
    private static func isDrawn(_ layer: CALayer, options: Options) -> Bool {
        if let background = layer.backgroundColor, background.alpha > 0.01 {
            return true
        }
        if layer.borderWidth > 0, let border = layer.borderColor, border.alpha > 0.01 {
            return true
        }
        if let shape = layer as? CAShapeLayer, shape.path != nil {
            if let fill = shape.fillColor, fill.alpha > 0.01 { return true }
            if let stroke = shape.strokeColor, stroke.alpha > 0.01, shape.lineWidth > 0 { return true }
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
        _ rects: [CGRect],
        rootBounds: CGRect,
        options: Options
    ) -> [CGRect] {
        var result: [CGRect] = []
        for rect in rects {
            // 루트 전체와 같은 크기는 rootBounds가 대신하므로 제외합니다.
            if isNearlyEqual(rect, rootBounds, tolerance: options.duplicateTolerance) { continue }
            if result.contains(where: { isNearlyEqual($0, rect, tolerance: options.duplicateTolerance) }) { continue }
            result.append(rect)
        }
        return result
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
