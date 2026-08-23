# Gesso

An app which lets you visually annotate and respond to UI changes in real time.

## Overview

Gesso is a modern iPad application built with SwiftUI, designed to provide an intuitive interface for visual annotation and real-time UI interaction.

## Features

- **Canvas View**: Interactive canvas for real-time UI manipulation
- **Annotation System**: Create and manage visual annotations
- **iPad Optimized**: Built specifically for iPad with split-view navigation
- **Modern Architecture**: Built with SwiftUI and iOS 17+

## Project Structure

```
Gesso/
├── Gesso/                      # Main iOS app
│   ├── Gesso.xcodeproj/       # Xcode project file
│   └── Gesso/                 # App source files
│       ├── GessoApp.swift     # App entry point
│       ├── ContentView.swift  # Main navigation view
│       ├── CanvasView.swift   # Canvas interface
│       ├── AnnotationView.swift # Annotation tools
│       ├── SettingsView.swift # Settings interface
│       └── Assets.xcassets/   # App assets
├── Sources/                   # Swift Package Manager sources
│   └── GessoCore/            # Core library
└── Tests/                     # Unit tests
    └── GessoCoreTests/       # Core library tests
```

## Non-Goals

Gesso is a single-user, in-session tool. Collaboration (multi-user sessions, shared
canvases, presence), persistence (document store, saved annotation history, cloud
sync), and export (PDF, image, or file output) are explicitly out of scope.
Annotations live in memory for the life of the session and are not written anywhere.

Gesso is also not a drawing or illustration app. Layers, template galleries, and
art-tool feature sets are out of scope; marks exist to point at UI, not to compose
artwork.

## Requirements

- iOS 17.0+
- iPadOS 17.0+
- Xcode 15.2+
- Swift 5.9+

## Building

### Using Xcode

1. Open `Gesso/Gesso.xcodeproj` in Xcode
2. Select an iPad simulator or device
3. Build and run (⌘R)

### Using Swift Package Manager

```bash
swift build
swift test
```

## Architecture

The app follows modern SwiftUI best practices:

- **SwiftUI**: Declarative UI framework
- **MVVM Pattern**: Model-View-ViewModel architecture
- **iPad-First Design**: Optimized for iPad with NavigationSplitView
- **Modular Structure**: Core functionality separated into reusable modules

## Development

The app uses:
- SwiftUI for UI components
- Combine for reactive programming
- AppStorage for UI preferences (theme, haptics)
- Preview providers for rapid development

## License

Copyright © 2026 Gesso. All rights reserved.
