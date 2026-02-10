# Gesso Development Guide

## Getting Started

This guide will help you set up and develop the Gesso iPad app.

## Prerequisites

- macOS Ventura or later
- Xcode 15.2 or later
- An Apple Developer account (for device deployment)
- iPad or iPad Simulator

## Initial Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/lgkeroack/gesso.git
   cd gesso
   ```

2. Open the project in Xcode:
   ```bash
   open Gesso/Gesso.xcodeproj
   ```

3. Select an iPad simulator from the device menu

4. Build and run the project (⌘R)

## Project Architecture

### App Structure

The app is built using SwiftUI and follows these principles:

- **Declarative UI**: All views are built using SwiftUI
- **State Management**: Uses @State, @StateObject, and @AppStorage
- **Navigation**: NavigationSplitView for iPad-optimized layout
- **Modular Design**: Separate views for different features

### Key Components

#### GessoApp.swift
- Main app entry point
- Defines the app scene structure

#### ContentView.swift
- Root navigation view
- Implements NavigationSplitView for iPad
- Manages tab selection

#### CanvasView.swift
- Main canvas for UI interaction
- Supports gestures (zoom, pan)
- Real-time drawing capabilities

#### AnnotationView.swift
- Annotation creation and management
- Display annotation overlays
- Edit and delete annotations

#### SettingsView.swift
- App preferences
- User settings persistence
- About information

## Development Workflow

### SwiftUI Previews

Use SwiftUI previews for rapid development:

```swift
#Preview {
    ContentView()
}
```

### Testing

Run unit tests:
```bash
swift test
```

Or use Xcode:
- ⌘U to run all tests
- ⌘Ctrl+Option+U to run tests in focus

### Building

Debug build:
```bash
xcodebuild -scheme Gesso -configuration Debug
```

Release build:
```bash
xcodebuild -scheme Gesso -configuration Release
```

## Code Style

- Use Swift 5.9+ features
- Follow Swift API Design Guidelines
- Use descriptive variable and function names
- Add comments for complex logic
- Keep views small and focused

## iPad Optimization

The app is optimized for iPad:

- Uses NavigationSplitView for sidebar navigation
- Supports all iPad orientations
- Leverages iPad screen real estate
- Implements touch gestures

## Adding New Features

1. Create a new Swift file in the Gesso folder
2. Add the file to the Xcode project
3. Implement your view/model/controller
4. Add preview provider for testing
5. Integrate with existing navigation

## Troubleshooting

### Build Errors

- Clean build folder: ⌘Shift+K
- Reset package cache: File → Packages → Reset Package Caches
- Delete derived data: ~/Library/Developer/Xcode/DerivedData

### Simulator Issues

- Reset simulator: Device → Erase All Content and Settings
- Restart Xcode
- Update to latest Xcode version

## Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [iPad App Design](https://developer.apple.com/design/human-interface-guidelines/ipad)
- [Swift Language Guide](https://docs.swift.org/swift-book/)

## Contributing

1. Create a feature branch
2. Make your changes
3. Test thoroughly on iPad
4. Submit a pull request

## Support

For issues or questions, please open an issue in the GitHub repository.
