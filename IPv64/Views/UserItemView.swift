//
//  UserItemView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 22.10.25.
//

import SwiftUI

struct UserItemView: View {
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    
    @State var user: User
    
    var body: some View {
        Button(action: {
            withAnimation {
                UserStorage.shared.ApiKey = user.ApiKey
                dismiss()
            }
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(user.Username)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(user.Information.isEmpty ? "No Information" : user.Information)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.trailing, 8)
                Image(systemName: user.ApiKey == UserStorage.shared.ApiKey ? "largecircle.fill.circle" : "circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 8)
        }
        .foregroundStyle(systemColorScheme == .dark ? .white : .black)
    }
}

#Preview {
    let user = User(Username: "Test", ApiKey: "Test", Information: "Test")
    List {
        UserItemView(user: user)
    }
}
