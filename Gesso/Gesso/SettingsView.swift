//
//  SettingsView.swift
//  Gesso
//
//  Settings and preferences view
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("autoSave") private var autoSave = true
    @AppStorage("theme") private var theme = "System"
    
    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable Haptics", isOn: $enableHaptics)
                Toggle("Auto-save Annotations", isOn: $autoSave)
            }
            
            Section("Appearance") {
                Picker("Theme", selection: $theme) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("1")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
