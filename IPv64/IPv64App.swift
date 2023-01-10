//
//  IPv64App.swift
//  IPv64
//
//  Created by Sebastian Rank on 06.11.22.
//

import SwiftUI

@main
struct IPv64App: App {
    
    init() {
        var titleFont = UIFont.preferredFont(forTextStyle: .largeTitle) /// the default large title font
        titleFont = UIFont(
            descriptor:
                titleFont.fontDescriptor
                .withDesign(.rounded)? /// make rounded
                .withSymbolicTraits(.traitBold) /// make bold
            ??
            titleFont.fontDescriptor, /// return the normal title if customization failed
            size: titleFont.pointSize
        )
        
        var smallTitleFont = UIFont.preferredFont(forTextStyle: .body) /// the default large title font
        smallTitleFont = UIFont(
            descriptor:
                smallTitleFont.fontDescriptor
                .withDesign(.rounded)? /// make rounded
                .withSymbolicTraits(.traitBold) /// make bold
            ??
            smallTitleFont.fontDescriptor, /// return the normal title if customization failed
            size: smallTitleFont.pointSize
        )
        
        /// set the rounded font
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: titleFont]
        UINavigationBar.appearance().titleTextAttributes = [.font : smallTitleFont]
    }
    
    var body: some Scene {
        WindowGroup {
            let apikey = SetupPrefs.readPreference(mKey: "APIKEY", mDefaultValue: "") as! String
            if (apikey.count == 0) {
                LoginView()
            } else {
                TabbView()
            }
        }
    }
}
