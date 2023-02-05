//
//  NewDomainView.swift
//  IPv64
//
//  Created by Sebastian Rank on 06.11.22.
//

import SwiftUI

struct NewDomainView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @Binding var newItem: Bool
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = nil
    @State var showSheet = false
    
    @State var domain: String = ""
    @State private var selectedDomain = 0
    @State var domainError: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Form {
                        Section("Benötigte Informationen") {
                            TextField("zB.: Heimserver01", text: $domain)
                            Picker(selection: $selectedDomain, label: Text("Domain")
                                .font(.system(.callout))
                                .padding(.horizontal, 5)) {
                                    ForEach(0 ..< dynDomainList.count) {
                                        Text(dynDomainList[$0])
                                            .tag(dynDomainList[$0])
                                    }
                                }
                        }
                    }
                }
                .navigationTitle("Neue Domain")
                .toolbar {
                    ToolbarItem {
                        Button(action: {
                            if (domain.count > 0) {
                                var domainReg = domain.trimmingCharacters(in: .whitespaces) + "." + dynDomainList[selectedDomain]
                                //loadDomains()
                                Task {
                                    let res = await api.PostDomain(domain: domainReg)
                                    if (res?.info == "success") {
                                        activeSheet = .error
                                        errorTyp = ErrorTypes.domainCreatedSuccesfully
                                        newItem = true
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
            .sheet(item: $activeSheet) { item in
                showActiveSheet(item: item)
            }
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .add:
            EmptyView()
        case .detail:
            EmptyView()
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: .constant(false))
                .interactiveDismissDisabled(true)
                .onDisappear {
                    if (self.errorTyp!.status == 201) {
                        withAnimation {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        default:
            EmptyView()
        }
    }
}

struct NewDomainView_Previews: PreviewProvider {
    static var previews: some View {
        NewDomainView(newItem: .constant(false))
    }
}
