//
//  BiometricsLockView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 03.11.25.
//

import SwiftUI

struct BiometricsLockView: View {
    
    @EnvironmentObject var bio: Biometrics
    @StateObject private var userStorage = UserStorage.shared
    
    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                Image(systemName: Biometrics.GetBiometricSymbol())
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.orange)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 75, height: 75, alignment: .center)
                    .padding(.bottom, 25)
                Text("Please use \(Biometrics.GetBiometricText()) to unlock the app")
                    .font(.system(.callout, design: .rounded))
                    .padding(.bottom)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                if #available(iOS 26.0, *) {
                    authBtn
                        .glassEffect(.regular.tint(.orange).interactive(true))
                } else {
                    authBtn
                        .background(RoundedRectangle(cornerRadius: 24).fill(.orange))
                }
            }
            .padding(.horizontal)
            .onAppear {
                print(userStorage.InAppSwitcher)
                if (!userStorage.InAppSwitcher) {
                    bio.disableFields = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        bio.tryToAuthenticatePIN()
                    }
                } else {
                    bio.disableFields = false
                }
                //bio.tryToAuthenticatePIN()
            }
            .onChange(of: bio.isAuthenticated) { _, value in
                withAnimation {
                    if bio.isAuthenticated {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            }
            .onChange(of: userStorage.InAppSwitcher) { _, value in
                withAnimation {
                    if (!userStorage.InAppSwitcher) {
                        bio.disableFields = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            bio.tryToAuthenticatePIN()
                        }
                    }
                }
            }
        }
    }
    
    private var authBtn: some View {
        Button (action: {
            withAnimation {
                bio.disableFields = true
                bio.tryToAuthenticatePIN()
            }
        }) {
            if bio.disableFields {
                Spinner(isAnimating: true, style: .medium, color: UIColor.white)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(16)
            } else {
                Text("Unlock")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(16)
            }
        }
        .disabled(bio.disableFields)
    }
}

#Preview {
    BiometricsLockView()
        .environmentObject(Biometrics())
}
