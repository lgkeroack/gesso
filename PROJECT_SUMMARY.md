# Gesso - Project Summary

## Overview
Gesso is an iPad application for visual annotation and real-time UI interaction. It is currently an empty scaffold whose only capability is receiving stylus input.

## Project Contents

### Core Application Files
- **GessoApp.swift**: Application entry point using SwiftUI's @main
- **ContentView.swift**: Full-screen stylus input surface; also defines
  `StylusInputView` and `StylusInputSurface`

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
- **Stylus Input**: Apple Pencil touches received via a UIKit bridge
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

Annotations live in memory for the life of the session.

## Architecture

```
GessoApp (@main)
└── ContentView
    └── StylusInputView → StylusInputSurface (UIView)
```

No navigation, no sidebar, no screens.

### Design Patterns
- **Plain SwiftUI views**: no view-model layer
- **State Management**: none currently held
- **UIKit bridge**: `UIViewRepresentable` for stylus input

## Features Implemented

✅ Apple Pencil input received (touch type filtered, coalesced samples read)
✅ iPad-optimized target, all orientations
✅ Asset catalog structure

Nothing else. Stylus samples are received and discarded.

## Project Statistics

- **Swift Files**: 4 (app entry, ContentView, core library, test)
- **Documentation Files**: 7 markdown files
- **Lines of Code**: ~90 Swift
- **Test Coverage**: One test, asserting a version string

## Status

An empty iPad scaffold. The only capability present is receiving stylus input.

## What's Next

Nothing is scheduled. Features are added only when asked for.

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
