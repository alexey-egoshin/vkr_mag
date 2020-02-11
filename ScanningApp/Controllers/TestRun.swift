/*
Трекинг сканированного объекта
*/

import Foundation
import ARKit

// класс тестового распознавания
class TestRun {
//    распознаваемый объект
    var referenceObject: ARReferenceObject?
    
    private(set) var detectedObject: DetectedObject?
    
    var detections = 0
    var lastDetectionDelayInSeconds: Double = 0
    var averageDetectionDelayInSeconds: Double = 0
    
    var resultDisplayDuration: Double {
        // вывод задержки
        return averageDetectionDelayInSeconds + 0.2
    }
    
    private var lastDetectionStartTime: Date?
    
    private var sceneView: ARSCNView
    
    private(set) var previewImage = UIImage()
    
    init(sceneView: ARSCNView) {
        self.sceneView = sceneView
    }
    
    deinit {
        self.detectedObject?.removeFromParentNode()
        
        if self.sceneView.session.configuration as? ARWorldTrackingConfiguration != nil {
            // проверка распозналось ли
            let configuration = ARObjectScanningConfiguration()
            configuration.planeDetection = .horizontal
            self.sceneView.session.run(configuration, options: .resetTracking)
        }
    }
    
    var statistics: String {
        let lastDelayMilliseconds = String(format: "%.0f", lastDetectionDelayInSeconds * 1000)
        let averageDelayMilliseconds = String(format: "%.0f", averageDetectionDelayInSeconds * 1000)
        return "Detected after: \(lastDelayMilliseconds) ms. Avg: \(averageDelayMilliseconds) ms"
    }
    
    func setReferenceObject(_ object: ARReferenceObject, screenshot: UIImage?) {
        referenceObject = object
        if let screenshot = screenshot {
            previewImage = screenshot
        }
        detections = 0
        lastDetectionDelayInSeconds = 0
        averageDetectionDelayInSeconds = 0
        
        self.detectedObject = DetectedObject(referenceObject: object)
        self.sceneView.scene.rootNode.addChildNode(self.detectedObject!)
        
        self.lastDetectionStartTime = Date()
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionObjects = [object]
        self.sceneView.session.run(configuration)
        
        startNoDetectionTimer()
    }
    
    func successfulDetection(_ objectAnchor: ARObjectAnchor) {
        
        // расчет времени трекинга
        lastDetectionDelayInSeconds = Date().timeIntervalSince(self.lastDetectionStartTime!)
        detections += 1
        averageDetectionDelayInSeconds = (averageDetectionDelayInSeconds * Double(detections - 1) + lastDetectionDelayInSeconds) / Double(detections)
        
        // задержка
        self.detectedObject?.displayDuration = resultDisplayDuration
        
        // повторное распознавание 
        self.lastDetectionStartTime = Date()
        self.sceneView.session.remove(anchor: objectAnchor)
        
        if let currentPointCloud = self.sceneView.session.currentFrame?.rawFeaturePoints {
            self.detectedObject?.updateVisualization(newTransform: objectAnchor.transform,
                                                     currentPointCloud: currentPointCloud)
        }
        
        startNoDetectionTimer()
    }
    
    func updateOnEveryFrame() {
        if let detectedObject = self.detectedObject {
            if let currentPointCloud = self.sceneView.session.currentFrame?.rawFeaturePoints {
                detectedObject.updatePointCloud(currentPointCloud)
            }
        }
    }
    
    var noDetectionTimer: Timer?
    
    func startNoDetectionTimer() {
        cancelNoDetectionTimer()
        noDetectionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            self.cancelNoDetectionTimer()
            ViewController.instance?.displayMessage("""
                Unable to detect the object.
                Please point the device at the scanned object, rescan or add another scan
                of this object in the current environment.
                """, expirationTime: 5.0)
        }
    }
    
    func cancelNoDetectionTimer() {
        noDetectionTimer?.invalidate()
        noDetectionTimer = nil
    }
}
