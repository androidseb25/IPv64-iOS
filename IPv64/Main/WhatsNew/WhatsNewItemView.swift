//
//  WhatsNewItemView.swift
//  Treibholz
//
//  Created by Sebastian Rank on 16.02.22.
//

import SwiftUI

struct WhatsNewItemView: View {
    
    @State var whatsNewItem: WhatsNewObj
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Image(systemName: whatsNewItem.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .symbolRenderingMode(.hierarchical)
                    .padding(.horizontal)
                    .foregroundColor(Color("ip64_color"))
                VStack(alignment: .leading, spacing: 5) {
                    Text(whatsNewItem.title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                    Text(whatsNewItem.subtitle)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(Color("primaryText"))
                }
                .padding(.trailing)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.bottom)
            .frame(maxWidth: .infinity)
        }
    }
}

struct WhatsNewItemView_Previews: PreviewProvider {
    static var previews: some View {
        WhatsNewItemView(whatsNewItem: WhatsNewObj(imageName: "sparkles", title: "Was ist Neu?", subtitle: "Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren"))
    }
}
