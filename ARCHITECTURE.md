# Gesso App Architecture Overview

## Application Structure

```
GessoApp (@main)
    └── WindowGroup
        └── ContentView
            └── StylusInputView          (UIViewRepresentable)
                └── StylusInputSurface   (UIView, receives Pencil touches)
```

The app is an empty scaffold. There is no navigation, no sidebar, and no
screens. `ContentView` hosts a single full-screen surface whose only job is to
receive Apple Pencil input.

## Core Component

### StylusInputSurface

A `UIView` subclass bridged into SwiftUI by `StylusInputView`. It overrides the
four `touches*` methods and filters for `UITouch.TouchType.pencil`, reading
coalesced touches so the full Pencil sample rate is available rather than one
point per frame. The samples are not consumed by anything yet — this is the
hook point for future work.

Stylus input is handled in UIKit because SwiftUI gestures do not expose touch
type.

## Technical Stack

- **Platform**: iOS 17.0+, iPadOS 17.0+
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: SwiftUI shell over a UIKit stylus input surface
- **Build System**: Xcode 15.2+
- **Package Manager**: Swift Package Manager

## Modular Design

```
Gesso/
├── App Layer (Gesso/)
│   ├── GessoApp.swift
│   ├── ContentView.swift
│   └── Assets
│
└── Core Layer (Sources/GessoCore/)
    └── Version constant only
```

## Non-Goals

Gesso is a single-user, in-session tool. The following are explicitly out of scope:

- **Collaboration**: no multi-user sessions, shared canvases, presence, or comment threads
- **Persistence**: no document store, no saved annotation history, no cloud or iCloud sync
- **Export**: no PDF, image, or file export; nothing leaves the session
- **Art and illustration**: no layers, no template galleries, no media library — Gesso is for marking up UI, not for making artwork

Annotations live in memory for the life of the session.

## Future Expansion Areas

Nothing is scheduled. The scaffold is deliberately empty; features are added
only when asked for.

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
