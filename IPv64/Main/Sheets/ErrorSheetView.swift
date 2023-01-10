//
//  ErrorSheetView.swift
//  IPv64
//
//  Created by Sebastian Rank on 07.11.22.
//

import SwiftUI

struct ErrorSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @Binding var errorTyp: ErrorTyp?
    @Binding var deleteThisDomain: Bool
    
    @State var timeRemaining = 10
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                let icon = errorTyp!.icon!
                if (icon.contains(";")) {
                    let splittetIcons = icon.split(separator: ";")
                    ZStack {
                        ZStack {
                            Circle()
                                .fill(Color("circleBG"))
                                .frame(height: 220)
                            Circle()
                                .fill(Color("circleBG"))
                                .frame(height: 75)
                                .offset(x: 75, y: 55)
                        }
                        Image(systemName: String(splittetIcons[0]))
                            .resizable()
                            .scaledToFit()
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(errorTyp!.iconColor!)
                            .frame(height: 115)
                            .padding(25)
                        Image(systemName: String(splittetIcons[1]))
                            .resizable()
                            .scaledToFit()
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(errorTyp!.iconColor!)
                            .frame(height: 45)
                            .padding()
                            .offset(x: 70, y: 50)
                        
                    }
                } else {
                    ZStack {
                        ZStack {
                            Circle()
                                .fill(Color("circleBG"))
                                .frame(height: 220)
                        }
                        Image(systemName: icon)
                            .resizable()
                            .scaledToFit()
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(errorTyp!.iconColor!)
                            .frame(height: 100)
                            .padding(25)
                        
                    }
                }
                Spacer()
                VStack {
                    Text(errorTyp!.errorTitle!)
                        .multilineTextAlignment(.center)
                        .font(.system(.title3, design: .rounded).bold())
                    Text(errorTyp!.errorDescription!)
                        .font(.system(.callout, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
                
                if (errorTyp!.status! == 429) {
                    Button(action: {
                        withAnimation {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text(timeRemaining > 0 ? "Schließen (\(timeRemaining))" : "Schließen")
                            .font(.system(.callout, design: .rounded))
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding(16)
                            .foregroundColor(Color.white)
                            .background(Color("ip64_color")).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(timeRemaining > 0)
                    .padding()
                } else if (errorTyp!.status! == 202) {
                    Button(action: {
                        withAnimation {
                            deleteThisDomain = true
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text("Wirklich löschen?")
                            .font(.system(.callout, design: .rounded))
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding(16)
                            .foregroundColor(Color.white)
                            .background(.red).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding([.horizontal, .top])
                    
                    Button(action: {
                        withAnimation {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text("Abbrechen")
                            .font(.system(.callout, design: .rounded))
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding(16)
                            .foregroundColor(Color("AccentColor"))
                            .background(.gray.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding([.horizontal, .bottom])
                } else {
                    Button(action: {
                        withAnimation {
                            deleteThisDomain = false
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text("Schließen")
                            .font(.system(.callout, design: .rounded))
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding(16)
                            .foregroundColor(Color.white)
                            .background(errorTyp!.iconColor!).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding()
                }
            }
            .navigationTitle(errorTyp!.navigationTitle!)
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(timer) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timer.upstream.connect().cancel()
                }
            }
        }
    }
}

struct ErrorSheetView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorSheetView(errorTyp: .constant(ErrorTypes.unauthorized), deleteThisDomain: .constant(false))
    }
}
