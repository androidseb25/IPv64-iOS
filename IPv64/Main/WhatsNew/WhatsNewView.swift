//
//  WhatsNewView.swift
//  Treibholz
//
//  Created by Sebastian Rank on 16.02.22.
//

import SwiftUI

struct WhatsNewView: View {
    @Binding var activeSheet: ActiveSheet?
    @Binding var isPresented: Bool
    var isFromSetting = false
    
    var whatsNewList = [
        WhatsNewObj(imageName: "ant.circle", title: "Fehlerbehebung", subtitle: "Es wurden in diesem Update ein Paar Fehler behoben, die zur Steigerung der Performance und der Nutzbarkeit dienen"),
        WhatsNewObj(imageName: "rectangle.3.group.fill", title: "Widgets konfigurierbar (beta)", subtitle: "Das kleine Widget & das Lockscreen Widget kann jetzt mit einen beliebigen Healthcheck konfiguriert werden"),
        WhatsNewObj(imageName: "platter.2.filled.iphone", title: "Lockscreen Widget", subtitle: "Es gibt jetzt ein Lockscreen Widgets, welches konfigriert werden kann")
    ]
    
    var body: some View {
        VStack {
            VStack {
                Text("Was ist neu in")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("v\(Bundle.main.versionNumber)?")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 27.5)
            
            Spacer()
            
            ScrollView {
                ForEach(whatsNewList, id: \.id) { item in
                    WhatsNewItemView(whatsNewItem: item)
                }
            }
            
            Button(action: {
                withAnimation {
                    let buildNumber = Bundle.main.buildNumber
                    SetupPrefs.setPreference(mKey: "LASTBUILDNUMBER", mValue: buildNumber)
                    activeSheet = nil
                }
            }) {
                Text(isFromSetting ? "Schließen" : "Fortfahren").font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 50, idealHeight: 50, maxHeight: 50, alignment: .center)
                    .background(Color("ip64_color"))
                    .cornerRadius(16.0)
            }
            .padding(.horizontal, 27.5)
            .padding(.bottom, UIDevice.isIPad ? 27.5 : 8)
        }.interactiveDismissDisabled(!isFromSetting)
    }
}

struct WhatsNewView_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewView(activeSheet: .constant(nil), isPresented: .constant(false))
    }
}
