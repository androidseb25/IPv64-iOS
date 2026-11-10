//
//  LogItemView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 24.10.25.
//

import Foundation
import SwiftUI

struct LogItemView: View {
    @State var log: MyLogs
    
    var body: some View {
        VStack {
            Text(log.header)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(log.content)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 5)
            Text(log.LogTime)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    LogItemView(log: MyLogs(time: "0001-01-01 00:00:00", header: "Test", content: "Test"))
}
