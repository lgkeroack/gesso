//
//  ContentView.swift
//  Gesso
//
//  An app which lets you visually annotate and respond to UI changes in real time
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .canvas
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(Tab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.title, systemImage: tab.icon)
                }
            }
            .navigationTitle("Gesso")
            .navigationBarTitleDisplayMode(.large)
        } detail: {
            // Detail view
            switch selectedTab {
            case .canvas:
                CanvasView()
            case .annotations:
                AnnotationView()
            case .settings:
                SettingsView()
            }
        }
    }
}

enum Tab: String, CaseIterable, Identifiable {
    case canvas
    case annotations
    case settings
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .canvas: return "Canvas"
        case .annotations: return "Annotations"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .canvas: return "paintbrush.pointed"
        case .annotations: return "hand.draw"
        case .settings: return "gearshape"
        }
    }
}

#Preview {
    ContentView()
}
