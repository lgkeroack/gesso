# Gesso - Project Summary

## Overview
Gesso is a modern iPad application for visual annotation and real-time UI interaction, built with SwiftUI and optimized for iOS 17+.

## Project Contents

### Core Application Files
- **GessoApp.swift**: Main application entry point using SwiftUI's @main
- **ContentView.swift**: Root navigation with iPad-optimized NavigationSplitView
- **CanvasView.swift**: Interactive canvas with zoom and pan gestures
- **AnnotationView.swift**: Annotation creation and management interface
- **SettingsView.swift**: User preferences and app settings

### Project Configuration
- **Gesso.xcodeproj**: Complete Xcode project configuration
- **Package.swift**: Swift Package Manager configuration
- **.gitignore**: Comprehensive Xcode and Swift ignore rules
- **Gesso.xcscheme**: Shared Xcode scheme for consistent builds

### Swift Package Manager
- **Sources/GessoCore/**: Core library module for shared functionality
- **Tests/GessoCoreTests/**: Unit tests for the core library

### Documentation
- **README.md**: Main project documentation and overview
- **QUICKSTART.md**: Get started in 5 minutes guide
- **DEVELOPMENT.md**: Comprehensive development guide
- **ARCHITECTURE.md**: Detailed architecture and design documentation
- **CONTRIBUTING.md**: Guidelines for contributing to the project

## Technical Specifications

### Platform Requirements
- **iOS**: 17.0 or later
- **iPadOS**: 17.0 or later
- **Xcode**: 15.2 or later
- **Swift**: 5.9 or later

### Key Technologies
- **SwiftUI**: Modern declarative UI framework
- **NavigationSplitView**: iPad-optimized navigation
- **AppStorage**: UI preference storage (theme, haptics)
- **Gesture Support**: Touch, pinch, zoom, and pan gestures
- **Preview Providers**: Fast iteration with live previews

### App Configuration
- **Bundle ID**: com.gesso.app
- **Target Device**: iPad only (Device Family: 2)
- **Supported Orientations**: All (Portrait, Landscape, Upside Down)
- **Deployment Target**: iOS 17.0
- **Build System**: Xcode Build System
- **Version**: 1.0 (Build 1)

## Non-Goals

Gesso is a single-user, in-session tool. The following are explicitly out of scope:

- **Collaboration**: no multi-user sessions, shared canvases, presence, or comment threads
- **Persistence**: no document store, no saved annotation history, no cloud or iCloud sync
- **Export**: no PDF, image, or file export; nothing leaves the session
- **Art and illustration**: no layers, no template galleries, no media library — Gesso is for marking up UI, not for making artwork

Annotations live in memory for the life of the session. `@AppStorage` is used only for
lightweight UI preferences (theme, haptics), never for annotation data.

## Architecture

### App Structure
```
NavigationSplitView (iPad-optimized)
├── Sidebar
│   ├── Canvas Tab
│   ├── Annotations Tab
│   └── Settings Tab
└── Detail Views
    ├── Canvas (annotation & interaction)
    ├── Annotations (management)
    └── Settings (preferences)
```

### Design Patterns
- **MVVM**: Model-View-ViewModel architecture
- **Declarative UI**: SwiftUI views
- **State Management**: @State, @StateObject, @AppStorage
- **Modular Design**: Separated concerns and reusable components

## Features Implemented

### Canvas View
✅ Interactive canvas surface
✅ Zoom in/out with gestures
✅ Pan navigation
✅ Reset view functionality
✅ Toolbar with actions

### Annotation View
✅ Annotation structure defined
✅ Basic annotation display
✅ List interface ready
✅ Framework for editing

### Settings View
✅ Haptics toggle
✅ Theme selection (System/Light/Dark)
✅ Version and build information
✅ UI preferences stored with AppStorage

### General Features
✅ iPad-optimized layout
✅ All orientation support
✅ SwiftUI previews for all views
✅ Clean, modern design
✅ Proper asset catalog structure

## Project Statistics

- **Swift Files**: 6 (5 views + 1 core library)
- **Documentation Files**: 5 markdown files
- **Lines of Code**: ~300 (app) + configuration
- **Test Coverage**: Basic unit tests implemented
- **Build Time**: ~15 seconds (initial)

## Build & Test Status

✅ Swift Package Manager build: **PASSED**
✅ Unit Tests: **PASSED** (1/1)
✅ Project Structure: **VALID**
✅ Xcode Project: **READY**

## What's Next

This scaffolding provides a solid foundation. Future development can include:

1. **Annotation Marks**: The mark types needed to point at UI (arrow, box, highlight, text)
2. **Advanced Gestures**: More sophisticated touch interactions
3. **Undo/Redo**: In-session action history
4. **Performance**: Optimize for large canvases

Collaboration, persistence, export, and art-tool features are out of scope — see
"Non-Goals" above.

## How to Use

### Quick Start
```bash
# Clone the repo
git clone https://github.com/lgkeroack/gesso.git
cd gesso

# Open in Xcode
open Gesso/Gesso.xcodeproj

# Build and Run (⌘R)
```

### Package Manager
```bash
# Build
swift build

# Test
swift test
```

## File Structure
```
gesso/
├── .gitignore
├── README.md
├── QUICKSTART.md
├── DEVELOPMENT.md
├── ARCHITECTURE.md
├── CONTRIBUTING.md
├── Package.swift
├── Gesso/
│   ├── Gesso.xcodeproj/
│   │   ├── project.pbxproj
│   │   └── xcshareddata/xcschemes/Gesso.xcscheme
│   └── Gesso/
│       ├── GessoApp.swift
│       ├── ContentView.swift
│       ├── CanvasView.swift
│       ├── AnnotationView.swift
│       ├── SettingsView.swift
│       ├── Assets.xcassets/
│       └── Preview Content/
├── Sources/
│   └── GessoCore/
│       └── GessoCore.swift
└── Tests/
    └── GessoCoreTests/
        └── GessoCoreTests.swift
```

## License
Copyright © 2026 Gesso. All rights reserved.

---

**Status**: ✅ Production-Ready Scaffolding
**Last Updated**: February 10, 2026
**Version**: 1.0.0
