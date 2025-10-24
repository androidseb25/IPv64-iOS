//
//  DomainItemView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//

import SwiftUI

struct DomainItemView: View {
    
    @State var domain: Domain
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)
                .foregroundStyle(domain.tintColor)
                .padding(.trailing, 5)
                .padding(.top, 8)
            
            VStack(alignment: .leading) {
                Text(domain.fqdn)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.bottom, 2)
                Text("Updates: \(domain.updates ?? 0)")
                    .multilineTextAlignment(.leading)
                Text("Wildcard: \(domain.isWildcardString)")
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    var domain: Domain = Domain(updates: Optional(0), wildcard: Optional(1), domainUpdateHash: Optional("pIWgUltDMxkn6GFaHizRJV495uYKPvSN"), records: Optional([RecordInfos(recordId: Optional(120762), content: Optional("37.247.65.25"), ttl: Optional(60), type: Optional("A"), praefix: Optional(""), lastUpdate: Optional("2024-04-16 07:48:17"), recordKey: Optional("r6lhGUXD1RxMBdNQVPYz53oTmJELAKSf"), deactivated: Optional(0), failoverPolicy: Optional("0")), RecordInfos(recordId: Optional(399283), content: Optional("10 rblwal"), ttl: Optional(60), type: Optional("MX"), praefix: Optional("vijomc"), lastUpdate: Optional("2025-09-05 16:40:06"), recordKey: Optional("moRXclzW3kOEpJNyYAPxZav0Ks2HwUeb"), deactivated: Optional(0), failoverPolicy: Optional("0"))]), ipv6prefix: Optional(""), dualstack: Optional(""), deactivated: Optional(0), fqdn: "gitlabrunner1.iot64.de", ipv4: "0.0.0.0", ipv6: "::1")
    
    List {
        DomainItemView(domain: domain)
    }
}
