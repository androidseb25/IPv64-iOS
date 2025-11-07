//
//  Tips.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 30.10.25.
//


import TipKit

struct HcActionTip: Tip {
    var title: Text {
        Text("Swipe for action")
    }
    var message: Text? {
        Text("Swipe on a Healthcheck to do delete or start/pause the Healthcheck")
    }
    var image: Image? {
        Image(systemName: "appwindow.swipe.rectangle")
    }
}
