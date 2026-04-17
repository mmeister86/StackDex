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
        case ocrDebug
        case settings
    }

    @State private var selectedTab: RootTab = .collection
    @State private var ocrDebugSnapshot: ScanOCRDebugSnapshot?

    var body: some View {
        TabView(selection: $selectedTab) {
            CollectionTabView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Sammlung", systemImage: "square.stack.3d.up")
                }
                .tag(RootTab.collection)

            ScanTabView { snapshot in
                ocrDebugSnapshot = snapshot
            }
                .tabItem {
                    Label("Scannen", systemImage: "camera.viewfinder")
                }
                .tag(RootTab.scan)

            ScanOCRDebugTabView(snapshot: ocrDebugSnapshot)
                .tabItem {
                    Label("OCR Debug", systemImage: "text.viewfinder")
                }
                .tag(RootTab.ocrDebug)

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
