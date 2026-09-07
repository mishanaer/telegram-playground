import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData

public final class WarpView: UIView {
    private final class WarpPartView: UIView {
        let cloneView: PortalView
        
        init?(contentView: PortalSourceView) {
            guard let cloneView = PortalView(matchPosition: false) else {
                return nil
            }
            self.cloneView = cloneView
            
            super.init(frame: CGRect())
            
            self.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            
            self.clipsToBounds = true
            self.addSubview(cloneView.view)
            contentView.addPortal(view: cloneView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func cloneFrame(containerSize: CGSize, rect: CGRect) -> CGRect {
            return CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: CGSize(width: containerSize.width, height: containerSize.height))
        }
        
        func update(containerSize: CGSize, rect: CGRect, transition: ComponentTransition) {
            transition.setFrame(view: self.cloneView.view, frame: self.cloneFrame(containerSize: containerSize, rect: rect))
        }
        
        func update(containerSize: CGSize, rect: CGRect, layoutTransition: ContainedViewLayoutTransition) {
            layoutTransition.updateFrame(view: self.cloneView.view, frame: self.cloneFrame(containerSize: containerSize, rect: rect))
        }
    }
    
    public let contentView: PortalSourceView
    
    private let clippingView: UIView
    
    private var warpViews: [WarpPartView] = []
    private let warpMaskContainer: UIView
    private let warpMaskGradientLayer: SimpleGradientLayer
    
    public override init(frame: CGRect) {
        self.contentView = PortalSourceView()
        self.clippingView = UIView()
        
        self.warpMaskContainer = UIView()
        self.warpMaskGradientLayer = SimpleGradientLayer()
        self.warpMaskContainer.layer.mask = self.warpMaskGradientLayer
        
        super.init(frame: frame)
        
        self.clippingView.addSubview(self.contentView)
        
        self.clippingView.clipsToBounds = true
        self.addSubview(self.clippingView)
        self.addSubview(self.warpMaskContainer)
        
        for _ in 0 ..< 8 {
            if let warpView = WarpPartView(contentView: self.contentView) {
                self.warpViews.append(warpView)
                self.warpMaskContainer.addSubview(warpView)
            }
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private struct Geometry {
        struct Part {
            let position: CGPoint
            let bounds: CGRect
            let transform: CATransform3D
            let rect: CGRect
        }
        let contentFrame: CGRect
        let parts: [Part]
        let clippingPosition: CGPoint
        let clippingBounds: CGRect
        let maskContainerFrame: CGRect
        let gradientFrame: CGRect
        let gradientLocations: [NSNumber]
        let gradientColors: [CGColor]
        let gradientStartPoint: CGPoint
        let gradientEndPoint: CGPoint
    }
    
    /// The emoji keyboard fades the last 6pt of the bend into its own opaque background. Over a glass
    /// sheet that fade shows whatever is behind the sheet, so the picker turns it off: the bend ends
    /// at the screen edge, where no fade is needed.
    public var fadesBottomEdge: Bool = true

    private func geometry(size: CGSize, topInset: CGFloat, warpHeight: CGFloat) -> Geometry {
        let allItemsHeight = warpHeight * 0.5
        var parts: [Geometry.Part] = []
        for i in 0 ..< self.warpViews.count {
            let itemFraction = CGFloat(i + 1) / CGFloat(self.warpViews.count)
            
            let da = CGFloat.pi * 0.5 / CGFloat(self.warpViews.count)
            let alpha = CGFloat.pi * 0.5 - itemFraction * CGFloat.pi * 0.5
            let endPoint = CGPoint(x: cos(alpha), y: sin(alpha))
            let prevAngle = alpha + da
            let prevPt = CGPoint(x: cos(prevAngle), y: sin(prevAngle))
            var angle: CGFloat
            angle = -atan2(endPoint.y - prevPt.y, endPoint.x - prevPt.x)
            
            let itemLengthVector = CGPoint(x: endPoint.x - prevPt.x, y: endPoint.y - prevPt.y)
            let itemLength = sqrt(itemLengthVector.x * itemLengthVector.x + itemLengthVector.y * itemLengthVector.y) * warpHeight * 0.5
            
            var transform: CATransform3D
            transform = CATransform3DIdentity
            transform.m34 = 1.0 / (240.0 * warpHeight / 50.0)
            
            transform = CATransform3DTranslate(transform, 0.0, prevPt.x * allItemsHeight, (1.0 - prevPt.y) * allItemsHeight)
            transform = CATransform3DRotate(transform, angle, 1.0, 0.0, 0.0)
            
            let positionY = size.height - allItemsHeight + 4.0 + CGFloat(i) * itemLength
            let rect = CGRect(origin: CGPoint(x: 0.0, y: positionY), size: CGSize(width: size.width, height: itemLength))
            // Without the fade every row of the bend is visible: slices overlap by 3pt so the seams
            // between them do not show the background (the steep last slices project a 3pt overlap to
            // well under 1pt), and the whole bend sits 2pt lower so its last slices cover the frame's
            // bottom rows (the top rows it leaves are under the flat content).
            let partHeight = itemLength + (self.fadesBottomEdge ? 0.0 : 3.0)
            let partOffsetY: CGFloat = self.fadesBottomEdge ? 4.0 : 6.0
            parts.append(Geometry.Part(
                position: CGPoint(x: rect.midX, y: partOffsetY),
                bounds: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: partHeight)),
                transform: transform,
                rect: rect
            ))
        }
        
        let clippingTopInset: CGFloat = topInset
        let clippingFrame = CGRect(origin: CGPoint(x: 0.0, y: clippingTopInset), size: CGSize(width: size.width, height: -clippingTopInset + size.height - 21.0))
        
        var locations: [NSNumber] = []
        var colors: [CGColor] = []
        let numStops = 6
        for i in 0 ..< numStops {
            let step = CGFloat(i) / CGFloat(numStops - 1)
            locations.append(step as NSNumber)
            colors.append(UIColor.black.withAlphaComponent(self.fadesBottomEdge ? 1.0 - step * step : 1.0).cgColor)
        }
        let gradientHeight: CGFloat = 6.0
        
        return Geometry(
            contentFrame: CGRect(origin: CGPoint(), size: size),
            parts: parts,
            clippingPosition: clippingFrame.center,
            clippingBounds: CGRect(origin: CGPoint(x: 0.0, y: clippingTopInset), size: clippingFrame.size),
            maskContainerFrame: CGRect(origin: CGPoint(x: 0.0, y: size.height - allItemsHeight), size: CGSize(width: size.width, height: allItemsHeight)),
            gradientFrame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: allItemsHeight)),
            gradientLocations: locations,
            gradientColors: colors,
            gradientStartPoint: CGPoint(x: 0.0, y: (allItemsHeight - gradientHeight) / allItemsHeight),
            gradientEndPoint: CGPoint(x: 0.0, y: 1.0)
        )
    }
    
    private func applyGradient(_ geometry: Geometry) {
        self.warpMaskGradientLayer.startPoint = geometry.gradientStartPoint
        self.warpMaskGradientLayer.endPoint = geometry.gradientEndPoint
        self.warpMaskGradientLayer.locations = geometry.gradientLocations
        self.warpMaskGradientLayer.colors = geometry.gradientColors
        self.warpMaskGradientLayer.type = .axial
    }
    
    public func update(size: CGSize, topInset: CGFloat, warpHeight: CGFloat, theme: PresentationTheme, transition: ComponentTransition) {
        let geometry = self.geometry(size: size, topInset: topInset, warpHeight: warpHeight)
        transition.setFrame(view: self.contentView, frame: geometry.contentFrame)
        for (i, part) in geometry.parts.enumerated() {
            transition.setPosition(view: self.warpViews[i], position: part.position)
            transition.setBounds(view: self.warpViews[i], bounds: part.bounds)
            transition.setTransform(view: self.warpViews[i], transform: part.transform)
            self.warpViews[i].update(containerSize: size, rect: part.rect, transition: transition)
        }
        transition.setPosition(view: self.clippingView, position: geometry.clippingPosition)
        transition.setBounds(view: self.clippingView, bounds: geometry.clippingBounds)
        self.clippingView.clipsToBounds = true
        transition.setFrame(view: self.warpMaskContainer, frame: geometry.maskContainerFrame)
        self.applyGradient(geometry)
        transition.setFrame(layer: self.warpMaskGradientLayer, frame: geometry.gradientFrame)
    }
    
    /// Same layout, driven by the exact `ContainedViewLayoutTransition` of the host. Use this when the
    /// host animates its own frame with that transition: `ComponentTransition` cannot carry a
    /// `.customSpring` curve and falls back to a plain spring, so the bend would follow a different
    /// curve than the sheet it sits in and visibly detach from the bottom edge while it settles.
    public func update(size: CGSize, topInset: CGFloat, warpHeight: CGFloat, theme: PresentationTheme, layoutTransition: ContainedViewLayoutTransition) {
        let geometry = self.geometry(size: size, topInset: topInset, warpHeight: warpHeight)
        layoutTransition.updateFrame(view: self.contentView, frame: geometry.contentFrame)
        for (i, part) in geometry.parts.enumerated() {
            layoutTransition.updatePosition(layer: self.warpViews[i].layer, position: part.position)
            layoutTransition.updateBounds(layer: self.warpViews[i].layer, bounds: part.bounds)
            layoutTransition.updateTransform(layer: self.warpViews[i].layer, transform: part.transform)
            self.warpViews[i].update(containerSize: size, rect: part.rect, layoutTransition: layoutTransition)
        }
        layoutTransition.updatePosition(layer: self.clippingView.layer, position: geometry.clippingPosition)
        layoutTransition.updateBounds(layer: self.clippingView.layer, bounds: geometry.clippingBounds)
        self.clippingView.clipsToBounds = true
        layoutTransition.updateFrame(view: self.warpMaskContainer, frame: geometry.maskContainerFrame)
        self.applyGradient(geometry)
        layoutTransition.updateFrame(layer: self.warpMaskGradientLayer, frame: geometry.gradientFrame)
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.contentView.hitTest(point, with: event)
    }
}
