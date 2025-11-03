//
//  LogItemView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI

struct LogItemView: View {
    
    @State var log: MyLogs
    
    var body: some View {
        let dateDate = dateDBFormatter.date(from: log.time!)
        let dateString = itemFormatter.string(from: dateDate ?? Date())
        Button(action: {
            print(log)
            withAnimation {
                log.expandLog.toggle()
            }
        }) {
            VStack {
                HStack {
                    Text(log.subdomain!)
                        .font(.system(.caption, design: .rounded))
                    Spacer()
                    Text(dateString)
                        .font(.system(.caption, design: .rounded))
                }
                .padding(.bottom, 2)
                VStack(alignment: .leading, spacing: 0) {
                    Text(log.header!)
                        .font(.system(.headline, design: .rounded))
                        .padding(.bottom, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if (log.expandLog) {
                        Text(log.content!)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(log.content!)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .foregroundStyle(Color("primaryText"))
        }
    }
    
    private let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    private let dateDBFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

#Preview {
    LogItemView(log: MyLogs(subdomain: "mesr.ipv64.net", time: "2022-11-25 15:12:16", header: "Record hinzugefügt", content: "DNS Record (A) für mesr.ipv64.net hinzugefügt. jhasiufjajsdnjcn ijsidncdnsciun "))
}
