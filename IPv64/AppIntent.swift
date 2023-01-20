//
//  AppIntent.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.01.23.
//

import Foundation
import Intents

class AppIntent {
    
    class func allowSiri() {
        INPreferences.requestSiriAuthorization { status in
            switch status {
            case .notDetermined, .restricted, .denied:
                print("SIRI ERROR!")
            case .authorized:
                print("SIRI OK!")
            }
        }
    }
    
    class func status() {
        let intent = HealthcheckIntent()
        intent.suggestedInvocationPhrase = "Wie ist der Status von gnghmhgmb"
        
        let interaction = INInteraction(intent: intent, response: nil)
        
        interaction.donate { error in
            if let error = error as NSError? {
                print("Interaction donation failed: \(error.localizedDescription)")
            } else {
                print("Interaction successfully donated.")
            }
            
        }
    }
}
