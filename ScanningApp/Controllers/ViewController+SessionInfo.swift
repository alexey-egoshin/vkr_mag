import UIKit
import ARKit

extension ViewController {
    
    func updateSessionInfoLabel(for trackingState: ARCamera.TrackingState) {
        // Обновление интерфейса после действий
        var message: String = ""
        let stateString = state == .testing ? "Detecting" : "Scanning"
        
        switch trackingState {
            
        case .notAvailable:
            message = "\(stateString) not possible: \(trackingState.presentationString)"
            startTimeOfLastMessage = Date().timeIntervalSince1970
            expirationTimeOfLastMessage = 3.0
            
        case .limited:
            message = "\(stateString) might not work: \(trackingState.presentationString)"
            startTimeOfLastMessage = Date().timeIntervalSince1970
            expirationTimeOfLastMessage = 3.0
            
        default:
//             Когда трекинг не готов - сообщение не нужно
//             Трекинг осуществлен - нужно отобразить статистику
            let now = Date().timeIntervalSince1970
            if let startTimeOfLastMessage = startTimeOfLastMessage,
                let expirationTimeOfLastMessage = expirationTimeOfLastMessage,
                now - startTimeOfLastMessage < expirationTimeOfLastMessage {
                let timeToKeepLastMessageOnScreen = expirationTimeOfLastMessage - (now - startTimeOfLastMessage)
                startMessageExpirationTimer(duration: timeToKeepLastMessageOnScreen)
            } else {
                // Скрытие статистики по распознаванию
                self.sessionInfoLabel.text = ""
                self.sessionInfoView.isHidden = true
            }
            return
        }
        
        sessionInfoLabel.text = message
        sessionInfoView.isHidden = false
    }
    
    func displayMessage(_ message: String, expirationTime: TimeInterval) {
        startTimeOfLastMessage = Date().timeIntervalSince1970
        expirationTimeOfLastMessage = expirationTime
        DispatchQueue.main.async {
            self.sessionInfoLabel.text = message
            self.sessionInfoView.isHidden = false
            self.startMessageExpirationTimer(duration: expirationTime)
        }
    }
    
    func startMessageExpirationTimer(duration: TimeInterval) {
        cancelMessageExpirationTimer()
        
        messageExpirationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { (timer) in
            self.cancelMessageExpirationTimer()
            self.sessionInfoLabel.text = ""
            self.sessionInfoView.isHidden = true
            
            self.startTimeOfLastMessage = nil
            self.expirationTimeOfLastMessage = nil
        }
    }
    
    func cancelMessageExpirationTimer() {
        messageExpirationTimer?.invalidate()
        messageExpirationTimer = nil
    }
}
