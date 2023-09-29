//
//  IntegrationView.swift
//  IPv64
//
//  Created by Sebastian Rank on 09.03.23.
//

import SwiftUI
import Introspect
import Toast

struct IntegrationView: View {
    
    @AppStorage("AccountInfos") var accountInfos: String = ""
    @AppStorage("IntegrationList") var integrationListS: String = ""
    @ObservedObject var api: NetworkServices = NetworkServices()
    
    @Binding var popToRootTab: Tab
    
    @State var deleteThisIntegration = false
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    @State var integrationList: IntegrationResult? = nil
    
    @State var deleteIntegrationId = 0
    
    fileprivate func deleteIntegrationDialog() {
        errorTyp = ErrorTypes.deleteIntegration
        activeSheet = .error
        print(errorTyp)
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    Form {
                        Section("Integrations") {
                            if (integrationList == nil) {
                                Text("Keine Daten gefunden!")
                            } else {
                                ForEach(GetSortedIntegrationList(), id: \.i_uuid) { ig in
                                    LazyVStack {
                                        HStack {
                                            GetSystemImage(ig: ig.integration!)
                                            Text(ig.integration_name!.replacingOccurrences(of: "&quot;", with: "\""))
                                            Spacer()
                                        }
                                        .id(UUID())
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive, action: {
                                            deleteIntegrationId = ig.integration_id
                                            deleteIntegrationDialog()
                                        }) {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle(Tab.integrations.labelName)
                .refreshable {
                    GetIntegrations()
                }
            }
            .introspectNavigationController { navigationController in
                navigationController.splitViewController?.preferredPrimaryColumnWidthFraction = 1
                navigationController.splitViewController?.maximumPrimaryColumnWidth = 400
            }
            .accentColor(Color("AccentColor"))
            .sheet(item: $activeSheet) { item in
                showActiveSheet(item: item)
            }
            
            if api.isLoading {
                VStack() {
                    Spinner(isAnimating: true, style: .large, color: .white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3).ignoresSafeArea())
            }
        }
        .onAppear {
            GetIntegrations()
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: $deleteThisIntegration)
                .interactiveDismissDisabled(errorTyp?.status == 202 ? false : true)
                .onDisappear {
                    if (deleteThisIntegration) {
                        Task {
                            let res = await api.DeleteIntegration(integration_id: deleteIntegrationId)
                            
                            
                            let toast = Toast.default(
                                image: GetUIImage(imageName: "checkmark.circle", color: UIColor.systemGreen, hierarichal: true),
                                title: "Erfolgreich gelöscht!", config: .init(
                                    direction: .top,
                                    autoHide: true,
                                    enablePanToClose: false,
                                    displayTime: 4,
                                    enteringAnimation: .fade(alphaValue: 0.5),
                                    exitingAnimation: .slide(x: 0, y: -100))
                            )
                            toast.show(haptic: .success)
                            
                            GetIntegrations()
                        }
                    } else {
                        if (errorTyp?.status == 401) {
                            SetupPrefs.setPreference(mKey: "APIKEY", mValue: "")
                        } else {
                            GetIntegrations()
                        }
                    }
                }
        default:
            EmptyView()
        }
    }
    
    fileprivate func GetSortedIntegrationList() -> [Integration] {
        var igList = (integrationList?.integration.sorted { ($0.integration_name?.lowercased())! < ($1.integration_name?.lowercased())! }) ?? []
        print(igList)
        return igList
    }
    
    @ViewBuilder
    fileprivate func GetSystemImage(ig: String) -> some View {
        switch ig {
        case "mobil":
            Image(systemName: "ipad.and.iphone")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(Color("primaryText"))
        case "email":
            Image(systemName: "mail")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(Color("primaryText"))
        case "sms":
            Image(systemName: "message.badge")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(Color("primaryText"))
        case "discord":
            Image("discord_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 25, height: 25)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(Color("primaryText"))
        case "telegram":
            Image("telegram_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 25, height: 25)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(Color("primaryText"))
        case "webhook":
            Image("webhook_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 25, height: 25)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(Color("primaryText"))
        case "gotify":
            Image("gotify_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 25, height: 25)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(Color("primaryText"))
        case "pushover":
            Image("pushover_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 25, height: 25)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(Color("primaryText"))
        case "ntfy":
            Image("ntfy_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 25, height: 25)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(Color("primaryText"))
        case "matrix":
            Image("matrix_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 25, height: 25)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(Color("primaryText"))
        default:
            Image(systemName: "questionmark.square.dashed")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(Color("primaryText"))
        }
    }
    
    fileprivate func GetIntegrations() {
        Task {
            integrationList = await api.GetIntegrations()
            let status = integrationList?.status
            if (status == nil) {
                throw NetworkError.NoNetworkConnection
            }
            if (status!.contains("429") && integrationList?.integration.count == 0) {
                activeSheet = .error
                errorTyp = ErrorTypes.tooManyRequests
            } else if (status!.contains("401")) {
                activeSheet = .error
                errorTyp = ErrorTypes.unauthorized
            } else {
                activeSheet = nil
                errorTyp = nil
                if (integrationList != nil) {
                    let jsonEncoder = JSONEncoder()
                    let jsonData = try jsonEncoder.encode(integrationList?.integration)
                    let json = String(data: jsonData, encoding: String.Encoding.utf8)
                    integrationListS = json!
                }
            }
        }
    }
    
    fileprivate func DeleteIntegration(integration_id: Int) {
        Task {
            let result = await api.DeleteIntegration(integration_id: integration_id)
            let status = integrationList?.status
            if (status == nil) {
                throw NetworkError.NoNetworkConnection
            }
            if (status!.contains("429") && integrationList?.integration.count == 0) {
                activeSheet = .error
                errorTyp = ErrorTypes.tooManyRequests
            } else if (status!.contains("401")) {
                activeSheet = .error
                errorTyp = ErrorTypes.unauthorized
            } else {
                activeSheet = nil
                errorTyp = nil
                if (integrationList != nil) {
                    let jsonEncoder = JSONEncoder()
                    let jsonData = try jsonEncoder.encode(integrationList?.integration)
                    let json = String(data: jsonData, encoding: String.Encoding.utf8)
                    integrationListS = json!
                }
            }
        }
        
    }
}

#Preview {
    IntegrationView(popToRootTab: .constant(.other))
}
