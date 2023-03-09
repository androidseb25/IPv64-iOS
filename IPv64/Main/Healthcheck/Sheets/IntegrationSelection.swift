//
//  IntegrationSelection.swift
//  IPv64
//
//  Created by Sebastian Rank on 07.03.23.
//

import SwiftUI

struct IntegrationSelection: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("IntegrationList") var integrationListS: String = ""
    @Binding var integrationIds: String
    @State var integrationList: [Integration] = []
    @State private var selection = Set<Int>()
    @State var editMode: EditMode = .active
    
    var body: some View {
        NavigationView {
            List(integrationList, id: \.integration_id, selection: $selection) { i in
                Text(i.integration_name!.replacingOccurrences(of: "&quot;", with: "\""))
            }
            .navigationTitle("Benachrichten auf")
            .environment(\.editMode, self.$editMode)
            .onAppear {
                var splitSel = integrationIds.split(separator: "_")
                splitSel.forEach { i in
                    if (Int(i)! != 0) {
                        selection.insert(Int(i)!)
                    }
                }
                do {
                    let jsonDecoder = JSONDecoder()
                    let jsonData = integrationListS.data(using: .utf8)
                    integrationList = try jsonDecoder.decode([Integration].self, from: jsonData!).sorted { $0.integration_name!.lowercased() < $1.integration_name!.lowercased()
                    }
                } catch {
                    print("ERROR \(error.localizedDescription)")
                }
            }
            .toolbar {
                Button(action: {
                    withAnimation {
                        integrationIds = selection.compactMap { $0.description }
                            .joined(separator: "_")
                        if (integrationIds.count == 0) {
                            integrationIds = "0"
                        }
                        print(integrationIds)
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text("Speichern")
                }
            }
        }
    }
}

struct IntegrationSelection_Previews: PreviewProvider {
    static var previews: some View {
        IntegrationSelection(integrationIds: .constant(""))
    }
}
