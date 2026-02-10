# Quick Start Guide

## Getting Gesso Running in 5 Minutes

### Step 1: Prerequisites
Ensure you have:
- macOS Ventura (13.0) or later
- Xcode 15.2 or later installed from the App Store
- At least 5 GB of free disk space

### Step 2: Clone the Repository
```bash
git clone https://github.com/lgkeroack/gesso.git
cd gesso
```

### Step 3: Open the Project
```bash
open Gesso/Gesso.xcodeproj
```

Or in Xcode:
1. Open Xcode
2. File → Open
3. Navigate to `gesso/Gesso/Gesso.xcodeproj`
4. Click "Open"

### Step 4: Select an iPad Simulator
1. In Xcode, find the device selector (next to the Run button)
2. Click on it and select an iPad simulator (e.g., "iPad Pro 12.9-inch")
3. If no iPad simulator is available, go to Xcode → Settings → Platforms to download one

### Step 5: Build and Run
1. Press ⌘R (Command + R) or click the Run button (▶)
2. Wait for the build to complete
3. The iPad simulator will launch with Gesso running

### What You'll See

When the app launches, you'll see:
- **Sidebar**: Three navigation options (Canvas, Annotations, Settings)
- **Main View**: The Canvas view by default

### Try These Features

1. **Navigate**: Click on different sidebar items to switch views
2. **Canvas**: 
   - Use pinch gesture on trackpad to zoom (or Option + drag)
   - Click the refresh button to reset the view
3. **Settings**:
   - Toggle haptics on/off
   - Change theme preferences
   - View app version

### Testing with Swift Package Manager

From the command line:
```bash
# Build the package
swift build

# Run tests
swift test
```

### Common Issues

#### "Developer Cannot Be Verified" Error
- Go to System Settings → Privacy & Security → Developer Tools
- Allow Xcode to run command line tools

#### Simulator Not Starting
- Close Xcode
- Delete ~/Library/Developer/Xcode/DerivedData
- Restart Xcode and try again

#### Build Errors
- Make sure you have the latest Xcode version
- Try cleaning the build folder: ⌘Shift+K
- Restart Xcode

### Next Steps

Now that you have the app running:
1. Explore the codebase in `Gesso/Gesso/`
2. Check out `ARCHITECTURE.md` to understand the app structure
3. Read `DEVELOPMENT.md` for development guidelines
4. Review `CONTRIBUTING.md` if you want to contribute

### Live Preview Development

Take advantage of SwiftUI previews for faster development:

1. Open any view file (e.g., `ContentView.swift`)
2. Look for the `#Preview` block at the bottom
3. Press ⌘Option+Return to show the preview pane
4. Edit code and see changes in real-time

### Need Help?

- Check out the [README.md](README.md) for more details
- Read the [DEVELOPMENT.md](DEVELOPMENT.md) guide
- Open an issue on GitHub if you encounter problems

Happy coding! 🎨
