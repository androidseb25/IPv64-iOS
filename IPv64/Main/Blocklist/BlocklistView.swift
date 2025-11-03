//
//  BlocklistView.swift
//  IPv64
//
//  Created by Sebastian Rank on 08.08.23.
//

import SwiftUI

struct BlocklistView: View {
    
    @Binding var popToRootTab: Tab
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    
    @State private var blockerNodeList: BlockerNodeResults = .empty
    @State private var selectedBlockerNodeId = ""
    @State private var badIp = ""
    @State private var badPort = ""
    @State private var badInfo = ""
    @State private var badCategory = 0
    @State private var showLoginView = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Form {
                        Section("IP - Adresse Reporten") {
                            Picker(selection: $selectedBlockerNodeId, label: Text("Blocker Node*")
                                .font(.system(.callout))
                                .padding(.horizontal, 5)) {
                                    ForEach(blockerNodeList.blockers, id: \.blocker_id) { b in
                                        let name = b.name!
                                        let blocker_id = b.blocker_id!
                                        Text(name)
                                            .tag(blocker_id)
                                            .id(blocker_id)
                                    }
                                }
                            TextField("IP Adresse*", text: $badIp)
                            TextField("Port", text: $badPort)
                            Picker(selection: $badCategory, label: Text("Kategorie*")
                                .font(.system(.callout))
                                .padding(.horizontal, 5)) {
                                    ForEach(0 ..< badNodeCategory.count) {
                                        Text(badNodeCategory[$0].text!)
                                            .tag(badNodeCategory[$0].id! - 1)
                                    }
                                }
                            TextField("Information", text: $badInfo)
                        }
                        
                        Text("* benötigte Informationen")
                            .bold()
                    }
                }
                .tint(Color("ip64_color"))
                .navigationTitle(Tab.blocklist.labelName)
                .toolbar {
                    ToolbarItem {
                        Button(action: {
                            if (badIp.count > 0) {
                                let poisonedIp = PoisonedIP(blocker_id: selectedBlockerNodeId, report_ip: badIp, port: badPort, category: "\(badCategory+1)", info: badInfo)
                                Task {
                                    let res = await api.PostPoisonedIP(poisonedIp: poisonedIp)
                                    print(res)
                                    if (res?.info == "success") {
                                        activeSheet = .error
                                        errorTyp = ErrorTypes.poisonedIpSuccesfully
                                        if (!blockerNodeList.blockers.isEmpty) {
                                            selectedBlockerNodeId = blockerNodeList.blockers[0].blocker_id!
                                        }
                                        badIp = ""
                                        badPort = ""
                                        badCategory = 0
                                        badInfo = ""
                                    } else if (res?.info == "error") {
                                        activeSheet = .error
                                        errorTyp = ErrorTypes.poisonedIpError
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
//                if api.isLoading {
//                    VStack() {
//                        Spinner(isAnimating: true, style: .large, color: .white)
//                    }
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .background(Color.black.opacity(0.3).ignoresSafeArea())
//                }
            }
            .onAppear {
                loadBlockerNodes()
            }
            .fullScreenCover(isPresented: $showLoginView) {
                LoginView()
            }
            .sheet(item: $activeSheet) { item in
                showActiveSheet(item: item)
            }
        }
    }
    
    fileprivate func loadBlockerNodes() {
        Task {
            let response = await api.GetBlockerNodes()
            let status = response?.status
            if (status == nil) {
                throw NetworkError.NoNetworkConnection
            }
            if (status!.contains("429") && response?.blockers == nil) {
                activeSheet = .error
                errorTyp = ErrorTypes.tooManyRequests
            } else if (status!.contains("401")) {
                activeSheet = .error
                errorTyp = ErrorTypes.unauthorized
            } else {
                activeSheet = nil
                errorTyp = nil
                blockerNodeList = response!
                if (!blockerNodeList.blockers.isEmpty) {
                    selectedBlockerNodeId = blockerNodeList.blockers[0].blocker_id!
                }
                print(selectedBlockerNodeId)
                print(response)
            }
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: .constant(false))
                .interactiveDismissDisabled(errorTyp?.status == 202 ? false : true)
                .onDisappear {
                    if (errorTyp?.status == 401) {
                        SetupPrefs.setPreference(mKey: "APIKEY", mValue: "")
                        withAnimation {
                            showLoginView.toggle()
                        }
                    } else {
                        loadBlockerNodes()
                    }
                }
        default:
            EmptyView()
        }
    }
}

#Preview {
    BlocklistView(popToRootTab: .constant(.other))
}
