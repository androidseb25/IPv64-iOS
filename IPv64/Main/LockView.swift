//
//  LockView.swift
//  Tokey
//
//  Created by Sebastian Rank on 05.04.22.
//

import SwiftUI

struct LockView: View {
    
    @State var showDomains = false
    @State private var frameWidth: CGFloat = .infinity
    @ObservedObject private var bio = Biometrics()
    
    var body: some View {
        ZStack {
            if !showDomains {
                VStack(alignment: .center) {
                    Image(systemName: "lock.shield")
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(Color("ip64_color"))
                        .frame(width: 75, height: 75, alignment: .center)
                        .padding(.bottom, 25)
                    Text("Bitte verwende FaceID/TouchID um IPv64.net zu entsperren")
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(Color("primaryText"))
                        .padding(.bottom)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    HStack {
                        Button(action: {
                            withAnimation {
                                bio.disableFields = true
                                bio.tryToAuthenticate()
                            }
                        }) {
                            ZStack {
                                if bio.disableFields {
                                    Spinner(isAnimating: true, style: .large, color: UIColor.white)
                                } else {
                                    HStack {
                                        Image(systemName: Biometrics.GetBiometricSymbol())
                                            .resizable()
                                            .symbolRenderingMode(.hierarchical)
                                            .scaledToFit()
                                            .frame(width: 24, height: 24, alignment: .center)
                                            .padding(.trailing, 10)
                                        Text("Entsperren")
                                            .font(.system(.callout, design: .rounded))
                                            .fontWeight(.bold)
                                            .textCase(.uppercase)
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .padding(16)
                                    .foregroundColor(Color.white)
                                    .background(Color("ip64_color")).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: 55)
                            .background(Color("ip64_color")).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(bio.disableFields)
                        .padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                .padding(16)
                .onAppear {
                    frameWidth = Functions.getOrientationWidth()
                    bio.reset()
                    bio.tryToAuthenticate()
                }
                .onChange(of: bio.isAuthenticated) { value in
                    withAnimation {
                        if bio.isAuthenticated {
                            showDomains = true
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                    }
                }
                .frame(maxWidth: frameWidth, maxHeight: .infinity)
            } else {
                TabbView(showDomains: $showDomains)
            }
        }
        .onRotate { _ in
            frameWidth = Functions.getOrientationWidth()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LockView_Previews: PreviewProvider {
    static var previews: some View {
        LockView()
            .preferredColorScheme(.light)
        LockView()
            .preferredColorScheme(.dark)
    }
}
