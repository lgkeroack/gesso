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
│  │          │       │       - Zoom & pan gestures       │
│  ├──────────┤       │       - Real-time drawing         │
│  │Annotation│───────┼─────▶ AnnotationView.swift        │
│  │          │       │       - Annotation tools          │
│  │          │       │       - Annotation list           │
│  ├──────────┤       │       - Edit/Delete functions     │
│  │ Settings │───────┼─────▶ SettingsView.swift          │
│  │          │       │       - App preferences           │
│  │          │       │       - User settings             │
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
            │   ├── Drawing Tools
            │   └── Gesture Controls
            │
            ├── AnnotationView
            │   ├── Annotation List
            │   ├── Annotation Editor
            │   └── Annotation Display
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
- **Gesture Support**: Tap, drag, zoom, and pan gestures

### Core Components

#### Canvas View
- Interactive drawing surface
- Zoom in/out with pinch gestures
- Pan to navigate the canvas
- Reset view functionality

#### Annotation View
- Create visual annotations
- Manage annotation list
- Edit annotation properties
- Delete annotations

#### Settings View
- Enable/disable haptics
- Theme selection (System/Light/Dark)
- Version and build info

## Technical Stack

- **Platform**: iOS 17.0+, iPadOS 17.0+
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
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
State Change (@State, @StateObject)
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

Annotations live in memory for the life of the session. `@AppStorage` is used only for
lightweight UI preferences (theme, haptics), never for annotation data.

## Future Expansion Areas

1. **Drawing Tools**: Advanced brush and shape tools
2. **Undo/Redo**: In-session action history
3. **Layers**: Support for multiple annotation layers
4. **Templates**: Pre-built annotation templates

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
