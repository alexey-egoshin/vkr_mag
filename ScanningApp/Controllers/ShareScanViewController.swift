/*
Интерфейс таблицы сканированных объектов
*/

import UIKit

class ShareScanViewController: UIActivityViewController {
    
    init(sourceView: UIView, sharedObject: Any) {
        super.init(activityItems: [sharedObject], applicationActivities: nil)
        
        // Стиль модального окна
        modalPresentationStyle = .popover
        popoverPresentationController?.sourceView = sourceView
        popoverPresentationController?.sourceRect = sourceView.bounds
        
        self.excludedActivityTypes = [.markupAsPDF, .openInIBooks, .message, .print,
                                      .addToReadingList, .saveToCameraRoll, .assignToContact,
                                      .copyToPasteboard, .postToTencentWeibo, .postToWeibo,
                                      .postToVimeo, .postToFlickr, .postToTwitter, .postToFacebook]
    }
    
    deinit {
        // Рестарт сессии
        if let configuration = ViewController.instance?.sceneView.session.configuration,
            ViewController.instance?.state == .testing {
            ViewController.instance?.sceneView.session.run(configuration)
        }
    }
}
