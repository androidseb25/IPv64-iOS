//
//  NotificationItemView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//

import SwiftUI

struct NotificationItemView: View {
    
    @State var integration: Integration
    
    var body: some View {
        HStack(alignment: .top) {
            integration.icon
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24, alignment: .center)
                .padding(.leading, 5)
            VStack(alignment: .leading) {
                Text(integration.integrationName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.bottom, 2)
                Text("added: \(integration.AddTime)")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Text("last use: \(integration.LastUsed)")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth:.infinity, alignment: .leading)
            .padding(.leading, 10)
        }
    }
}

#Preview {
    var integration = Integration(integration: "telegram", integrationId: Optional(1109), integrationName: "Telegram Bot", options: Optional(IPv64_net.IntegrationOptions(serverurl: nil, downprio: nil, upprio: nil, number: nil, countrycode: nil, completenumber: nil, key: nil, webhookurl: nil, pinguser: nil, pinggroup: nil, email: nil, devicetoken: nil, apptoken: nil, priority: nil)), addTime: "2023-03-09 11:18:12", lastUsed: "2023-03-09 11:18:12", selectedState: false, keyName: Optional("Telegram Bot"))
    NotificationItemView(integration: integration)
}
