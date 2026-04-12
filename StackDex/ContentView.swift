//
//  ContentView.swift
//  StackDex
//
//  Created by Matthias Meister on 12.04.26.
//

import SwiftUI

struct ContentView: View {
    enum RootTab: Hashable {
        case collection
        case scan
        case settings
    }

    @State private var selectedTab: RootTab = .collection

    var body: some View {
        TabView(selection: $selectedTab) {
            CollectionTabView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Sammlung", systemImage: "square.stack.3d.up")
                }
                .tag(RootTab.collection)

            ScanTabView()
                .tabItem {
                    Label("Scannen", systemImage: "camera.viewfinder")
                }
                .tag(RootTab.scan)

            SettingsTabView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .tag(RootTab.settings)
        }
    }
}

#Preview {
    ContentView()
}
