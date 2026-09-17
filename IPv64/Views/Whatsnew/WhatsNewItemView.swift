//
//  WhatsNewItemView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 13.02.26.
//

import SwiftUI

struct WhatsNewItemView: View {
    
    @State var whatsNewItem: WhatsNew
    @State private var animate = false
    
    var body: some View {
        VStack(alignment: .leading)
        {
            HStack(alignment: .top) {
                if #available(iOS 17.0, *) {
                    if (whatsNewItem.imageName == "fireworks") {
                        Image(systemName: whatsNewItem.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                            .padding(.horizontal)
                            .foregroundStyle(.green, .yellow)
                            .symbolRenderingMode(.palette)
                        //                            .symbolEffect(.bounce.up.byLayer, options: .speed(0.4).repeating, value: animate)
                    } else if (whatsNewItem.assetIcon) {
                        Image(whatsNewItem.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                            .padding(.horizontal)
                            .foregroundColor(.orange)
                            .symbolRenderingMode(.hierarchical)
                    } else {
                        Image(systemName: whatsNewItem.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                            .padding(.horizontal)
                            .foregroundColor(.orange)
                            .symbolRenderingMode(.hierarchical)
                    }
                } else {
                    Image(systemName: whatsNewItem.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35, height: 35)
                        .padding(.horizontal)
                        .foregroundColor(.orange)
                        .symbolRenderingMode(.hierarchical)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(whatsNewItem.title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                    Text(whatsNewItem.subtitle)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.gray)
                }
                .padding(.trailing)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.bottom)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            animate = true
        }
    }
}

struct WhatsNewItemView26: View {
    
    @State var whatsNewItem: WhatsNew
    @State private var animate = false
    
    var body: some View {
        VStack(alignment: .leading)
        {
            HStack(alignment: .top) {
                if #available(iOS 17.0, *) {
                    if (whatsNewItem.imageName == "fireworks") {
                        Image(systemName: whatsNewItem.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                            .padding(.trailing, 8)
                            .foregroundStyle(.green, .yellow)
                            .symbolRenderingMode(.palette)
                        //                            .symbolEffect(.bounce.up.byLayer, options: .speed(0.4).repeating, value: animate)
                    } else if (whatsNewItem.assetIcon) {
                        Image(whatsNewItem.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                            .padding(.trailing)
                            .foregroundColor(.orange)
                            .symbolRenderingMode(.hierarchical)
                    } else {
                        Image(systemName: whatsNewItem.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                            .padding(.trailing, 8)
                            .foregroundColor(.orange)
                    }
                } else {
                    Image(systemName: whatsNewItem.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35, height: 35)
                        .padding(.trailing, 8)
                        .foregroundColor(.orange)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(whatsNewItem.title)
                        .font(.system(.body))
                        .fontWeight(.bold)
                    Text(whatsNewItem.subtitle)
                        .font(.system(.callout))
                        .foregroundColor(.gray)
                }
                .padding(.trailing)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            animate = true
        }
    }
}

#Preview {
    WhatsNewItemView26(whatsNewItem: WhatsNew(imageName: "appstore", title: "Was ist Neu?", subtitle: "Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren", assetIcon: true))
}
