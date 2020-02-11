/*
жест поворота
*/
import UIKit.UIGestureRecognizerSubclass

class ThresholdRotationGestureRecognizer: UIRotationGestureRecognizer {
    
    /// порог поворота
    private static let threshold: CGFloat = .pi / 15 // (12°)
    
    /// отображает превышен ли порог
    private(set) var isThresholdExceeded = false
    
    var previousRotation: CGFloat = 0
    var rotationDelta: CGFloat = 0
    
    /// наблюдатель изменяет состояние
    override var state: UIGestureRecognizer.State {
        didSet {
            switch state {
            case .began, .changed:
                break
            default:
                // Reset threshold check.
                isThresholdExceeded = false
                previousRotation = 0
                rotationDelta = 0
            }
        }
    }
//    иницирует передвижение
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if isThresholdExceeded {
            rotationDelta = rotation - previousRotation
            previousRotation = rotation
        }
        
        if !isThresholdExceeded && abs(rotation) > ThresholdRotationGestureRecognizer.threshold {
            isThresholdExceeded = true
            previousRotation = rotation
        }
    }
}
