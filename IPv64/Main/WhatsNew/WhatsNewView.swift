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
        WhatsNewObj(imageName: "text.line.first.and.arrowtriangle.forward", title: "Domain Übersicht verbessert", subtitle: "Die Domain Übersicht wurde jetzt überarbeitet. Diese werden jetzt in den einzelnen Domains aufgelistet"),
        WhatsNewObj(imageName: "app", title: "Neues App Icon", subtitle: "Nach einem Picasso ähnlichen kreativen Erguss, wurde ein neues App Icon gemalt"),
        WhatsNewObj(imageName: "bell.badge", title: "Benachrichtung über die App", subtitle: "Empfange jetzt deine Server Down/Up  Benachrichtungen über die App, wenn du unter deinem Healthcheck bei den Benachrichtungsmethoden \"iOS IPv64.net App\" auswählst")
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
