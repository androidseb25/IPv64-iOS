//
//  NewDomainDNSView.swift
//  IPv64
//
//  Created by Sebastian Rank on 08.11.22.
//

import SwiftUI

struct NewDomainDNSView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = nil
    
    @Binding var isSaved: Bool
    @State var domainName: String
    
    @State var praefix: String = ""
    @State var content: String = ""
    @State var selectedTyp: Int = 0
    
    var typeList = [
        "A",
        "AAAA",
        "TXT",
        "MX",
        "NS",
        "SRV",
        "CNAME",
        "TLSA",
        "CAA"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Form {
                        Section("Benötigte Informationen") {
                            TextField("Präfix", text: $praefix)
                            Picker(selection: $selectedTyp, label: Text("Typ")
                                .font(.system(.callout))
                                .padding(.horizontal, 5)) {
                                    ForEach(0 ..< typeList.count) {
                                        Text(self.typeList[$0])
                                            .tag(self.typeList[$0])
                                    }
                                }
                            TextField("Wert", text: $content)
                        }
                    }
                }
                .navigationTitle("Neuer DNS-Record")
                .sheet(item: $activeSheet) { item in
                    showActiveSheet(item: item)
                }
                .toolbar {
                    ToolbarItem {
                        Button(action: {
                            if (content.count > 0) {
                                let _praefix = praefix.trimmingCharacters(in: .whitespaces)
                                let _content = content.trimmingCharacters(in: .whitespaces)
                                Task {
                                    let res = await api.PostDNSRecord(domain: domainName, praefix: _praefix, typ: typeList[selectedTyp], content: _content)
                                    print(res)
                                    if (res?.info == "success") {
                                        activeSheet = .error
                                        errorTyp = ErrorTypes.dnsRecordSuccesfullyCreated
                                    } else if (res?.info == "error") {
                                        activeSheet = .error
                                        errorTyp = ErrorTypes.domainNotAvailable
                                    } else if (res?.info == "Updateintervall overcommited") {
                                        activeSheet = .error
                                        errorTyp = ErrorTypes.tooManyRequests
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "paperplane")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(Color("primaryText"))
                        }
                        .foregroundColor(.black)
                    }
                }
                if api.isLoading {
                    VStack() {
                        Spinner(isAnimating: true, style: .large, color: .white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3).ignoresSafeArea())
                }
            }
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: .constant(false))
                .onDisappear {
                    if (self.errorTyp!.status == 201) {
                        withAnimation {
                            isSaved = true
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        default:
            EmptyView()
        }
    }
}

struct NewDomainDNSView_Previews: PreviewProvider {
    static var previews: some View {
        NewDomainDNSView(isSaved: .constant(false), domainName: "seb.nas64.de")
    }
}
