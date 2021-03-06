/*
авторегулировка сканбокса (пока не очень работает)
*/

import Foundation
import ARKit

class DetectedBoundingBox: SCNNode {
    
    init(points: [float3], scale: CGFloat, color: UIColor = .appYellow) {
        super.init()
        
        var localMin = float3(Float.greatestFiniteMagnitude)
        var localMax = float3(-Float.greatestFiniteMagnitude)
        
        for point in points {
            localMin = min(localMin, point)
            localMax = max(localMax, point)
        }
        
        self.simdPosition += (localMax + localMin) / 2
        let extent = localMax - localMin
        let wireframe = Wireframe(extent: extent, color: color, scale: scale)
        self.addChildNode(wireframe)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
