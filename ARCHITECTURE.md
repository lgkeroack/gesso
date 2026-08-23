# Gesso App Architecture Overview

## Application Structure

```
┌─────────────────────────────────────────────────────────┐
│                      GessoApp.swift                      │
│                    (Main App Entry)                      │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│                    ContentView.swift                     │
│              (NavigationSplitView - iPad)                │
├─────────────────────┬───────────────────────────────────┤
│    Sidebar          │         Detail View               │
│  ┌──────────┐       │                                   │
│  │ Canvas   │───────┼─────▶ CanvasView.swift            │
│  │          │       │       - Interactive canvas        │
│  │          │       │       - Zoom gesture (pinch)      │
│  ├──────────┤       │       - Placeholder content       │
│  │Annotation│───────┼─────▶ AnnotationView.swift        │
│  │          │       │       - Placeholder labels        │
│  │          │       │       - Annotation model (unused) │
│  ├──────────┤       │       - No list or editing yet    │
│  │ Settings │───────┼─────▶ SettingsView.swift          │
│  │          │       │       - App preferences           │
│  │          │       │       - Haptics and theme         │
│  └──────────┘       │       - About info                │
└─────────────────────┴───────────────────────────────────┘
```

## View Hierarchy

```
GessoApp (@main)
    └── ContentView
        ├── Sidebar Navigation
        │   ├── Canvas Tab
        │   ├── Annotations Tab
        │   └── Settings Tab
        │
        └── Detail Views
            ├── CanvasView
            │   ├── Canvas Background
            │   └── Zoom Gesture
            │
            ├── AnnotationView
            │   └── Placeholder Labels
            │
            └── SettingsView
                ├── General Settings
                ├── Appearance
                └── About Section
```

## Key Features

### iPad-Optimized Layout
- **NavigationSplitView**: Provides a sidebar + detail pane layout
- **All Orientations**: Supports portrait and landscape modes
- **Adaptive UI**: Automatically adjusts to screen size

### Modern SwiftUI Architecture
- **Declarative UI**: All views built with SwiftUI
- **State Management**: 
  - `@State` for local view state
  - `@AppStorage` for UI preferences only
- **Preview Support**: Every view has a preview provider
- **Gesture Support**: Pinch-to-zoom on the canvas

### Core Components

#### Canvas View
- Static canvas background (no mark-making yet)
- Zoom in/out with pinch gesture
- Reset view button

#### Annotation View
- Placeholder text only
- Declares an `Annotation` model (id, position, text, color) that is not yet used

#### Settings View
- Enable/disable haptics
- Theme selection (System/Light/Dark)
- Version and build info

## Technical Stack

- **Platform**: iOS 17.0+, iPadOS 17.0+
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: Plain SwiftUI views; no view-model layer yet
- **Build System**: Xcode 15.2+
- **Package Manager**: Swift Package Manager

## Modular Design

```
Gesso/
├── App Layer (Gesso/)
│   ├── Views (SwiftUI)
│   ├── Assets
│   └── Preview Content
│
└── Core Layer (Sources/GessoCore/)
    ├── Models
    ├── Business Logic
    └── Utilities
```

## Data Flow

```
User Input
    ↓
View (SwiftUI)
    ↓
State Change (@State, @AppStorage)
    ↓
View Update (Automatic)
    ↓
Display Changes
```

## Non-Goals

Gesso is a single-user, in-session tool. The following are explicitly out of scope:

- **Collaboration**: no multi-user sessions, shared canvases, presence, or comment threads
- **Persistence**: no document store, no saved annotation history, no cloud or iCloud sync
- **Export**: no PDF, image, or file export; nothing leaves the session
- **Art and illustration**: no layers, no template galleries, no media library — Gesso is for marking up UI, not for making artwork

Annotations live in memory for the life of the session. `@AppStorage` is used only for
lightweight UI preferences (theme, haptics), never for annotation data.

## Future Expansion Areas

1. **Annotation Marks**: The mark types needed to point at UI (arrow, box, highlight, text)
2. **Undo/Redo**: In-session action history

## Performance Considerations

- **Lazy Loading**: Views load content on demand
- **Efficient Rendering**: SwiftUI's diffing algorithm
- **Asset Optimization**: Vector graphics for scalability
- **Memory Management**: Automatic via ARC

## Accessibility

- VoiceOver support (built-in with SwiftUI)
- Dynamic Type support
- High contrast mode compatibility
- Keyboard navigation support
