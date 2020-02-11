
import Foundation
import ARKit
import SceneKit

class ScannedPointCloud: SCNNode, PointCloud {
    
    private var pointNode = SCNNode()
    private var preliminaryPointsNode = SCNNode()

    private var referenceObjectPoints: [float3] = []
    private var currentFramePoints: [float3] = []
    
    private var renderedPoints: [float3] = []
    private var renderedPreliminaryPoints: [float3] = []
    
    private var boundingBox: BoundingBox?
    
    override init() {
        super.init()
        
        addChildNode(pointNode)
        addChildNode(preliminaryPointsNode)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.scanningStateChanged(_:)),
                                               name: Scan.stateChangedNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.boundingBoxPositionOrExtentChanged(_:)),
                                               name: BoundingBox.extentChangedNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.boundingBoxPositionOrExtentChanged(_:)),
                                               name: BoundingBox.positionChangedNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.scannedObjectPositionChanged(_:)),
                                               name: ScannedObject.positionChangedNotification,
                                               object: nil)
    }
    
    @objc
    func boundingBoxPositionOrExtentChanged(_ notification: Notification) {
        guard let boundingBox = notification.object as? BoundingBox else { return }
        updateBoundingBox(boundingBox)
    }
    
    @objc
    func scannedObjectPositionChanged(_ notification: Notification) {
        guard let scannedObject = notification.object as? ScannedObject else { return }
        let boundingBox = scannedObject.boundingBox != nil ? scannedObject.boundingBox : scannedObject.ghostBoundingBox
        updateBoundingBox(boundingBox)
    }
    
    func updateBoundingBox(_ boundingBox: BoundingBox?) {
        self.boundingBox = boundingBox
    }
    
    func update(with pointCloud: ARPointCloud, localFor boundingBox: BoundingBox) {
        var pointsInWorld: [float3] = []
        for point in pointCloud.points {
            pointsInWorld.append(boundingBox.simdConvertPosition(point, to: nil))
        }
        
        self.referenceObjectPoints = pointsInWorld
    }
    
    func update(with pointCloud: ARPointCloud) {
        self.currentFramePoints = pointCloud.points
    }
    
    func updateOnEveryFrame() {
        guard !self.isHidden else { return }
        guard !referenceObjectPoints.isEmpty, let boundingBox = boundingBox else {
            self.pointNode.geometry = nil
            self.preliminaryPointsNode.geometry = nil
            return
        }
        
        renderedPoints = []
        renderedPreliminaryPoints = []
        guard boundingBox.extent.x > 0 else { return }
        self.pointNode.geometry = createVisualization(for: renderedPoints, color: .appYellow, size: 12)
        self.preliminaryPointsNode.geometry = createVisualization(for: renderedPreliminaryPoints, color: .appLightYellow, size: 12)
    }
    
    var count: Int {
        return renderedPoints.count
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    private func scanningStateChanged(_ notification: Notification) {
        guard let state = notification.userInfo?[Scan.stateUserInfoKey] as? Scan.State else { return }
        switch state {
        case .ready, .scanning, .defineBoundingBox:
            self.isHidden = false
        case .adjustingOrigin:
            self.isHidden = true
        }
    }
}
