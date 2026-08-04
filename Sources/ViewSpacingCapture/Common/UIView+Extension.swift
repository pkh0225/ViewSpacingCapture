//
//  UIView+Extension.swift
//  ViewSpacingCapture
//
//
import UIKit

// MARK: - CGRect 각 코너별 radius 지원
extension UIView {
    private struct RoundCornerAssociatedKeys {
        static var topLeftRadius: UInt8 = 0
        static var topRightRadius: UInt8 = 0
        static var bottomLeftRadius: UInt8 = 0
        static var bottomRightRadius: UInt8 = 0
    }
    /// XIB에서 코너별로 다른 radius 적용 시 cornerRadius 값을 무시하고 위의 값을 적용
    @IBInspectable public var topLeftRadius: NSNumber? {
        get {
            if let value = objc_getAssociatedObject(self, &RoundCornerAssociatedKeys.topLeftRadius) as? NSNumber {
                return value
            }
            return nil
        }
        set {
            let oldValue = objc_getAssociatedObject(self, &RoundCornerAssociatedKeys.topLeftRadius)
            objc_setAssociatedObject(self, &RoundCornerAssociatedKeys.topLeftRadius, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            setLayerMaskIfNeeded(oldValue: oldValue as? NSNumber, newValue: newValue)
        }
    }
    @IBInspectable public var topRightRadius: NSNumber? {
        get {
            if let value = objc_getAssociatedObject(self, &RoundCornerAssociatedKeys.topRightRadius) as? NSNumber {
                return value
            }
            return nil
        }
        set {
            let oldValue = objc_getAssociatedObject(self, &RoundCornerAssociatedKeys.topRightRadius)
            objc_setAssociatedObject(self, &RoundCornerAssociatedKeys.topRightRadius, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            setLayerMaskIfNeeded(oldValue: oldValue as? NSNumber, newValue: newValue)
        }
    }
    @IBInspectable public var bottomLeftRadius: NSNumber? {
        get {
            if let value = objc_getAssociatedObject(self, &RoundCornerAssociatedKeys.bottomLeftRadius) as? NSNumber {
                return value
            }
            return nil
        }
        set {
            let oldValue = objc_getAssociatedObject(self, &RoundCornerAssociatedKeys.bottomLeftRadius)
            objc_setAssociatedObject(self, &RoundCornerAssociatedKeys.bottomLeftRadius, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            setLayerMaskIfNeeded(oldValue: oldValue as? NSNumber, newValue: newValue)
        }
    }
    @IBInspectable public var bottomRightRadius: NSNumber? {
        get {
            if let value = objc_getAssociatedObject(self, &RoundCornerAssociatedKeys.bottomRightRadius) as? NSNumber {
                return value
            }
            return nil
        }
        set {
            let oldValue = objc_getAssociatedObject(self, &RoundCornerAssociatedKeys.bottomRightRadius)
            objc_setAssociatedObject(self, &RoundCornerAssociatedKeys.bottomRightRadius, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            setLayerMaskIfNeeded(oldValue: oldValue as? NSNumber, newValue: newValue)
        }
    }
    /// 여러 코너의 cornerRadius 값을 변경한 경우, 한 번의 mask만 그리는 operation을 수행하도록 하는 func
    public func setLayerMaskOperation(topLeft: CGFloat = 0, topRight: CGFloat = 0, bottomLeft: CGFloat = 0, bottomRight: CGFloat = 0) {
        objc_setAssociatedObject(self, &RoundCornerAssociatedKeys.topLeftRadius, NSNumber(floatLiteral: topLeft), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &RoundCornerAssociatedKeys.topRightRadius, NSNumber(floatLiteral: topRight), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &RoundCornerAssociatedKeys.bottomLeftRadius, NSNumber(floatLiteral: bottomLeft), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &RoundCornerAssociatedKeys.bottomRightRadius, NSNumber(floatLiteral: bottomRight), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        setLayerMask()
    }
    /// 런타임에서 특정 코너의 cornerRadius 값을 변경하는 경우, 값이 바뀌어야만 masking을 하도록 만든 func
    private func setLayerMaskIfNeeded<T>(oldValue: T?, newValue: T?) where T: NSNumber {
        guard let oldValue, oldValue.isEqual(to: newValue ?? NSNumber(floatLiteral: 0)) else { return }
        setLayerMask()
    }
    /// layer의 mask를 graphic operation 으로 (GPU 가속을 이용하여) 그리는 공통 func
    private func setLayerMask() {
        //    let maskPath = UIBezierPath(shouldRoundRect: bounds, topLeftRadius: topLeftRadius, topRightRadius: topRightRadius, bottomLeftRadius: bottomLeftRadius, bottomRightRadius: bottomRightRadius)
        //    let shape = CAShapeLayer()
        //    shape.path = maskPath.cgPath
        //    layer.mask = shape
        //
        // AS-IS : UIBezierPath 는 CPU를 사용하여 그리므로 퍼포먼스 저하가 있으므로 아래와 같이 개선 by. iSunSoo.
//        self.layer.addCornerRadiusClosure { [weak self] newValue, oldValue in
//            guard let self else { return }
//            self.layer.mask = nil
//            self.layer.updateSublayersMask()
//        }

        let cornerSize = (topLeft: CGSize(width: topLeftRadius?.doubleValue ?? 0, height: topLeftRadius?.doubleValue ?? 0),
                          topRight: CGSize(width: topRightRadius?.doubleValue ?? 0, height: topRightRadius?.doubleValue ?? 0),
                          bottomLeft: CGSize(width: bottomLeftRadius?.doubleValue ?? 0, height: bottomLeftRadius?.doubleValue ?? 0),
                          bottomRight: CGSize(width: bottomRightRadius?.doubleValue ?? 0, height: bottomRightRadius?.doubleValue ?? 0))
        layer.mask = layer.makeLayer(type: CAShapeLayer.self)
            .roundedMask(topLeft: cornerSize.topLeft,
                         topRight: cornerSize.topRight,
                         bottomLeft: cornerSize.bottomLeft,
                         bottomRight: cornerSize.bottomRight)
        clipsToBounds = true
        layer.masksToBounds = true
        setNeedsDisplay()
        // TO-BE : INPUT -> OUTPUT 흐름 (layer.mask = CALayer -> CAShapeLayer (init & setFrame) -> CAShapeLayer (setPath))
    }
}

// MARK: - sublayer 관리용 extension
private extension CALayer {
    /// 🏭 name과 Type으로 CALayer를 상속받는 레이어를 생성하는 팩토리 메서드
    func makeLayer<T: CALayer>(by name: String? = nil, type: T.Type) -> T {
        let layer = T()
        layer.frame = self.bounds
        layer.masksToBounds = self.masksToBounds
        layer.needsDisplayOnBoundsChange = self.needsDisplayOnBoundsChange
        layer.name = name
        // 기본적으로 shouldRasterize, drawsAsynchronously 사용하지 않습니다. (원래 default가 false)
        // 애니메이션되는 뷰가 없는게 더 많으면 factory 메서드로 기능 제공할지는 고민해보겠습니다. by. iSunSoo.
        return layer
    }
}

private extension CAShapeLayer {
    func roundedMask(cornerRadius r: CGFloat = 0,
                            topLeft: CGSize = .zero,
                            topRight: CGSize = .zero,
                            bottomLeft: CGSize = .zero,
                            bottomRight: CGSize = .zero) -> Self {
        /// 내부에서 사용하는 실질 곡률 반지름 구하는 메서드
        func radius(with size: CGSize, _ cornerRadius: CGFloat = 0) -> CGSize {
            if cornerRadius > 0 {
                return CGSize(width: cornerRadius, height: cornerRadius)
            }
            else if size.width > 0, size.height > 0 {
                return size
            }
            // radius는 어느 하나라도 0이면 곡선이 될 수 없다.
            return .zero
        }
        // 1 ➡️ 2 ➡️ 3 ➡️ 4사분면 순서로 path 따줍니다. 편의를 위해 사각형 모퉁이 좌표는 상수로 땁니다.
        // addArc 아니고 addCurve 땄는데 곡선형이 cornerRadius와 조금 다르면 addArc로 수정 예정입니다.
        // 타원형으로 라운딩을 적용하려면 width와 height을 다르게 주면 됩니다. 기본은 라운딩으로 같은 값을 씁니다.
        // 필요 시 공통파트에 요청하면 eclipse 전용으로도 스펙 만들어 개발 필요하니 요청하세요! by. iSunSoo.
        let topRightPoint = CGPoint(x: frame.maxX, y: frame.minY) // 1사분면 좌표
        let topLeftPoint = CGPoint(x: frame.minX, y: frame.minY) // 2사분면 좌표
        let bottomLeftPoint = CGPoint(x: frame.minX, y: frame.maxY) // 3사분면 좌표
        let bottomRightPoint = CGPoint(x: frame.maxX, y: frame.maxY) // 4사분면 좌표
        let path = CGMutablePath()
        path.move(to: CGPoint(x: topRightPoint.x - radius(with: topRight, r).width, y: topRightPoint.y))
        path.addLine(to: CGPoint(x: topLeftPoint.x + radius(with: topLeft, r).width, y: topLeftPoint.y))
        if radius(with: topLeft, r) != .zero {
            let nextPathPoint = CGPoint(x: topLeftPoint.x, y: topLeftPoint.y + radius(with: topLeft, r).height)
            path.addArcOrCurve(with: radius(with: topLeft, r), controlPoint: topLeftPoint, nextPoint: nextPathPoint)
        }
        path.addLine(to: CGPoint(x: bottomLeftPoint.x, y: bottomLeftPoint.y - radius(with: bottomLeft, r).height))
        if radius(with: bottomLeft, r) != .zero {
            let nextPathPoint = CGPoint(x: bottomLeftPoint.x + radius(with: bottomLeft, r).width, y: bottomLeftPoint.y)
            path.addArcOrCurve(with: radius(with: bottomLeft, r), controlPoint: bottomLeftPoint, nextPoint: nextPathPoint)
        }
        path.addLine(to: CGPoint(x: bottomRightPoint.x - radius(with: bottomRight, r).width, y: bottomRightPoint.y))
        if radius(with: bottomRight, r) != .zero {
            let nextPathPoint = CGPoint(x: bottomRightPoint.x, y: bottomRightPoint.y - radius(with: bottomRight, r).height)
            path.addArcOrCurve(with: radius(with: bottomRight, r), controlPoint: bottomRightPoint, nextPoint: nextPathPoint)
        }
        path.addLine(to: CGPoint(x: topRightPoint.x, y: topRightPoint.y + radius(with: topRight, r).height))
        if radius(with: topRight, r) != .zero {
            let nextPathPoint = CGPoint(x: topRightPoint.x - radius(with: topRight, r).width, y: topRightPoint.y)
            path.addArcOrCurve(with: radius(with: topRight, r), controlPoint: topRightPoint, nextPoint: nextPathPoint)
        }
        path.closeSubpath()
        self.path = path
        return self
    }
}

private extension CGMutablePath {
    /// ⭕️ 부드러운 라운딩을 위한 보정 함수. 원을 부드럽게 그릴 때 두 접선에 내접하는 곡선을 그려준다.
    func addArcOrCurve(with size: CGSize, controlPoint: CGPoint, nextPoint: CGPoint) {
        if size.width == size.height {
            // cornerRadius 적용 시 두 선이 직선으로 접선이 되어야 하는데, 이 계산값은 아래와 같음.
            // 첫번째와 두번째 tanΘ 모두 밑변 r, 높이 r 이다. 즉 Θ = 45도, 이 45도가 맞는 지점
            // 첫번쨰 arctanΘ 값이 될 좌표 : Rect의 모퉁이가 되는 좌표
            // 두번째 arctanΘ 값이 될 좌표 : Rect의 직선과 내접하는 원이 만나는 좌표
            // 계산이 틀려서 라운딩 이상하게 표현 시 제보 주세요! by. iSunSoo.
            self.addArc(tangent1End: controlPoint, tangent2End: nextPoint, radius: size.width)
        }
        else {
            self.addCurve(to: nextPoint, control1: controlPoint, control2: nextPoint)
        }
    }
}
