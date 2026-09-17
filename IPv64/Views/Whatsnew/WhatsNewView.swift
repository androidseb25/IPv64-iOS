//
//  WhatsNewView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 13.02.26.
//

import SwiftUI
import Combine

struct WhatsNewView: View {
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var userStorage = UserStorage.shared
    @Binding var activeSheet: ActiveSheet?
    @Binding var isPresented: Bool
    var isFromSetting = false
    
    var whatsNewList: [WhatsNew] = [
        WhatsNew(imageName: "appstore", title: "AppStore release".localized, subtitle: "It's now the time to give you all access to this app!".localized, assetIcon: true),
        WhatsNew(imageName: "sparkles", title: "iOS 26 optimized".localized, subtitle: "Version 2.0 brings a striking new app icon and a thoughtfully refined Liquid Glass user interface. Built for iOS 26, it seamlessly embraces the newest technologies to deliver a more powerful and fluid experience.".localized),
        WhatsNew(imageName: "ant.circle", title: "Improvements & Fixes".localized, subtitle: "We’ve also included various bug fixes and stability improvements to ensure a smoother and more reliable experience.".localized)
    ]
    
    var body: some View {
        VStack {
            VStack {
                Text("What's new?")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("In the version \(Bundle.main.versionNumber) (\(Bundle.main.buildNumber)) are these changes implemented and bugs have been resolved:")
                    .font(.system(.body, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.top, 1)
            }
            .padding(.vertical, 27.5)
            
            ScrollView {
                ForEach(whatsNewList, id: \.id) { item in
                    WhatsNewItemView(whatsNewItem: item)
                }
            }.offset(y: -10)
            
            Button(action: {
                withAnimation {
                    let buildNumber = Bundle.main.buildNumber
                    userStorage.LAST_BUILD_NUMBER = buildNumber
                    activeSheet = nil
                    dismiss()
                }
            }) {
                Text(isFromSetting ? "Close" : "Continue").font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 50, idealHeight: 50, maxHeight: 50, alignment: .center)
                    .background(.orange)
                    .cornerRadius(8.0)
            }
            .padding(.horizontal, 27.5)
            .padding(.bottom, UIDevice.isIpad ? 27.5 : 8)
            
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(!isFromSetting)
    }
}

@available(iOS 26.0, *)
struct WhatsNewView26: View {
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var userStorage = UserStorage.shared
    @Binding var activeSheet: ActiveSheet?
    @Binding var isPresented: Bool
    var isFromSetting = false
    
    var whatsNewList: [WhatsNew] = [
        WhatsNew(imageName: "appstore", title: "AppStore release".localized, subtitle: "It's now the time to give you all access to this app!".localized, assetIcon: true),
        WhatsNew(imageName: "sparkles", title: "iOS 26 optimized".localized, subtitle: "Version 2.0 brings a striking new app icon and a thoughtfully refined Liquid Glass user interface. Built for iOS 26, it seamlessly embraces the newest technologies to deliver a more powerful and fluid experience.".localized),
        WhatsNew(imageName: "ant.circle", title: "Improvements & Fixes".localized, subtitle: "We’ve also included various bug fixes and stability improvements to ensure a smoother and more reliable experience.".localized)
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("What's new in IPv64.net \nv\(Bundle.main.versionNumber) (\(Bundle.main.buildNumber))")
                .font(.system(.title3, weight: .bold))
                .padding(.bottom)
            
            ScrollView {
                ForEach(whatsNewList, id: \.id) { item in
                    WhatsNewItemView26(whatsNewItem: item)
                }
            }
            
            Button (action: {
                withAnimation {
                    let buildNumber = Bundle.main.buildNumber
                    userStorage.LAST_BUILD_NUMBER = buildNumber
                    activeSheet = nil
                    dismiss()
                }
            }) {
                Text(isFromSetting ? "Close" : "Continue")
                    .font(.system(.callout))
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(16)
            }
            .glassEffect(.regular.tint(.orange).interactive(true))
        }
        .padding([.top, .horizontal], 50)
        .interactiveDismissDisabled(!isFromSetting)
    }
}

#Preview {
    VStack { }
        .sheet(item: .constant(ActiveSheet.whatsnew)) { _ in
            if #available(iOS 26.0, *) {
                WhatsNewView26(activeSheet: .constant(nil), isPresented: .constant(true))
            } else {
                WhatsNewView(activeSheet: .constant(nil), isPresented: .constant(true))
            }
        }
}
