/*
Управление шагами сканирования
*/

import Foundation
import UIKit
import ARKit

class Scan {
    
    static let stateChangedNotification = Notification.Name("ScanningStateChanged")
    static let stateUserInfoKey = "ScanState"
    static let objectCreationInterval: CFTimeInterval = 1.0
    
    enum State {
        case ready
        case defineBoundingBox
        case scanning
        case adjustingOrigin
    }
    
    // текущий шаг
    private var stateValue: State = .ready
    var state: State {
        get {
            return stateValue
        }
        set {
            // проверка условий
            switch newValue {
            case .ready:
                break
            case .defineBoundingBox where !boundingBoxExists && !ghostBoundingBoxExists:
                print("Error: Ghost bounding box not yet created.")
                return
            case .scanning where !boundingBoxExists, .adjustingOrigin where !boundingBoxExists:
                print("Error: Bounding box not yet created.")
                return
            case .scanning where stateValue == .defineBoundingBox && !isReasonablySized,
                 .adjustingOrigin where stateValue == .scanning && !isReasonablySized:
                
                let title = "Scanned object too big or small"
                let message = """
                big object
                """
                let previousState = stateValue
                ViewController.instance?.showAlert(title: title, message: message, buttonTitle: "Yes", showCancel: true) { _ in
                    self.state = previousState
                }
            case .scanning:
                // сохранение фото объекта для превью
                createScreenshot()
            case .adjustingOrigin where stateValue == .scanning && qualityIsLow:
                let title = "Not enough detail"
                let message = """
                This scan has not enough detail (it contains \(pointCloud.count) features - aim for at least \(Scan.minFeatureCount)).
                It is unlikely that a good reference object can be generated.
                Do you want to go back and continue the scan?
                """
                ViewController.instance?.showAlert(title: title, message: message, buttonTitle: "Yes", showCancel: true) { _ in
                    self.state = .scanning
                }
            case .adjustingOrigin where stateValue == .scanning:
                if let boundingBox = scannedObject.boundingBox, boundingBox.progressPercentage < 100 {
                    let title = "Scan not complete"
                    let message = """
                    The object was not scanned from all sides, scanning progress is \(boundingBox.progressPercentage)%.
                    It is likely that it won't detect from all angles.
                    Do you want to go back and continue the scan?
                    """
                    ViewController.instance?.showAlert(title: title, message: message, buttonTitle: "Yes", showCancel: true) { _ in
                        self.state = .scanning
                    }
                }
            default:
                break
            }
            // сохранить состояние
            stateValue = newValue

            NotificationCenter.default.post(name: Scan.stateChangedNotification,
                                            object: self,
                                            userInfo: [Scan.stateUserInfoKey: self.state])
        }
    }
    
    var objectToManipulate: SCNNode? {
        if state == .adjustingOrigin {
            return scannedObject.origin
        } else {
            return scannedObject.eitherBoundingBox
        }
    }
    
    // сканируемый объект
    private(set) var scannedObject: ScannedObject
    
    // скан
    private(set) var scannedReferenceObject: ARReferenceObject?
    
    // визуализация карты объекта по точкам
    private(set) var pointCloud: ScannedPointCloud
    
    private var sceneView: ARSCNView
    
    private var isBusyCreatingReferenceObject = false
    
    private(set) var screenshot = UIImage()
    
    private var hasWarnedAboutLowLight = false
    
    private var isFirstScan: Bool {
        return ViewController.instance?.referenceObjectToMerge == nil
    }
    
    static let minFeatureCount = 100
    
    init(_ sceneView: ARSCNView) {
        self.sceneView = sceneView
        
        scannedObject = ScannedObject(sceneView)
        pointCloud = ScannedPointCloud()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.applicationStateChanged(_:)),
                                               name: ViewController.appStateChangedNotification,
                                               object: nil)
        
        self.sceneView.scene.rootNode.addChildNode(self.scannedObject)
        self.sceneView.scene.rootNode.addChildNode(self.pointCloud)
    }
    
    deinit {
        self.scannedObject.removeFromParentNode()
        self.pointCloud.removeFromParentNode()
    }
    
    @objc
    private func applicationStateChanged(_ notification: Notification) {
        guard let appState = notification.userInfo?[ViewController.appStateUserInfoKey] as? ViewController.State else { return }
        switch appState {
        case .scanning:
            scannedObject.isHidden = false
            pointCloud.isHidden = false
        default:
            scannedObject.isHidden = true
            pointCloud.isHidden = true
        }
    }
    
    func didOneFingerPan(_ gesture: UIPanGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            switch gesture.state {
            case .possible:
                break
            case .began:
                scannedObject.boundingBox?.startSidePlaneDrag(screenPos: gesture.location(in: sceneView))
            case .changed:
                scannedObject.boundingBox?.updateSidePlaneDrag(screenPos: gesture.location(in: sceneView))
            case .failed, .cancelled, .ended:
                scannedObject.boundingBox?.endSidePlaneDrag()
            }
        } else if state == .adjustingOrigin {
            switch gesture.state {
            case .possible:
                break
            case .began:
                scannedObject.origin?.startAxisDrag(screenPos: gesture.location(in: sceneView))
            case .changed:
                scannedObject.origin?.updateAxisDrag(screenPos: gesture.location(in: sceneView))
            case .failed, .cancelled, .ended:
                scannedObject.origin?.endAxisDrag()
            }
        }
    }
    
    func didTwoFingerPan(_ gesture: ThresholdPanGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            switch gesture.state {
            case .possible:
                break
            case .began:
                if gesture.numberOfTouches == 2 {
                    scannedObject.boundingBox?.startGroundPlaneDrag(screenPos: gesture.offsetLocation(in: sceneView))
                }
            case .changed where gesture.isThresholdExceeded:
                if gesture.numberOfTouches == 2 {
                    scannedObject.boundingBox?.updateGroundPlaneDrag(screenPos: gesture.offsetLocation(in: sceneView))
                }
            case .changed:
                break
            case .failed, .cancelled, .ended:
                scannedObject.boundingBox?.endGroundPlaneDrag()
            }
        } else if state == .adjustingOrigin {
            switch gesture.state {
            case .possible:
                break
            case .began:
                if gesture.numberOfTouches == 2 {
                    scannedObject.origin?.startPlaneDrag(screenPos: gesture.offsetLocation(in: sceneView))
                }
            case .changed where gesture.isThresholdExceeded:
                if gesture.numberOfTouches == 2 {
                    scannedObject.origin?.updatePlaneDrag(screenPos: gesture.offsetLocation(in: sceneView))
                }
            case .changed:
                break
            case .failed, .cancelled, .ended:
                scannedObject.origin?.endPlaneDrag()
            }
        }
    }
    
    func didRotate(_ gesture: ThresholdRotationGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            if gesture.state == .changed {
                scannedObject.rotateOnYAxis(by: -Float(gesture.rotationDelta))
            }
        } else if state == .adjustingOrigin {
            if gesture.state == .changed {
                scannedObject.origin?.rotateWithSnappingOnYAxis(by: -Float(gesture.rotationDelta))
            }
        }
    }
    
    func didLongPress(_ gesture: UILongPressGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            switch gesture.state {
            case .possible:
                break
            case .began:
                scannedObject.boundingBox?.startSideDrag(screenPos: gesture.location(in: sceneView))
            case .changed:
                scannedObject.boundingBox?.updateSideDrag(screenPos: gesture.location(in: sceneView))
            case .failed, .cancelled, .ended:
                scannedObject.boundingBox?.endSideDrag()
            }
        } else if state == .adjustingOrigin {
            switch gesture.state {
            case .possible:
                break
            case .began:
                scannedObject.origin?.startAxisDrag(screenPos: gesture.location(in: sceneView))
            case .changed:
                scannedObject.origin?.updateAxisDrag(screenPos: gesture.location(in: sceneView))
            case .failed, .cancelled, .ended:
                scannedObject.origin?.endAxisDrag()
            }
        }
    }
    
    func didTap(_ gesture: UITapGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            if gesture.state == .ended {
                scannedObject.createOrMoveBoundingBox(screenPos: gesture.location(in: sceneView))
            }
        } else if state == .adjustingOrigin {
            if gesture.state == .ended {
                scannedObject.origin?.flashOrReposition(screenPos: gesture.location(in: sceneView))
            }
        }
    }
    
    func didPinch(_ gesture: ThresholdPinchGestureRecognizer) {
        if state == .ready {
            state = .defineBoundingBox
        }
        
        if state == .defineBoundingBox || state == .scanning {
            switch gesture.state {
            case .possible, .began:
                break
            case .changed where gesture.isThresholdExceeded:
                scannedObject.scaleBoundingBox(scale: gesture.scale)
                gesture.scale = 1
            case .changed:
                break
            case .failed, .cancelled, .ended:
                break
            }
        } else if state == .adjustingOrigin {
            switch gesture.state {
            case .possible, .began:
                break
            case .changed where gesture.isThresholdExceeded:
                scannedObject.origin?.updateScale(Float(gesture.scale))
                gesture.scale = 1
            case .changed, .failed, .cancelled, .ended:
                break
            }
        }
    }
    
    func updateOnEveryFrame(_ frame: ARFrame) {
        if state == .ready || state == .defineBoundingBox {
            if let points = frame.rawFeaturePoints {
                // подгон размера
                self.scannedObject.fitOverPointCloud(points)
            }
        }
        
        if state == .ready || state == .defineBoundingBox || state == .scanning {
            
            if let lightEstimate = frame.lightEstimate, lightEstimate.ambientIntensity < 500, !hasWarnedAboutLowLight, isFirstScan {
                hasWarnedAboutLowLight = true
                let title = "Too dark for scanning"
                let message = "Consider moving to an environment with more light."
                ViewController.instance?.showAlert(title: title, message: message)
            }
            
            if let boundingBox = scannedObject.eitherBoundingBox {
                let now = CACurrentMediaTime()
                if now - timeOfLastReferenceObjectCreation > Scan.objectCreationInterval, !isBusyCreatingReferenceObject {
                    timeOfLastReferenceObjectCreation = now
                    isBusyCreatingReferenceObject = true
                    sceneView.session.createReferenceObject(transform: boundingBox.simdWorldTransform,
                                                            center: float3(),
                                                            extent: boundingBox.extent) { object, error in
                        if let referenceObject = object {
                            // Pass the feature points to the point cloud visualization.
                            self.pointCloud.update(with: referenceObject.rawFeaturePoints, localFor: boundingBox)
                        }
                        self.isBusyCreatingReferenceObject = false
                    }
                }
                
                // обновление облака точек
                if let currentPoints = frame.rawFeaturePoints {
                    pointCloud.update(with: currentPoints)
                }
            }
        }
        
        // обновление сканбокса
        if state == .scanning {
            scannedObject.boundingBox?.highlightCurrentTile()
            scannedObject.boundingBox?.updateCapturingProgress()
        }
        
        scannedObject.updateOnEveryFrame()
        pointCloud.updateOnEveryFrame()
    }
    
    var timeOfLastReferenceObjectCreation = CACurrentMediaTime()
    
    var qualityIsLow: Bool {
        return pointCloud.count < Scan.minFeatureCount
    }
    
    var boundingBoxExists: Bool {
        return scannedObject.boundingBox != nil
    }
    
    var ghostBoundingBoxExists: Bool {
        return scannedObject.ghostBoundingBox != nil
    }
    
    var isReasonablySized: Bool {
        guard let boundingBox = scannedObject.boundingBox else {
            return false
        }
        
        // проверка на размер поддерживаемый ARKit и количество точек
        let validSizeRange: ClosedRange<Float> = 0.01...5.0
        if validSizeRange.contains(boundingBox.extent.x) && validSizeRange.contains(boundingBox.extent.y) &&
            validSizeRange.contains(boundingBox.extent.z) {
            let volume = boundingBox.extent.x * boundingBox.extent.y * boundingBox.extent.z
            return volume >= 0.0005
        }
        
        return false
    }
    
    /// - Tag: ExtractReferenceObject
    func createReferenceObject(completionHandler creationFinished: @escaping (ARReferenceObject?) -> Void) {
        guard let boundingBox = scannedObject.boundingBox, let origin = scannedObject.origin else {
            print("Error: No bounding box or object origin present.")
            creationFinished(nil)
            return
        }
        
        // получение положения объекта
        sceneView.session.createReferenceObject(
            transform: boundingBox.simdWorldTransform,
            center: float3(), extent: boundingBox.extent,
            completionHandler: { object, error in
                if let referenceObject = object {
                    // выбор объекта
                    self.scannedReferenceObject = referenceObject.applyingTransform(origin.simdTransform)
                    self.scannedReferenceObject!.name = self.scannedObject.scanName
                    
                    if let referenceObjectToMerge = ViewController.instance?.referenceObjectToMerge {
                        ViewController.instance?.referenceObjectToMerge = nil
                        
                        // activity слияния сканов
                        ViewController.instance?.showAlert(title: "", message: "Merging previous scan into this scan...", buttonTitle: nil)
                        
                        // если скан один
                        self.scannedReferenceObject?.mergeInBackground(with: referenceObjectToMerge, completion: { (mergedObject, error) in

                            if let mergedObject = mergedObject {
                                self.scannedReferenceObject = mergedObject
                                ViewController.instance?.showAlert(title: "Merge successful",
                                                                   message: "The previous scan has been merged into this scan.", buttonTitle: "OK")
                                creationFinished(self.scannedReferenceObject)

                            } else {
                                print("Error: Failed to merge scans. \(error?.localizedDescription ?? "")")
                                let message = """
                                        Merging the previous scan into this scan failed.
                                        """
                                let thisScan = UIAlertAction(title: "Use This Scan", style: .default) { _ in
                                    creationFinished(self.scannedReferenceObject)
                                }
                                let previousScan = UIAlertAction(title: "Use Previous Scan", style: .default) { _ in
                                    self.scannedReferenceObject = referenceObjectToMerge
                                    creationFinished(self.scannedReferenceObject)
                                }
                                ViewController.instance?.showAlert(title: "Merge failed", message: message, actions: [thisScan, previousScan])
                            }
                        })
                    } else {
                        creationFinished(self.scannedReferenceObject)
                    }
                } else {
                    print("Error: Failed to create reference object. \(error!.localizedDescription)")
                    creationFinished(nil)
                }
        })
    }
    
    private func createScreenshot() {
        guard let frame = self.sceneView.session.currentFrame else {
            print("Error: Failed to create a screenshot - no current ARFrame exists.")
            return
        }

        var orientation: UIImage.Orientation = .right
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = .right
        case .portraitUpsideDown:
            orientation = .left
        case .landscapeLeft:
            orientation = .up
        case .landscapeRight:
            orientation = .down
        default:
            break
        }
        
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let context = CIContext()
        if let cgimage = context.createCGImage(ciImage, from: ciImage.extent) {
            screenshot = UIImage(cgImage: cgimage, scale: 1.0, orientation: orientation)
        }
    }
}
