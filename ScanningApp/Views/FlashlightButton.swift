/*
Кнопка включения вспышки
*/

import UIKit
import AVFoundation

@IBDesignable
class FlashlightButton: RoundedButton {
    
    override var isHidden: Bool {
        didSet {
            guard let captureDevice = AVCaptureDevice.default(for: .video), captureDevice.hasTorch else {
                if !isHidden {
                    isHidden = true
                }
                return
            }
            
            if isHidden {
                // отключение
                toggledOn = false
            }
        }
    }
    
    override var toggledOn: Bool {
        didSet {
            // обновление UI
            if toggledOn {
                setTitle("Light On", for: [])
                backgroundColor = .appBlue
            } else {
                setTitle("Light Off", for: [])
                backgroundColor = .appLightBlue
            }
            
            // флажок
            guard let captureDevice = AVCaptureDevice.default(for: .video), captureDevice.hasTorch else {
                if toggledOn {
                    toggledOn = false
                }
                return
            }
            
            do {
                try captureDevice.lockForConfiguration()
                let mode: AVCaptureDevice.TorchMode = toggledOn ? .on : .off
                if captureDevice.isTorchModeSupported(mode) {
                    captureDevice.torchMode = mode
                }
                captureDevice.unlockForConfiguration()
            } catch {
                print("Error while attempting to access flashlight.")
            }
        }
    }
}
