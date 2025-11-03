//
//  HealthcheckDetailView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 30.10.25.
//

import SwiftUI

struct HealthcheckDetailView: View {
    
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.dismiss) var dismiss
    
    @State var hc: HealthCheck
    @Binding var isChanged: Bool
    
    @State private var showEditHc: Bool = false
    
    var body: some View {
        if #available(iOS 26.0, *) {
            listView
                .setColorGradient(showEditHc ? .clear : .orange)
        } else {
            listView
        }
    }
    
    private var listView: some View {
        List {
            Section("Status") {
                HealthcheckEventView(showSmall: false, events: hc.events)
                    .listStyle(.plain)
            }
            Section("Healthcheck Settings") {
                LabeledContent("Period:", value: "\(hc.alarm_count) \(hc.AlarmUnit.label)")
                LabeledContent("Waiting period:", value: "\(hc.grace_count) \(hc.GraceUnit.label)")
                LabeledContent("Notification methods:", value: "\(hc.integration_id.filter { $0 == "," }.count + 1)")
                LabeledContent("Notification DOWN", value: hc.AlarmDown)
                    .foregroundStyle(.red)
                LabeledContent("Notification UP", value: hc.AlarmUp)
                    .foregroundStyle(.green)
                LabeledContent("created at:", value: hc.AddTime)
                LabeledContent("last update:", value: hc.LastUpdateTime)
                LabeledContent("next alarm time:", value: hc.NextAlarmTime)
                LabeledContent("Ping total:", value: "\(hc.pings_total)")
                    
                Text("Healthcheck URL")
                    .badge("swipe")
                    .swipeActions {
                        Button {
                            UIPasteboard.general.string = HealthcheckUrl
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Label("Copy", systemImage: "document.on.document")
                        }
                        .tint(.blue)
                        .labelStyle(.iconOnly)
                        Button {
                            if let url = URL(string: HealthcheckUrl) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Open in Browser", systemImage: "arrow.up.forward.app")
                        }
                        .tint(.gray)
                    }
                    .foregroundStyle(.blue)
            }
            Section("Logs") {
                ForEach(hc.events, id:\.uuid) { event in
                    VStack {
                        Text(event.text ?? "")
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 5)
                            .foregroundStyle(event.HealthStatus.color)
                        Text(event.EventTime)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle(hc.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Button(action: {
                    withAnimation {
                        showEditHc.toggle()
                    }
                }){
                    Label("Edit Healthcheck", systemImage: "pencil")
                }
                .tint(systemColorScheme == .dark ? .white : .black)
            }
        }
        .sheet(isPresented: $showEditHc.animation()){
            HealthcheckEditView(hc: hc, isChanged: $isChanged).onDisappear {
                if (isChanged) {
                    dismiss()
                }
            }
        }
    }
    
    private var HealthcheckUrl: String {
        return "https://ipv64.net/health.php?token=" + (hc.healthtoken)
    }
}

#Preview {
    NavigationStack {
        HealthcheckDetailView(hc: .empty, isChanged: .constant(false))
    }
}
